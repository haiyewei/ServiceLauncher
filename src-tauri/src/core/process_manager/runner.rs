//! 进程启动核心逻辑

use regex::Regex;
use std::collections::HashMap;
use std::io::{BufRead, BufReader};
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::LazyLock;
use std::thread;
use tauri::{AppHandle, Emitter};

use super::state::{ProcessManager, RunningProcess};
use super::types::{CommandType, ProcessConfig, ProcessOutputEvent};
use super::utils::{current_timestamp, current_timestamp_millis, kill_processes_by_name};

/// 用于匹配 ANSI 转义序列的正则表达式
/// 使用 LazyLock 缓存编译后的正则表达式以提高性能
static ANSI_ESCAPE_REGEX: LazyLock<Regex> = LazyLock::new(|| {
    // 匹配 ANSI 转义序列：
    // - \x1b\[[0-9;]*[a-zA-Z] 匹配 CSI 序列（如颜色、光标控制等）
    // - \x1b\].*?\x07 匹配 OSC 序列（如设置窗口标题等）
    Regex::new(r"\x1b\[[0-9;]*[a-zA-Z]|\x1b\].*?\x07").unwrap()
});

/// 清理输出中的 ANSI 转义序列
///
/// 移除终端颜色代码和其他控制字符，返回纯文本
fn strip_ansi_escape_codes(input: &str) -> String {
    ANSI_ESCAPE_REGEX.replace_all(input, "").to_string()
}

/// 获取完整的用户环境变量
///
/// 在 Windows 上，当应用程序通过自动启动机制启动时，可能无法获得完整的用户环境变量。
/// 此函数会从注册表中读取用户环境变量，并与当前进程的环境变量合并，确保子进程能够获得完整的环境。
///
/// 注意：只有当前进程中不存在的变量才会从注册表中补充，避免重复。
#[cfg(windows)]
fn get_full_user_environment() -> HashMap<String, String> {
    use std::collections::HashSet;

    let mut env_map: HashMap<String, String> = std::env::vars().collect();

    // 尝试从注册表读取用户环境变量
    if let Ok(user_env) = read_user_env_from_registry() {
        for (key, value) in user_env {
            // PATH 变量需要特殊处理：合并而不是覆盖，但要去重
            if key.eq_ignore_ascii_case("PATH") {
                if let Some(existing_path) =
                    env_map.get("PATH").or_else(|| env_map.get("Path")).cloned()
                {
                    // 将现有 PATH 分割成集合用于去重
                    let existing_paths: HashSet<String> = existing_path
                        .split(';')
                        .filter(|s| !s.is_empty())
                        .map(|s| s.to_lowercase())
                        .collect();

                    // 只添加不存在的路径
                    let new_paths: Vec<&str> = value
                        .split(';')
                        .filter(|s| !s.is_empty() && !existing_paths.contains(&s.to_lowercase()))
                        .collect();

                    if !new_paths.is_empty() {
                        let merged_path = format!("{};{}", new_paths.join(";"), existing_path);
                        env_map.insert("PATH".to_string(), merged_path);
                    }
                } else {
                    env_map.insert(key, value);
                }
            } else {
                // 其他变量：只有当前进程中不存在时才添加
                // 使用不区分大小写的比较
                let key_lower = key.to_lowercase();
                let exists = env_map.keys().any(|k| k.to_lowercase() == key_lower);
                if !exists {
                    env_map.insert(key, value);
                }
            }
        }
    }

    env_map
}

/// 从 Windows 注册表读取用户环境变量
#[cfg(windows)]
fn read_user_env_from_registry() -> Result<HashMap<String, String>, String> {
    use winreg::enums::*;
    use winreg::RegKey;

    let mut env_map = HashMap::new();

    // 打开用户环境变量注册表键
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    let env_key = hkcu
        .open_subkey("Environment")
        .map_err(|e| format!("Failed to open user environment registry key: {}", e))?;

    // 读取所有值
    for value_result in env_key.enum_values() {
        if let Ok((name, _)) = value_result {
            // 尝试将注册表值转换为字符串
            let string_value: Result<String, _> = env_key.get_value(&name);
            if let Ok(val) = string_value {
                // 展开环境变量引用（如 %USERPROFILE%）
                let expanded = expand_env_vars(&val);
                env_map.insert(name, expanded);
            }
        }
    }

    Ok(env_map)
}

