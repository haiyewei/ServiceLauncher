//! 进程管理器类型定义

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// 命令类型：定义如何执行命令
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
#[serde(rename_all = "lowercase")]
pub enum CommandType {
    /// 直接执行可执行文件
    #[default]
    Executable,
    /// 通过系统 shell 执行命令
    Shell,
}

/// 进程启动模式
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum ProcessMode {
    Fork,
    Import,
}

/// 进程状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum ProcessStatus {
    Running,
    Stopped,
    Error,
}

/// 进程配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessConfig {
    pub id: String,
    pub name: String,
    pub mode: ProcessMode,
    /// 命令类型：Executable（直接执行）或 Shell（通过 shell 执行）
    #[serde(default)]
    pub command_type: CommandType,
    pub command: String,
    pub args: Vec<String>,
    pub working_dir: String,
    pub source_path: Option<String>,
    pub env: HashMap<String, String>,
    pub auto_restart: bool,
    pub auto_start: bool, // 跟随应用启动
    pub created_at: i64,
}

/// 进程信息（运行时状态）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessInfo {
    pub id: String,
    pub name: String,
    pub mode: ProcessMode,
    /// 命令类型：Executable（直接执行）或 Shell（通过 shell 执行）
    #[serde(default)]
    pub command_type: CommandType,
    pub command: String,
    pub args: Vec<String>,
    pub working_dir: String,
    pub source_path: Option<String>,
    pub status: ProcessStatus,
    pub pid: Option<u32>,
    pub auto_restart: bool,
    pub auto_start: bool,
    pub started_at: Option<i64>,
    pub created_at: i64,
    pub has_output: bool,
}

/// 进程输出事件
#[derive(Debug, Clone, Serialize)]
pub struct ProcessOutputEvent {
    pub id: String,
    pub output_type: String,
    pub line: String,
    pub timestamp: i64,
}
