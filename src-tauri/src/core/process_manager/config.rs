//! 进程配置管理命令

use std::collections::HashMap;
use std::path::Path;
use tauri::AppHandle;

use super::state::{ProcessManager, ProcessOutput};
use super::types::{CommandType, ProcessConfig, ProcessMode};
use super::utils::{copy_dir_recursive, current_timestamp, get_processes_dir};
use crate::storage::{delete_process_config, save_process_config, DbState};

/// Fork 模式添加进程
#[tauri::command]
pub fn add_process_fork(
    state: tauri::State<ProcessManager>,
    db_state: tauri::State<DbState>,
    name: String,
    working_dir: String,
    executable_path: Option<String>,
    args: Vec<String>,
    auto_restart: bool,
    auto_start: bool,
    command_type: Option<String>,
) -> Result<ProcessConfig, String> {
    // 解析命令类型
    let cmd_type = match command_type.as_deref() {
        Some("shell") => CommandType::Shell,
        _ => CommandType::Executable,
    };

    // 验证工作目录存在
    let working_dir_path = Path::new(&working_dir);
    if !working_dir_path.exists() {
        return Err("Working directory not found".to_string());
    }
    if !working_dir_path.is_dir() {
        return Err("Working directory path is not a directory".to_string());
    }

    // 如果是 Executable 模式且提供了可执行文件路径，验证其存在
    // Shell 模式下不验证路径，因为命令会通过 shell 解析
    if cmd_type == CommandType::Executable {
        if let Some(ref exe_path_str) = executable_path {
            if !exe_path_str.is_empty() {
                let exe_path = Path::new(exe_path_str);
                if !exe_path.exists() {
                    return Err("Executable file not found".to_string());
                }
            }
        }
    }

    // command 字段：如果提供了 executable_path 则使用它，否则为空字符串
    let command = executable_path.unwrap_or_default();

    let id = uuid::Uuid::new_v4().to_string();
    let config = ProcessConfig {
        id: id.clone(),
        name,
        mode: ProcessMode::Fork,
        command_type: cmd_type,
        command,
        args,
        working_dir,
        source_path: None,
        env: HashMap::new(),
        auto_restart,
        auto_start,
        created_at: current_timestamp(),
    };

    // 保存到数据库
    {
        let conn = db_state.0.lock().map_err(|e| e.to_string())?;
        save_process_config(&conn, &config)?;
    }

    // 添加到内存
    let mut manager = state.lock().map_err(|e| e.to_string())?;
    manager.configs.insert(id.clone(), config.clone());
    manager.outputs.insert(id, ProcessOutput::default());
    Ok(config)
}

/// 导入模式添加进程
#[tauri::command]
pub fn add_process_import(
    app: AppHandle,
    state: tauri::State<ProcessManager>,
    db_state: tauri::State<DbState>,
    name: String,
    source_folder: String,
    executable_path: Option<String>,
    args: Vec<String>,
    auto_restart: bool,
    auto_start: bool,
    command_type: Option<String>,
) -> Result<ProcessConfig, String> {
    // 解析命令类型
    let cmd_type = match command_type.as_deref() {
        Some("shell") => CommandType::Shell,
        _ => CommandType::Executable,
    };

    let source_path = Path::new(&source_folder);
    if !source_path.exists() || !source_path.is_dir() {
        return Err("Source folder not found".to_string());
    }

    let processes_dir = get_processes_dir(&app)?;
    let id = uuid::Uuid::new_v4().to_string();
    let target_dir = processes_dir.join(&id);

    copy_dir_recursive(source_path, &target_dir)?;

    // 如果是 Executable 模式且提供了可执行文件路径，验证其存在
    // Shell 模式下不验证路径，因为命令会通过 shell 解析
    if cmd_type == CommandType::Executable {
        if let Some(ref exe_path_str) = executable_path {
            if !exe_path_str.is_empty() {
                let exe_path = Path::new(exe_path_str);
                if !exe_path.exists() {
                    return Err("Executable file not found".to_string());
                }
            }
        }
    }

    // command 字段：如果提供了 executable_path 则使用它，否则为空字符串
    let command = executable_path.unwrap_or_default();

    let config = ProcessConfig {
        id: id.clone(),
        name,
        mode: ProcessMode::Import,
        command_type: cmd_type,
        command,
        args,
        working_dir: target_dir.to_string_lossy().to_string(),
        source_path: Some(source_folder),
        env: HashMap::new(),
        auto_restart,
        auto_start,
        created_at: current_timestamp(),
    };

    // 保存到数据库
    {
        let conn = db_state.0.lock().map_err(|e| e.to_string())?;
        save_process_config(&conn, &config)?;
    }

    // 添加到内存
    let mut manager = state.lock().map_err(|e| e.to_string())?;
    manager.configs.insert(id.clone(), config.clone());
    manager.outputs.insert(id, ProcessOutput::default());
    Ok(config)
}

