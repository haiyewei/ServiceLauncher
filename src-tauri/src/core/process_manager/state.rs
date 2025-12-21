//! 进程管理器状态

use std::collections::HashMap;
use std::process::Child;
use std::sync::{Arc, Mutex};

use super::types::ProcessConfig;

/// 输出缓冲限制常量
pub const MAX_OUTPUT_LINES: usize = 1000;
pub const MAX_LINE_LENGTH: usize = 4096; // 单行最大 4KB
pub const MAX_TOTAL_OUTPUT_BYTES: usize = 2 * 1024 * 1024; // 每个进程最大 2MB 输出

/// 运行中的进程句柄
pub(crate) struct RunningProcess {
    pub child: Child,
    #[allow(dead_code)]
    pub config: ProcessConfig,
    pub started_at: i64,
}

/// 进程输出缓冲
#[derive(Default)]
pub struct ProcessOutput {
    pub lines: Vec<(i64, String, String)>, // (timestamp, type, line)
    pub total_bytes: usize,                // 当前总字节数
}

impl ProcessOutput {
    /// 添加一行输出，自动管理内存
    pub fn push_line(&mut self, timestamp: i64, output_type: String, mut line: String) {
        // 截断过长的单行
        if line.len() > MAX_LINE_LENGTH {
            line.truncate(MAX_LINE_LENGTH);
            line.push_str("...[truncated]");
        }

        let line_bytes = line.len() + output_type.len() + 16; // 估算内存占用
        self.total_bytes += line_bytes;
        self.lines.push((timestamp, output_type, line));

        // 按行数限制
        while self.lines.len() > MAX_OUTPUT_LINES {
            if let Some((_, t, l)) = self.lines.first() {
                self.total_bytes = self.total_bytes.saturating_sub(l.len() + t.len() + 16);
            }
            self.lines.remove(0);
        }

        // 按总字节数限制
        while self.total_bytes > MAX_TOTAL_OUTPUT_BYTES && !self.lines.is_empty() {
            if let Some((_, t, l)) = self.lines.first() {
                self.total_bytes = self.total_bytes.saturating_sub(l.len() + t.len() + 16);
            }
            self.lines.remove(0);
        }
    }

    /// 清空输出
    pub fn clear(&mut self) {
        self.lines.clear();
        self.total_bytes = 0;
    }
}

/// 进程管理器状态
pub struct ProcessManagerState {
    pub(crate) processes: HashMap<String, RunningProcess>,
    pub(crate) configs: HashMap<String, ProcessConfig>,
    pub(crate) outputs: HashMap<String, ProcessOutput>,
}

impl ProcessManagerState {
    pub fn new() -> Self {
        Self {
            processes: HashMap::new(),
            configs: HashMap::new(),
            outputs: HashMap::new(),
        }
    }
}

impl Default for ProcessManagerState {
    fn default() -> Self {
        Self::new()
    }
}

pub type ProcessManager = Arc<Mutex<ProcessManagerState>>;

/// 创建进程管理器
pub fn create_process_manager() -> ProcessManager {
    Arc::new(Mutex::new(ProcessManagerState::new()))
}

/// 终止所有运行中的子进程
pub fn kill_all_processes(manager: &ProcessManager) {
    if let Ok(mut state) = manager.lock() {
        for (id, mut running) in state.processes.drain() {
            if let Err(e) = running.child.kill() {
                eprintln!("Failed to kill process {}: {}", id, e);
            } else {
                println!("Killed process: {}", id);
            }
            // 等待进程完全退出
            let _ = running.child.wait();
        }
    }
}
