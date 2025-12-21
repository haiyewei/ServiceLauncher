// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
pub mod core;
pub mod paths;
pub mod storage;
pub mod system_theme;

use core::{
    add_process_fork, add_process_import, auto_start_processes_on_init, clear_process_output,
    create_process_manager, get_process, get_process_output, kill_all_processes, list_processes,
    remove_process, start_auto_start_processes, start_process, stop_process, update_process,
};
use storage::{
    get_download_setting, init_db, init_process_manager_from_db, set_download_setting, DbState,
};
use tauri::menu::{Menu, MenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{Manager, WindowEvent};

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[tauri::command]
fn set_titlebar_color(window: tauri::Window, r: u8, g: u8, b: u8) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        use windows::Win32::Foundation::HWND;
        use windows::Win32::Graphics::Dwm::{DwmSetWindowAttribute, DWMWA_CAPTION_COLOR};
        let raw_hwnd = window.hwnd().map_err(|e| e.to_string())?;
        let hwnd = HWND(raw_hwnd.0);
        let color: u32 = (b as u32) << 16 | (g as u32) << 8 | (r as u32);
        unsafe {
            DwmSetWindowAttribute(
                hwnd,
                DWMWA_CAPTION_COLOR,
                &color as *const _ as *const _,
                std::mem::size_of::<u32>() as u32,
            )
            .map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            // 当尝试启动第二个实例时，显示并聚焦现有窗口
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
            }
        }))
        .plugin(
            tauri_plugin_autostart::Builder::new()
                .args(["--silent"])
                .build(),
        )
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .setup(|app| {
            let conn = init_db(app.handle().clone()).expect("Failed to initialize database");

            // 初始化进程管理器
            let process_manager = create_process_manager();

            // 从数据库加载进程配置到内存
            init_process_manager_from_db(&conn, &process_manager)
                .expect("Failed to load process configs from database");

            app.manage(DbState(std::sync::Mutex::new(conn)));
            app.manage(process_manager.clone());

            // 启动设置为跟随应用启动的进程
            let app_handle = app.handle().clone();
            auto_start_processes_on_init(&app_handle, &process_manager);

            // 检查是否静默启动（通过命令行参数 --silent 触发，且用户启用了静默启动设置）
            let has_silent_arg = std::env::args().any(|arg| arg == "--silent");
            if has_silent_arg {
                // 检查用户是否启用了静默启动
                let silent_enabled = {
                    let db = app.state::<DbState>();
                    let conn = db.0.lock().unwrap();
                    conn.query_row(
                        "SELECT value FROM settings WHERE key = 'silent_start'",
                        [],
                        |row| row.get::<_, String>(0),
                    )
                    .map(|v| v == "true")
                    .unwrap_or(false)
                };

                if silent_enabled {
                    // 静默启动时隐藏主窗口
                    if let Some(window) = app.get_webview_window("main") {
                        let _ = window.hide();
                    }
                }
            }

            // 设置系统托盘图标
            let app_handle_for_tray = app.handle().clone();

            // 创建托盘菜单
            let show_item = MenuItem::with_id(app, "show", "显示窗口", true, None::<&str>)?;
            let quit_item = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;
            let tray_menu = Menu::with_items(app, &[&show_item, &quit_item])?;

            TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .tooltip("ServiceLauncher")
                .menu(&tray_menu)
                .on_menu_event(move |app, event| match event.id.as_ref() {
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                    "quit" => {
                        // 退出前终止所有子进程
                        if let Some(manager) = app.try_state::<core::ProcessManager>() {
                            kill_all_processes(manager.inner());
                        }
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(move |_tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        // 左键点击托盘图标，显示主窗口
                        if let Some(window) = app_handle_for_tray.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;

            // 设置 Windows 主题色变化监听器
            system_theme::setup_accent_color_listener(app_handle);

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            greet,
            set_titlebar_color,
            system_theme::get_accent_color,
            // 设置管理命令
            get_download_setting,
            set_download_setting,
            // 进程管理命令
            add_process_fork,
            add_process_import,
            remove_process,
            start_process,
            stop_process,
            list_processes,
            get_process,
            get_process_output,
            clear_process_output,
            update_process,
            start_auto_start_processes,
        ])
        .on_window_event(|window, event| {
            // 关闭窗口时隐藏到托盘而不是退出
            if let WindowEvent::CloseRequested { api, .. } = event {
                window.hide().unwrap();
                api.prevent_close();
            }
        })
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(|app, event| {
            if let tauri::RunEvent::Exit = event {
                // 应用退出时终止所有子进程
                if let Some(manager) = app.try_state::<core::ProcessManager>() {
                    kill_all_processes(manager.inner());
                }
            }
        });
}