/// 删除进程配置
#[tauri::command]
pub fn remove_process(
    _app: AppHandle,
    state: tauri::State<ProcessManager>,
    db_state: tauri::State<DbState>,
    id: String,
) -> Result<(), String> {
    // 从数据库删除
    {
        let conn = db_state.0.lock().map_err(|e| e.to_string())?;
        delete_process_config(&conn, &id)?;
    }

    let mut manager = state.lock().map_err(|e| e.to_string())?;

    if let Some(mut running) = manager.processes.remove(&id) {
        let _ = running.child.kill();
    }

    let _config = manager
        .configs
        .remove(&id)
        .ok_or_else(|| "Process not found".to_string())?;

    manager.outputs.remove(&id);

    Ok(())
}

/// 编辑进程配置
#[tauri::command]
pub fn update_process(
    state: tauri::State<ProcessManager>,
    db_state: tauri::State<DbState>,
    id: String,
    name: String,
    working_dir: Option<String>,
    executable_path: Option<String>,
    args: Vec<String>,
    auto_restart: bool,
    auto_start: bool,
    command_type: Option<String>,
) -> Result<ProcessConfig, String> {
    // 解析命令类型
    let cmd_type = match command_type.as_deref() {
        Some("shell") => Some(CommandType::Shell),
        Some("executable") => Some(CommandType::Executable),
        _ => None, // 不更新命令类型
    };

    // 如果提供了工作目录，验证其存在
    if let Some(ref wd) = working_dir {
        let working_dir_path = Path::new(wd);
        if !working_dir_path.exists() {
            return Err("Working directory not found".to_string());
        }
        if !working_dir_path.is_dir() {
            return Err("Working directory path is not a directory".to_string());
        }
    }

    // 获取当前配置以确定命令类型
    let current_cmd_type = {
        let manager = state.lock().map_err(|e| e.to_string())?;
        let config = manager
            .configs
            .get(&id)
            .ok_or_else(|| "Process not found".to_string())?;
        cmd_type.clone().unwrap_or(config.command_type.clone())
    };

    // 如果是 Executable 模式且提供了可执行文件路径，验证其存在
    // Shell 模式下不验证路径，因为命令会通过 shell 解析
    if current_cmd_type == CommandType::Executable {
        if let Some(ref exe_path_str) = executable_path {
            if !exe_path_str.is_empty() {
                let exe_path = Path::new(exe_path_str);
                if !exe_path.exists() {
                    return Err("Executable file not found".to_string());
                }
            }
        }
    }

    let mut manager = state.lock().map_err(|e| e.to_string())?;

    let config = manager
        .configs
        .get_mut(&id)
        .ok_or_else(|| "Process not found".to_string())?;

    config.name = name;
    config.args = args;
    config.auto_restart = auto_restart;
    config.auto_start = auto_start;

    // 更新命令类型（如果提供）
    if let Some(ct) = cmd_type {
        config.command_type = ct;
    }

    // 更新工作目录（如果提供）
    if let Some(wd) = working_dir {
        config.working_dir = wd;
    }

    // 更新可执行文件路径（如果提供）
    if let Some(exe_path) = executable_path {
        config.command = exe_path;
    }

    // 保存到数据库
    let conn = db_state.0.lock().map_err(|e| e.to_string())?;
    save_process_config(&conn, config)?;

    Ok(config.clone())
}
