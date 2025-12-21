//! System theme color utilities for Windows
//!
//! Provides functions to get the Windows system accent color.

#[cfg(windows)]
use windows::UI::ViewManagement::{UIColorType, UISettings};

#[cfg(windows)]
use std::sync::atomic::{AtomicBool, Ordering};
#[cfg(windows)]
use tauri::{AppHandle, Emitter};

#[cfg(windows)]
static LISTENER_STARTED: AtomicBool = AtomicBool::new(false);

/// Get the Windows system accent color as RGB values
///
/// Returns the accent color as (r, g, b) tuple, or None if not available
#[cfg(windows)]
pub fn get_system_accent_color() -> Option<(u8, u8, u8)> {
    let settings = UISettings::new().ok()?;
    let color = settings.GetColorValue(UIColorType::Accent).ok()?;
    Some((color.R, color.G, color.B))
}

/// Get the Windows system accent color as hex string
///
/// Returns the accent color as "#RRGGBB" format, or None if not available
#[cfg(windows)]
pub fn get_system_accent_color_hex() -> Option<String> {
    let (r, g, b) = get_system_accent_color()?;
    Some(format!("#{:02x}{:02x}{:02x}", r, g, b))
}

/// Tauri command to get system accent color
#[tauri::command]
pub fn get_accent_color() -> Option<AccentColor> {
    #[cfg(windows)]
    {
        let (r, g, b) = get_system_accent_color()?;
        Some(AccentColor {
            r,
            g,
            b,
            hex: format!("#{:02x}{:02x}{:02x}", r, g, b),
        })
    }
    #[cfg(not(windows))]
    {
        None
    }
}

/// Accent color response structure
#[derive(serde::Serialize, Clone)]
pub struct AccentColor {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub hex: String,
}

/// Setup listener for Windows accent color changes
#[cfg(windows)]
pub fn setup_accent_color_listener(app_handle: AppHandle) {
    // 防止重复启动监听器
    if LISTENER_STARTED.swap(true, Ordering::SeqCst) {
        return;
    }

    std::thread::spawn(move || {
        // 记录上一次的颜色
        let mut last_color = get_system_accent_color();

        loop {
            std::thread::sleep(std::time::Duration::from_millis(500));

            let current_color = get_system_accent_color();
            if current_color != last_color {
                last_color = current_color;

                if let Some((r, g, b)) = current_color {
                    let color = AccentColor {
                        r,
                        g,
                        b,
                        hex: format!("#{:02x}{:02x}{:02x}", r, g, b),
                    };
                    let _ = app_handle.emit("accent-color-changed", color);
                }
            }
        }
    });
}

/// Setup listener for Windows accent color changes (non-Windows stub)
#[cfg(not(windows))]
pub fn setup_accent_color_listener(_app_handle: tauri::AppHandle) {
    // No-op on non-Windows platforms
}
