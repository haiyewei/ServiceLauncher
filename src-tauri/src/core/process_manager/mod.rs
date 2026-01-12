//! 进程管理器模块
//!
//! 提供进程启动、停止、监控功能
//! - Fork 模式：选择可执行文件，以其所在文件夹作为工作目录执行
//! - 导入模式：选择文件夹，复制到应用工作目录的子目录中执行
//! - 实时输出监听

mod config;
mod lifecycle;
mod output;
mod query;
mod runner;
mod state;
mod types;
mod utils;

// 导出类型
pub use types::{
    CommandType, ProcessConfig, ProcessInfo, ProcessMode, ProcessOutputEvent, ProcessStatus,
};

// 导出状态管理
pub use state::{
    create_process_manager, kill_all_processes, ProcessManager, ProcessManagerState, ProcessOutput,
};

// 导出配置管理命令
pub use config::{add_process_fork, add_process_import, remove_process, update_process};

// 导出生命周期管理命令
pub use lifecycle::{
    auto_start_processes_on_init, start_auto_start_processes, start_process, stop_process,
};

// 导出查询命令
pub use query::{get_process, list_processes};

// 导出输出管理命令
pub use output::{clear_process_output, get_process_output};
