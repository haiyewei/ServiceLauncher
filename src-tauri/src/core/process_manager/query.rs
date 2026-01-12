//! 进程查询命令

use super::state::ProcessManager;
use super::types::{ProcessInfo, ProcessStatus};

/// 获取所有进程列表
#[tauri::command]
pub fn list_processes(state: tauri::State<ProcessManager>) -> Result<Vec<ProcessInfo>, String> {
    let mut manager = state.lock().map_err(|e| e.to_string())?;

    // 检查已退出的进程
    let stopped_ids: Vec<String> = manager
        .processes
        .iter_mut()
        .filter_map(|(id, running)| match running.child.try_wait() {
            Ok(Some(_)) | Err(_) => Some(id.clone()),
            Ok(None) => None,
        })
        .collect();

    for id in stopped_ids {
        manager.processes.remove(&id);
    }

    let mut result: Vec<ProcessInfo> = manager
        .configs
        .iter()
        .map(|(id, config)| {
            let (status, pid, started_at) = if let Some(running) = manager.processes.get(id) {
                (
                    ProcessStatus::Running,
                    Some(running.child.id()),
                    Some(running.started_at),
                )
            } else {
                (ProcessStatus::Stopped, None, None)
            };

            let has_output = manager
                .outputs
                .get(id)
                .map(|o| !o.lines.is_empty())
                .unwrap_or(false);

            ProcessInfo {
                id: config.id.clone(),
                name: config.name.clone(),
                mode: config.mode.clone(),
                command_type: config.command_type.clone(),
                command: config.command.clone(),
                args: config.args.clone(),
                working_dir: config.working_dir.clone(),
                source_path: config.source_path.clone(),
                status,
                pid,
                auto_restart: config.auto_restart,
                auto_start: config.auto_start,
                started_at,
                created_at: config.created_at,
                has_output,
            }
        })
        .collect();

    result.sort_by(|a, b| b.created_at.cmp(&a.created_at));

    Ok(result)
}

/// 获取单个进程信息
#[tauri::command]
pub fn get_process(state: tauri::State<ProcessManager>, id: String) -> Result<ProcessInfo, String> {
    let manager = state.lock().map_err(|e| e.to_string())?;

    let config = manager
        .configs
        .get(&id)
        .ok_or_else(|| "Process not found".to_string())?;

    let (status, pid, started_at) = if let Some(running) = manager.processes.get(&id) {
        (
            ProcessStatus::Running,
            Some(running.child.id()),
            Some(running.started_at),
        )
    } else {
        (ProcessStatus::Stopped, None, None)
    };

    let has_output = manager
        .outputs
        .get(&id)
        .map(|o| !o.lines.is_empty())
        .unwrap_or(false);

    Ok(ProcessInfo {
        id: config.id.clone(),
        name: config.name.clone(),
        mode: config.mode.clone(),
        command_type: config.command_type.clone(),
        command: config.command.clone(),
        args: config.args.clone(),
        working_dir: config.working_dir.clone(),
        source_path: config.source_path.clone(),
        status,
        pid,
        auto_restart: config.auto_restart,
        auto_start: config.auto_start,
        started_at,
        created_at: config.created_at,
        has_output,
    })
}
