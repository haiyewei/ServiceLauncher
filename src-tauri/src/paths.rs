//! 路径管理模块
//!
//! 统一管理应用程序的各种路径：
//! - 数据库路径: {app_data_dir}/Data/
//! - 日志路径: {app_data_dir}/Logs/

use std::path::PathBuf;
use tauri::{AppHandle, Manager};

/// 应用路径管理器
pub struct AppPaths {
    /// 应用数据目录 (用户数据)
    pub app_data_dir: PathBuf,
}

impl AppPaths {
    /// 从 Tauri AppHandle 创建路径管理器
    pub fn new(app: &AppHandle) -> Result<Self, String> {
        let app_data_dir = app
            .path()
            .app_data_dir()
            .map_err(|e| format!("Failed to get app data dir: {}", e))?;

        Ok(Self { app_data_dir })
    }

    /// 获取数据库目录路径: {app_data_dir}/Data/
    pub fn data_dir(&self) -> PathBuf {
        self.app_data_dir.join("Data")
    }

    /// 获取日志目录路径: {app_data_dir}/Logs/
    pub fn logs_dir(&self) -> PathBuf {
        self.app_data_dir.join("Logs")
    }

    /// 确保所有必要的目录存在
    pub fn ensure_directories(&self) -> Result<(), String> {
        std::fs::create_dir_all(self.data_dir())
            .map_err(|e| format!("Failed to create data directory: {}", e))?;
        std::fs::create_dir_all(self.logs_dir())
            .map_err(|e| format!("Failed to create logs directory: {}", e))?;
        Ok(())
    }
}

/// 获取默认的日志目录路径
pub fn get_default_logs_dir(app: &AppHandle) -> Option<String> {
    AppPaths::new(app)
        .ok()
        .map(|paths| paths.logs_dir().to_string_lossy().to_string())
}

/// 获取默认的数据目录路径
pub fn get_default_data_dir(app: &AppHandle) -> Option<String> {
    AppPaths::new(app)
        .ok()
        .map(|paths| paths.data_dir().to_string_lossy().to_string())
}
