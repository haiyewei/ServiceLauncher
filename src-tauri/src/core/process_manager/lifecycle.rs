//! 进程生命周期管理命令

use tauri::{AppHandle, Emitter};

use super::runner::{register_running_process, setup_output_listeners, spawn_process};
use super::state::ProcessManager;
use super::types::{ProcessConfig, ProcessInfo, ProcessStatus};

/// 启动进程
#[tauri::command]
pub fn start_process(
    app: AppHandle,
    state: tauri::State<ProcessManager>,
    id: String,
) -> Result<ProcessInfo, String> {
    let config: ProcessConfig;
    {
        let mut manager = state.lock().map_err(|e| e.to_string())?;

        if manager.processes.contains_key(&id) {
            return Err("Process is already running".to_string());
        }

        config = manager
            .configs
            .get(&id)
            .ok_or_else(|| "Process config not found".to_string())?
            .clone();

        if let Some(output) = manager.outputs.get_mut(&id) {
            output.clear();
        }
    }

    let mut result = spawn_process(&config)?;
    let pid = result.child.id();
    let started_at = result.started_at;

    // 设置输出监听
    setup_output_listeners(&app, state.inner(), &id, &mut result.child);

    // 注册运行中的进程
    register_running_process(state.inner(), &id, result.child, config.clone(), started_at)?;

    let _ = app.emit("process-status-changed", &id);

    Ok(ProcessInfo {
        id: config.id,
        name: config.name,
        mode: config.mode,
        command_type: config.command_type,
        command: config.command,
        args: config.args,
        working_dir: config.working_dir,
        source_path: config.source_path,
        status: ProcessStatus::Running,
        pid: Some(pid),
        auto_restart: config.auto_restart,
        auto_start: config.auto_start,
        started_at: Some(started_at),
        created_at: config.created_at,
        has_output: false,
    })
}

/// 停止进程
#[tauri::command]
pub fn stop_process(
    app: AppHandle,
    state: tauri::State<ProcessManager>,
    id: String,
) -> Result<(), String> {
    let mut manager = state.lock().map_err(|e| e.to_string())?;

    let mut running = manager
        .processes
        .remove(&id)
        .ok_or_else(|| "Process is not running".to_string())?;

    running
        .child
        .kill()
        .map_err(|e| format!("Failed to stop process: {}", e))?;

    let _ = app.emit("process-status-changed", &id);

    Ok(())
}

/// 启动所有设置为跟随应用启动的进程（Tauri 命令）
#[tauri::command]
pub fn start_auto_start_processes(
    app: AppHandle,
    state: tauri::State<ProcessManager>,
) -> Result<Vec<String>, String> {
    let auto_start_ids: Vec<String>;
    {
        let manager = state.lock().map_err(|e| e.to_string())?;
        auto_start_ids = manager
            .configs
            .iter()
            .filter(|(_, config)| config.auto_start)
            .map(|(id, _)| id.clone())
            .collect();
    }

    let mut started = Vec::new();
    for id in auto_start_ids {
        if start_process_with_manager(&app, state.inner(), &id).is_ok() {
            started.push(id);
        }
    }

    Ok(started)
}

/// 应用启动时自动启动进程（供 setup 使用，不依赖 tauri::State）
/// 在后台线程中排队启动，等待每个进程启动完成后再启动下一个
pub fn auto_start_processes_on_init(app: &AppHandle, manager: &ProcessManager) {
    let auto_start_ids: Vec<String>;
    {
        if let Ok(state) = manager.lock() {
            auto_start_ids = state
                .configs
                .iter()
                .filter(|(_, config)| config.auto_start)
                .map(|(id, _)| id.clone())
                .collect();
        } else {
            return;
        }
    }

    if auto_start_ids.is_empty() {
        return;
    }

    // 在后台线程中排队启动进程
    let app_clone = app.clone();
    let manager_clone = manager.clone();
    std::thread::spawn(move || {
        for id in auto_start_ids.iter() {
            // 启动进程并等待确认启动状态
            match start_process_and_wait(&app_clone, &manager_clone, id) {
                Ok(_) => {
                    println!("Auto-started process: {}", id);
                }
                Err(e) => {
                    eprintln!("Failed to auto-start process {}: {}", id, e);
                }
            }
            // 无论成功或失败，都继续启动下一个进程
        }
    });
}

/// 启动进程并等待确认启动状态
fn start_process_and_wait(
    app: &AppHandle,
    manager: &ProcessManager,
    id: &str,
) -> Result<(), String> {
    let config: ProcessConfig;
    {
        let mut state = manager.lock().map_err(|e| e.to_string())?;

        if state.processes.contains_key(id) {
            return Ok(()); // 已经在运行
        }

        config = state
            .configs
            .get(id)
            .ok_or_else(|| "Process config not found".to_string())?
            .clone();

        if let Some(output) = state.outputs.get_mut(id) {
            output.clear();
        }
    }

    let mut result = spawn_process(&config)?;
    let started_at = result.started_at;

    // 等待一小段时间确认进程是否成功启动
    std::thread::sleep(std::time::Duration::from_millis(100));

    // 检查进程是否仍在运行
    match result.child.try_wait() {
        Ok(Some(status)) => {
            // 进程已退出，启动失败
            return Err(format!(
                "Process exited immediately with status: {:?}",
                status
            ));
        }
        Ok(None) => {
            // 进程仍在运行，启动成功
        }
        Err(e) => {
            return Err(format!("Failed to check process status: {}", e));
        }
    }

    // 设置输出监听
    setup_output_listeners(app, manager, id, &mut result.child);

    // 注册运行中的进程
    register_running_process(manager, id, result.child, config, started_at)?;

    let _ = app.emit("process-status-changed", id);

    Ok(())
}

/// 内部启动进程函数（通用版本）
fn start_process_with_manager(
    app: &AppHandle,
    manager: &ProcessManager,
    id: &str,
) -> Result<(), String> {
    let config: ProcessConfig;
    {
        let mut state = manager.lock().map_err(|e| e.to_string())?;

        if state.processes.contains_key(id) {
            return Ok(()); // 已经在运行
        }

        config = state
            .configs
            .get(id)
            .ok_or_else(|| "Process config not found".to_string())?
            .clone();

        if let Some(output) = state.outputs.get_mut(id) {
            output.clear();
        }
    }

    let mut result = spawn_process(&config)?;
    let started_at = result.started_at;

    // 设置输出监听
    setup_output_listeners(app, manager, id, &mut result.child);

    // 注册运行中的进程
    register_running_process(manager, id, result.child, config, started_at)?;

    let _ = app.emit("process-status-changed", id);

    Ok(())
}