/// 展开环境变量引用（如 %USERPROFILE% -> C:\Users\Username）
#[cfg(windows)]
fn expand_env_vars(input: &str) -> String {
    use std::ffi::{OsStr, OsString};
    use std::os::windows::ffi::{OsStrExt, OsStringExt};

    // 使用 Windows API 展开环境变量
    let wide: Vec<u16> = OsStr::new(input)
        .encode_wide()
        .chain(std::iter::once(0))
        .collect();

    unsafe {
        use windows_sys::Win32::System::Environment::ExpandEnvironmentStringsW;

        // 首先获取需要的缓冲区大小
        let size = ExpandEnvironmentStringsW(wide.as_ptr(), std::ptr::null_mut(), 0);
        if size == 0 {
            return input.to_string();
        }

        let mut buffer: Vec<u16> = vec![0; size as usize];
        let result = ExpandEnvironmentStringsW(wide.as_ptr(), buffer.as_mut_ptr(), size);

        if result == 0 || result > size {
            return input.to_string();
        }

        // 移除末尾的 null 字符
        if let Some(pos) = buffer.iter().position(|&c| c == 0) {
            buffer.truncate(pos);
        }

        OsString::from_wide(&buffer).to_string_lossy().into_owned()
    }
}

/// 非 Windows 平台：直接使用当前进程的环境变量
#[cfg(not(windows))]
fn get_full_user_environment() -> HashMap<String, String> {
    std::env::vars().collect()
}

/// 进程启动结果
pub struct SpawnResult {
    pub child: Child,
    pub started_at: i64,
}

/// 启动进程的核心逻辑
pub fn spawn_process(config: &ProcessConfig) -> Result<SpawnResult, String> {
    // 检查 command 是否为空
    if config.command.is_empty() {
        return Err(
            "Command is not specified. Please configure a command for this process.".to_string(),
        );
    }

    let mut cmd = match config.command_type {
        CommandType::Executable => {
            // 启动前结束同名进程（仅对可执行文件）
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
            cmd
        }
        CommandType::Shell => {
            // 通过系统 shell 执行命令
            let full_command = if config.args.is_empty() {
                config.command.clone()
            } else {
                format!("{} {}", config.command, config.args.join(" "))
            };

            #[cfg(windows)]
            {
                let mut cmd = Command::new("cmd");
                cmd.args(["/C", &full_command]);
                cmd
            }

            #[cfg(not(windows))]
            {
                let mut cmd = Command::new("sh");
                cmd.args(["-c", &full_command]);
                cmd
            }
        }
    };

    cmd.current_dir(&config.working_dir);

    // 获取完整的用户环境变量（包括从注册表读取的用户变量）
    // 这确保了子进程能够获得完整的用户环境变量，
    // 即使应用程序是通过 Windows 自动启动机制启动的
    let user_env = get_full_user_environment();
    cmd.env_clear();
    cmd.envs(&user_env);

    // 然后添加/覆盖配置中指定的额外环境变量
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
                // 清理 ANSI 转义序列
                let clean_line = strip_ansi_escape_codes(&line);
                let timestamp = current_timestamp_millis();
                if let Ok(mut state) = manager_clone.lock() {
                    if let Some(output) = state.outputs.get_mut(&id_clone) {
                        output.push_line(timestamp, "stdout".to_string(), clean_line.clone());
                    }
                }
                let _ = app_clone.emit(
                    "process-output",
                    ProcessOutputEvent {
                        id: id_clone.clone(),
                        output_type: "stdout".to_string(),
                        line: clean_line,
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
                // 清理 ANSI 转义序列
                let clean_line = strip_ansi_escape_codes(&line);
                let timestamp = current_timestamp_millis();
                if let Ok(mut state) = manager_clone.lock() {
                    if let Some(output) = state.outputs.get_mut(&id_clone) {
                        output.push_line(timestamp, "stderr".to_string(), clean_line.clone());
                    }
                }
                let _ = app_clone.emit(
                    "process-output",
                    ProcessOutputEvent {
                        id: id_clone.clone(),
                        output_type: "stderr".to_string(),
                        line: clean_line,
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
