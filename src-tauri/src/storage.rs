use rusqlite::{params, Connection};
use std::path::PathBuf;
use std::sync::Mutex;
use tauri::{AppHandle, Manager};

use crate::paths::{get_default_data_dir, get_default_logs_dir};

pub struct DbState(pub Mutex<Connection>);

pub fn init_db(app: AppHandle) -> Result<Connection, rusqlite::Error> {
    let app_dir = app
        .path()
        .app_data_dir()
        .expect("Failed to get app data dir");
    std::fs::create_dir_all(&app_dir).expect("Failed to create app data dir");

    let db_path: PathBuf = app_dir.join("servicelauncher.db");
    let conn = Connection::open(db_path)?;

    // Create settings table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT UNIQUE NOT NULL,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
        )",
        [],
    )?;

    // Create processes table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS processes (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            mode TEXT NOT NULL,
            command TEXT NOT NULL,
            args TEXT NOT NULL,
            working_dir TEXT NOT NULL,
            source_path TEXT,
            env TEXT NOT NULL,
            auto_restart INTEGER NOT NULL DEFAULT 0,
            auto_start INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
        )",
        [],
    )?;

    // 初始化默认设置（仅当设置不存在时）
    init_default_settings(&conn, &app);

    Ok(conn)
}

/// 初始化默认设置
/// 仅当设置不存在时才设置默认值
fn init_default_settings(conn: &Connection, app: &AppHandle) {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;

    // 设置默认日志路径: {app_data_dir}/Logs/
    if let Some(logs_dir) = get_default_logs_dir(app) {
        let _ = conn.execute(
            "INSERT OR IGNORE INTO settings (key, value, updated_at) VALUES ('log_path', ?1, ?2)",
            params![logs_dir, now],
        );
    }

    // 设置默认数据库路径: {app_data_dir}/Data/
    if let Some(data_dir) = get_default_data_dir(app) {
        let _ = conn.execute(
            "INSERT OR IGNORE INTO settings (key, value, updated_at) VALUES ('database_path', ?1, ?2)",
            params![data_dir, now],
        );
    }
}

// ============ Settings CRUD Operations ============

/// 获取设置值
#[tauri::command]
pub fn get_download_setting(
    state: tauri::State<DbState>,
    key: String,
) -> Result<Option<String>, String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;

    let result: Result<String, _> = conn.query_row(
        "SELECT value FROM settings WHERE key = ?1",
        params![key],
        |row| row.get(0),
    );

    match result {
        Ok(value) => Ok(Some(value)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e.to_string()),
    }
}

/// 设置设置值
#[tauri::command]
pub fn set_download_setting(
    state: tauri::State<DbState>,
    key: String,
    value: String,
) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;

    conn.execute(
        "INSERT INTO settings (key, value, updated_at) VALUES (?1, ?2, ?3)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
        params![key, value, now],
    )
    .map_err(|e| e.to_string())?;

    Ok(())
}

// ============ Process Config CRUD Operations ============

use crate::core::{ProcessConfig, ProcessMode};

/// 保存进程配置到数据库
pub fn save_process_config(conn: &Connection, config: &ProcessConfig) -> Result<(), String> {
    let mode = match config.mode {
        ProcessMode::Fork => "fork",
        ProcessMode::Import => "import",
    };
    let args_json = serde_json::to_string(&config.args).map_err(|e| e.to_string())?;
    let env_json = serde_json::to_string(&config.env).map_err(|e| e.to_string())?;

    conn.execute(
        "INSERT INTO processes (id, name, mode, command, args, working_dir, source_path, env, auto_restart, auto_start, created_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
         ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            args = excluded.args,
            auto_restart = excluded.auto_restart,
            auto_start = excluded.auto_start",
        params![
            config.id,
            config.name,
            mode,
            config.command,
            args_json,
            config.working_dir,
            config.source_path,
            env_json,
            config.auto_restart as i32,
            config.auto_start as i32,
            config.created_at
        ],
    )
    .map_err(|e| e.to_string())?;

    Ok(())
}

/// 从数据库删除进程配置
pub fn delete_process_config(conn: &Connection, id: &str) -> Result<(), String> {
    conn.execute("DELETE FROM processes WHERE id = ?1", params![id])
        .map_err(|e| e.to_string())?;
    Ok(())
}

/// 初始化进程管理器：从数据库加载所有进程配置到内存
pub fn init_process_manager_from_db(
    conn: &Connection,
    manager: &crate::core::ProcessManager,
) -> Result<(), String> {
    let configs = load_all_process_configs(conn)?;

    let mut state = manager.lock().map_err(|e| e.to_string())?;
    for config in configs {
        let id = config.id.clone();
        state.configs.insert(id.clone(), config);
        state
            .outputs
            .insert(id, crate::core::ProcessOutput::default());
    }

    Ok(())
}

/// 从数据库加载所有进程配置
pub fn load_all_process_configs(conn: &Connection) -> Result<Vec<ProcessConfig>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT id, name, mode, command, args, working_dir, source_path, env, auto_restart, auto_start, created_at
             FROM processes ORDER BY created_at DESC",
        )
        .map_err(|e| e.to_string())?;

    let configs = stmt
        .query_map([], |row| {
            let id: String = row.get(0)?;
            let name: String = row.get(1)?;
            let mode_str: String = row.get(2)?;
            let command: String = row.get(3)?;
            let args_json: String = row.get(4)?;
            let working_dir: String = row.get(5)?;
            let source_path: Option<String> = row.get(6)?;
            let env_json: String = row.get(7)?;
            let auto_restart: i32 = row.get(8)?;
            let auto_start: i32 = row.get(9)?;
            let created_at: i64 = row.get(10)?;

            let mode = if mode_str == "fork" {
                ProcessMode::Fork
            } else {
                ProcessMode::Import
            };

            let args: Vec<String> = serde_json::from_str(&args_json).unwrap_or_default();
            let env: std::collections::HashMap<String, String> =
                serde_json::from_str(&env_json).unwrap_or_default();

            Ok(ProcessConfig {
                id,
                name,
                mode,
                command,
                args,
                working_dir,
                source_path,
                env,
                auto_restart: auto_restart != 0,
                auto_start: auto_start != 0,
                created_at,
            })
        })
        .map_err(|e| e.to_string())?;

    configs
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())
}
