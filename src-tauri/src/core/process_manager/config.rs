//! 进程配置管理命令

use std::collections::HashMap;
use std::path::Path;
use tauri::AppHandle;

use super::state::{ProcessManager, ProcessOutput};
use super::types::{ProcessConfig, ProcessMode};
use super::utils::{copy_dir_recursive, current_timestamp, find_executable, get_processes_dir};
use crate::storage::{delete_process_config, save_process_config, DbState};

/// Fork 模式添加进程
#[tauri::command]
pub fn add_process_fork(
    state: tauri::State<ProcessManager>,
    db_state: tauri::State<DbState>,
    name: String,
    executable_path: String,
    args: Vec<String>,
    auto_restart: bool,
    auto_start: bool,
) -> Result<ProcessConfig, String> {
    let exe_path = Path::new(&executable_path);
    if !exe_path.exists() {
        return Err("Executable file not found".to_string());
    }

    let working_dir = exe_path
        .parent()
        .ok_or("Invalid executable path")?
        .to_string_lossy()
        .to_string();

    let id = uuid::Uuid::new_v4().to_string();
    let config = ProcessConfig {
        id: id.clone(),
        name,
        mode: ProcessMode::Fork,
        command: executable_path,
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
    args: Vec<String>,
    auto_restart: bool,
    auto_start: bool,
) -> Result<ProcessConfig, String> {
    let source_path = Path::new(&source_folder);
    if !source_path.exists() || !source_path.is_dir() {
        return Err("Source folder not found".to_string());
    }

    let processes_dir = get_processes_dir(&app)?;
    let id = uuid::Uuid::new_v4().to_string();
    let target_dir = processes_dir.join(&id);

    copy_dir_recursive(source_path, &target_dir)?;

    let executable = find_executable(&target_dir).ok_or("No executable found in the folder")?;

    let config = ProcessConfig {
        id: id.clone(),
        name,
        mode: ProcessMode::Import,
        command: executable.to_string_lossy().to_string(),
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
    app: AppHandle,
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

    let config = manager
        .configs
        .remove(&id)
        .ok_or_else(|| "Process not found".to_string())?;

    manager.outputs.remove(&id);

    if config.mode == ProcessMode::Import {
        if let Ok(processes_dir) = get_processes_dir(&app) {
            let target_dir = processes_dir.join(&id);
            let _ = std::fs::remove_dir_all(target_dir);
        }
    }

    Ok(())
}

/// 编辑进程配置
#[tauri::command]
pub fn update_process(
    state: tauri::State<ProcessManager>,
    db_state: tauri::State<DbState>,
    id: String,
    name: String,
    args: Vec<String>,
    auto_restart: bool,
    auto_start: bool,
) -> Result<ProcessConfig, String> {
    let mut manager = state.lock().map_err(|e| e.to_string())?;

    let config = manager
        .configs
        .get_mut(&id)
        .ok_or_else(|| "Process not found".to_string())?;

    config.name = name;
    config.args = args;
    config.auto_restart = auto_restart;
    config.auto_start = auto_start;

    // 保存到数据库
    let conn = db_state.0.lock().map_err(|e| e.to_string())?;
    save_process_config(&conn, config)?;

    Ok(config.clone())
}
