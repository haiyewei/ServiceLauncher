//! 进程管理器工具函数

use std::path::{Path, PathBuf};
use tauri::{AppHandle, Manager};

#[cfg(windows)]
use std::ffi::OsString;
#[cfg(windows)]
use std::os::windows::ffi::OsStringExt;

/// 获取当前时间戳（秒）
pub fn current_timestamp() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64
}

/// 获取当前时间戳（毫秒）
pub fn current_timestamp_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64
}

/// 获取应用的进程工作目录
pub fn get_processes_dir(app: &AppHandle) -> Result<PathBuf, String> {
    let app_data = app
        .path()
        .app_data_dir()
        .map_err(|e| format!("Failed to get app data dir: {}", e))?;
    let processes_dir = app_data.join("processes");
    std::fs::create_dir_all(&processes_dir)
        .map_err(|e| format!("Failed to create processes dir: {}", e))?;
    Ok(processes_dir)
}

/// 递归复制文件夹
pub fn copy_dir_recursive(src: &Path, dst: &Path) -> Result<(), String> {
    std::fs::create_dir_all(dst).map_err(|e| format!("Failed to create dir: {}", e))?;

    for entry in std::fs::read_dir(src).map_err(|e| format!("Failed to read dir: {}", e))? {
        let entry = entry.map_err(|e| format!("Failed to read entry: {}", e))?;
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());

        if src_path.is_dir() {
            copy_dir_recursive(&src_path, &dst_path)?;
        } else {
            std::fs::copy(&src_path, &dst_path)
                .map_err(|e| format!("Failed to copy file: {}", e))?;
        }
    }
    Ok(())
}

/// 查找文件夹中的可执行文件
pub fn find_executable(dir: &Path) -> Option<PathBuf> {
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_file() {
                #[cfg(windows)]
                {
                    if let Some(ext) = path.extension() {
                        let ext = ext.to_string_lossy().to_lowercase();
                        if ext == "exe" || ext == "bat" || ext == "cmd" {
                            return Some(path);
                        }
                    }
                }
                #[cfg(not(windows))]
                {
                    use std::os::unix::fs::PermissionsExt;
                    if let Ok(meta) = path.metadata() {
                        if meta.permissions().mode() & 0o111 != 0 {
                            return Some(path);
                        }
                    }
                }
            }
        }
    }
    None
}

/// 结束同名进程 (Windows)
#[cfg(windows)]
pub fn kill_processes_by_name(exe_name: &str) -> Result<u32, String> {
    use windows_sys::Win32::Foundation::CloseHandle;
    use windows_sys::Win32::System::Diagnostics::ToolHelp::{
        CreateToolhelp32Snapshot, Process32FirstW, Process32NextW, PROCESSENTRY32W,
        TH32CS_SNAPPROCESS,
    };
    use windows_sys::Win32::System::Threading::{OpenProcess, TerminateProcess, PROCESS_TERMINATE};

    let mut killed_count = 0u32;
    let target_name = exe_name.to_lowercase();

    unsafe {
        let snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if snapshot.is_null() {
            return Err("Failed to create process snapshot".to_string());
        }

        let mut entry: PROCESSENTRY32W = std::mem::zeroed();
        entry.dwSize = std::mem::size_of::<PROCESSENTRY32W>() as u32;

        if Process32FirstW(snapshot, &mut entry) != 0 {
            loop {
                let name_len = entry
                    .szExeFile
                    .iter()
                    .position(|&c| c == 0)
                    .unwrap_or(entry.szExeFile.len());
                let process_name = OsString::from_wide(&entry.szExeFile[..name_len])
                    .to_string_lossy()
                    .to_lowercase();

                if process_name == target_name {
                    let handle = OpenProcess(PROCESS_TERMINATE, 0i32, entry.th32ProcessID);
                    if !handle.is_null() {
                        if TerminateProcess(handle, 1) != 0 {
                            killed_count += 1;
                        }
                        CloseHandle(handle);
                    }
                }

                if Process32NextW(snapshot, &mut entry) == 0 {
                    break;
                }
            }
        }

        CloseHandle(snapshot);
    }

    Ok(killed_count)
}

/// 结束同名进程 (Unix)
#[cfg(not(windows))]
pub fn kill_processes_by_name(exe_name: &str) -> Result<u32, String> {
    let output = Command::new("pkill")
        .arg("-f")
        .arg(exe_name)
        .output()
        .map_err(|e| format!("Failed to run pkill: {}", e))?;

    if output.status.success() {
        Ok(1)
    } else {
        Ok(0)
    }
}
