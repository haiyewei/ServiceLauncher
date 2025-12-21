//! 核心公共模块
//!
//! - `process_manager` - 进程管理器

pub mod process_manager;

pub use process_manager::{
    add_process_fork, add_process_import, auto_start_processes_on_init, clear_process_output,
    create_process_manager, get_process, get_process_output, kill_all_processes, list_processes,
    remove_process, start_auto_start_processes, start_process, stop_process, update_process,
    ProcessConfig, ProcessInfo, ProcessManager, ProcessMode, ProcessOutput, ProcessStatus,
};
