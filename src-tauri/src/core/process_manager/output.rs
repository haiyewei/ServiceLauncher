//! 进程输出管理命令

use super::state::ProcessManager;

/// 获取进程输出
#[tauri::command]
pub fn get_process_output(
    state: tauri::State<ProcessManager>,
    id: String,
) -> Result<Vec<(i64, String, String)>, String> {
    let manager = state.lock().map_err(|e| e.to_string())?;

    let output = manager
        .outputs
        .get(&id)
        .ok_or_else(|| "Process not found".to_string())?;

    Ok(output.lines.clone())
}

/// 清空进程输出
#[tauri::command]
pub fn clear_process_output(state: tauri::State<ProcessManager>, id: String) -> Result<(), String> {
    let mut manager = state.lock().map_err(|e| e.to_string())?;

    let output = manager
        .outputs
        .get_mut(&id)
        .ok_or_else(|| "Process not found".to_string())?;

    output.clear();
    Ok(())
}
