//! 进程启动核心逻辑

use std::io::{BufRead, BufReader};
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::thread;
use tauri::{AppHandle, Emitter};

use super::state::{ProcessManager, RunningProcess};
use super::types::{ProcessConfig, ProcessOutputEvent};
use super::utils::{current_timestamp, current_timestamp_millis, kill_processes_by_name};

/// 进程启动结果
pub struct SpawnResult {
    pub child: Child,
    pub started_at: i64,
}

/// 启动进程的核心逻辑
pub fn spawn_process(config: &ProcessConfig) -> Result<SpawnResult, String> {
    // 启动前结束同名进程
    if let Some(exe_name) = Path::new(&config.command).file_name() {
        let exe_name_str = exe_name.to_string_lossy();
        if let Ok(count) = kill_processes_by_name(&exe_name_str) {
            if count > 0 {
                thread::sleep(std::time::Duration::from_millis(500));
            }
        }
    }

    let mut cmd = Command::new(&config.command);
    cmd.args(&config.args);
    cmd.current_dir(&config.working_dir);

    for (key, value) in &config.env {
        cmd.env(key, value);
    }

    cmd.stdout(Stdio::piped());
    cmd.stderr(Stdio::piped());

    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        cmd.creation_flags(0x08000000);
    }

    let child = cmd
        .spawn()
        .map_err(|e| format!("Failed to start process: {}", e))?;

    let started_at = current_timestamp();

    Ok(SpawnResult { child, started_at })
}

/// 设置进程输出监听线程
pub fn setup_output_listeners(
    app: &AppHandle,
    manager: &ProcessManager,
    id: &str,
    child: &mut Child,
) {
    // stdout 监听线程
    if let Some(stdout) = child.stdout.take() {
        let app_clone = app.clone();
        let manager_clone = manager.clone();
        let id_clone = id.to_string();
        thread::spawn(move || {
            let reader = BufReader::new(stdout);
            for line in reader.lines().map_while(Result::ok) {
                let timestamp = current_timestamp_millis();
                if let Ok(mut state) = manager_clone.lock() {
                    if let Some(output) = state.outputs.get_mut(&id_clone) {
                        output.push_line(timestamp, "stdout".to_string(), line.clone());
                    }
                }
                let _ = app_clone.emit(
                    "process-output",
                    ProcessOutputEvent {
                        id: id_clone.clone(),
                        output_type: "stdout".to_string(),
                        line,
                        timestamp,
                    },
                );
            }
        });
    }

    // stderr 监听线程
    if let Some(stderr) = child.stderr.take() {
        let app_clone = app.clone();
        let manager_clone = manager.clone();
        let id_clone = id.to_string();
        thread::spawn(move || {
            let reader = BufReader::new(stderr);
            for line in reader.lines().map_while(Result::ok) {
                let timestamp = current_timestamp_millis();
                if let Ok(mut state) = manager_clone.lock() {
                    if let Some(output) = state.outputs.get_mut(&id_clone) {
                        output.push_line(timestamp, "stderr".to_string(), line.clone());
                    }
                }
                let _ = app_clone.emit(
                    "process-output",
                    ProcessOutputEvent {
                        id: id_clone.clone(),
                        output_type: "stderr".to_string(),
                        line,
                        timestamp,
                    },
                );
            }
        });
    }
}

/// 注册运行中的进程到状态管理器
pub fn register_running_process(
    manager: &ProcessManager,
    id: &str,
    child: Child,
    config: ProcessConfig,
    started_at: i64,
) -> Result<(), String> {
    let mut state = manager.lock().map_err(|e| e.to_string())?;
    let running = RunningProcess {
        child,
        config,
        started_at,
    };
    state.processes.insert(id.to_string(), running);
    Ok(())
}
