import { Injectable, signal, effect, OnDestroy } from "@angular/core";
import { invoke } from "@tauri-apps/api/core";
import { listen, UnlistenFn } from "@tauri-apps/api/event";
import {
  argbFromHex,
  themeFromSourceColor,
  hexFromArgb,
} from "@material/material-color-utilities";

export type ThemeMode = "light" | "dark";

// MD3 预设调色板
export type PaletteType =
  | "red"
  | "green"
  | "blue"
  | "yellow"
  | "cyan"
  | "magenta"
  | "orange"
  | "chartreuse"
  | "spring-green"
  | "azure"
  | "violet"
  | "rose";

export interface PaletteOption {
  value: PaletteType;
  label: string;
  color: string; // 用于显示的代表色
}

export const PALETTE_OPTIONS: PaletteOption[] = [
  { value: "red", label: "Red", color: "#f44336" },
  { value: "green", label: "Green", color: "#4caf50" },
  { value: "blue", label: "Blue", color: "#2196f3" },
  { value: "yellow", label: "Yellow", color: "#ffeb3b" },
  { value: "cyan", label: "Cyan", color: "#00bcd4" },
  { value: "magenta", label: "Magenta", color: "#e91e63" },
  { value: "orange", label: "Orange", color: "#ff9800" },
  { value: "chartreuse", label: "Chartreuse", color: "#cddc39" },
  { value: "spring-green", label: "Spring Green", color: "#00e676" },
  { value: "azure", label: "Azure", color: "#03a9f4" },
  { value: "violet", label: "Violet", color: "#9c27b0" },
  { value: "rose", label: "Rose", color: "#f06292" },
];

interface AccentColor {
  r: number;
  g: number;
  b: number;
  hex: string;
}

@Injectable({
  providedIn: "root",
})
export class ThemeService implements OnDestroy {
  private readonly STORAGE_KEY_FOLLOW_SYSTEM = "theme_follow_system";
  private readonly STORAGE_KEY_DARK_MODE = "theme_dark_mode";
  private readonly STORAGE_KEY_USE_SYSTEM_ACCENT = "theme_use_system_accent";
  private readonly STORAGE_KEY_PALETTE = "theme_palette";
  private readonly STORAGE_KEY_ACCENT_COLOR = "theme_accent_color_cache";

  followSystem = signal(true);
  darkMode = signal(false);
  useSystemAccent = signal(true);
  accentColor = signal<string | null>(null);
  selectedPalette = signal<PaletteType>("azure");

  // 主题变化计数器，用于通知其他组件主题已更新
  themeVersion = signal(0);

  readonly paletteOptions = PALETTE_OPTIONS;

  private systemDarkMode = signal(false);
  private mediaQuery: MediaQueryList;
  private accentColorUnlisten: UnlistenFn | null = null;
  private initialized = false;

  constructor() {
    // 监听系统主题变化
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    this.systemDarkMode.set(this.mediaQuery.matches);

    this.mediaQuery.addEventListener("change", (e) => {
      this.systemDarkMode.set(e.matches);
      if (this.followSystem()) {
        this.applyTheme(e.matches);
      }
    });

    // 从 localStorage 加载设置（同步，快速）
    this.loadSettings();

    // 监听设置变化并应用主题
    effect(() => {
      const follow = this.followSystem();
      const dark = this.darkMode();
      const systemDark = this.systemDarkMode();

      if (follow) {
        this.applyTheme(systemDark);
      } else {
        this.applyTheme(dark);
      }

      // 重新应用主题色（因为深浅模式切换需要不同的色调）
      if (this.useSystemAccent() && this.accentColor()) {
        this.applyAccentColor(this.accentColor()!);
      }
    });

    // 延迟加载系统主题色，避免阻塞应用启动
    this.deferredInit();
  }

  /** 延迟初始化：在应用渲染完成后加载系统主题色 */
  private deferredInit() {
    if (this.initialized) return;
    this.initialized = true;

    // 使用 requestIdleCallback 或 setTimeout 延迟执行，确保不阻塞首屏渲染
    const initAccentColor = () => {
      this.loadSystemAccentColor();
      this.setupAccentColorListener();
    };

    if ("requestIdleCallback" in window) {
      (window as any).requestIdleCallback(initAccentColor, { timeout: 1000 });
    } else {
      setTimeout(initAccentColor, 100);
    }
  }

  private loadSettings() {
    const followSystem = localStorage.getItem(this.STORAGE_KEY_FOLLOW_SYSTEM);
    const darkMode = localStorage.getItem(this.STORAGE_KEY_DARK_MODE);
    const useSystemAccent = localStorage.getItem(
      this.STORAGE_KEY_USE_SYSTEM_ACCENT,
    );
    const palette = localStorage.getItem(this.STORAGE_KEY_PALETTE);
    const cachedAccentColor = localStorage.getItem(
      this.STORAGE_KEY_ACCENT_COLOR,
    );

    if (followSystem !== null) {
      this.followSystem.set(followSystem === "true");
    }
    if (darkMode !== null) {
      this.darkMode.set(darkMode === "true");
    }
    if (useSystemAccent !== null) {
      this.useSystemAccent.set(useSystemAccent === "true");
    }
    if (palette !== null) {
      this.selectedPalette.set(palette as PaletteType);
    }

    // 从缓存加载系统主题色（同步，快速）
    if (cachedAccentColor) {
      this.accentColor.set(cachedAccentColor);
    }

    // 初始应用主题
    if (this.followSystem()) {
      this.applyTheme(this.systemDarkMode());
    } else {
      this.applyTheme(this.darkMode());
    }

    // 应用调色板或缓存的系统主题色
    if (this.useSystemAccent() && cachedAccentColor) {
      // 使用缓存的系统主题色，移除调色板类
      PALETTE_OPTIONS.forEach((p) => {
        document.documentElement.classList.remove(`palette-${p.value}`);
      });
      this.applyAccentColor(cachedAccentColor);
    } else {
      this.applyPalette();
    }
  }

  setFollowSystem(value: boolean) {
    this.followSystem.set(value);
    localStorage.setItem(this.STORAGE_KEY_FOLLOW_SYSTEM, String(value));

    // 如果开启跟随系统，立即应用系统主题
    if (value) {
      this.darkMode.set(this.systemDarkMode());
    }
  }

  setDarkMode(value: boolean) {
    this.darkMode.set(value);
    localStorage.setItem(this.STORAGE_KEY_DARK_MODE, String(value));
  }

  /** 设置调色板 */
  setPalette(palette: PaletteType) {
    this.selectedPalette.set(palette);
    localStorage.setItem(this.STORAGE_KEY_PALETTE, palette);
    this.applyPalette();
  }

  /** 应用调色板到 HTML 类 */
  private applyPalette() {
    const html = document.documentElement;
    // 移除所有调色板类
    PALETTE_OPTIONS.forEach((p) => {
      html.classList.remove(`palette-${p.value}`);
    });

    // 如果不使用系统主题色，应用选择的调色板
    if (!this.useSystemAccent()) {
      html.classList.add(`palette-${this.selectedPalette()}`);
      this.removeAccentColor(); // 移除动态 CSS 变量
    }

    // 通知主题已更新
    this.notifyThemeChange();
  }

  /** 通知主题变化 */
  private notifyThemeChange() {
    // 延迟通知，确保 CSS 变量已更新
    setTimeout(() => {
      this.themeVersion.update((v) => v + 1);
    }, 50);
  }

  private applyTheme(dark: boolean) {
    const html = document.documentElement;
    if (dark) {
      html.classList.add("dark-theme");
      html.classList.remove("light-theme");
    } else {
      html.classList.add("light-theme");
      html.classList.remove("dark-theme");
    }
    // 同步更新 darkMode signal（用于 UI 显示）
    if (this.followSystem()) {
      this.darkMode.set(dark);
    }
  }

  /** 加载系统主题色并缓存 */
  private async loadSystemAccentColor() {
    try {
      const color = await invoke<AccentColor | null>("get_accent_color");
      if (color) {
        this.accentColor.set(color.hex);
        // 缓存到 localStorage
        localStorage.setItem(this.STORAGE_KEY_ACCENT_COLOR, color.hex);
        if (this.useSystemAccent()) {
          this.applyAccentColor(color.hex);
        }
      }
    } catch (e) {
      console.error("Failed to get system accent color:", e);
    }
  }

  /** 监听系统主题色变化 */
  private async setupAccentColorListener() {
    try {
      this.accentColorUnlisten = await listen<AccentColor>(
        "accent-color-changed",
        (event) => {
          const color = event.payload;
          this.accentColor.set(color.hex);
          // 更新缓存
          localStorage.setItem(this.STORAGE_KEY_ACCENT_COLOR, color.hex);
          if (this.useSystemAccent()) {
            this.applyAccentColor(color.hex);
          }
        },
      );
    } catch (e) {
      console.error("Failed to setup accent color listener:", e);
    }
  }

  ngOnDestroy() {
    if (this.accentColorUnlisten) {
      this.accentColorUnlisten();
    }
  }

  /** 设置是否使用系统主题色 */
  setUseSystemAccent(value: boolean) {
    this.useSystemAccent.set(value);
    localStorage.setItem(this.STORAGE_KEY_USE_SYSTEM_ACCENT, String(value));

    if (value && this.accentColor()) {
      // 使用系统主题色，移除调色板类
      PALETTE_OPTIONS.forEach((p) => {
        document.documentElement.classList.remove(`palette-${p.value}`);
      });
      this.applyAccentColor(this.accentColor()!);
      this.notifyThemeChange();
    } else {
      // 使用预设调色板
      this.applyPalette();
    }
  }

  /** 应用主题色到 CSS 变量 (使用 material-color-utilities 生成 MD3 调色板) */
  private applyAccentColor(hex: string) {
    const theme = themeFromSourceColor(argbFromHex(hex));
    const scheme = this.darkMode() ? theme.schemes.dark : theme.schemes.light;
    const palettes = theme.palettes;
    const root = document.documentElement;

    // Primary 色系
    root.style.setProperty("--mat-sys-primary", hexFromArgb(scheme.primary));
    root.style.setProperty(
      "--mat-sys-on-primary",
      hexFromArgb(scheme.onPrimary),
    );
    root.style.setProperty(
      "--mat-sys-primary-container",
      hexFromArgb(scheme.primaryContainer),
    );
    root.style.setProperty(
      "--mat-sys-on-primary-container",
      hexFromArgb(scheme.onPrimaryContainer),
    );
    root.style.setProperty(
      "--mat-sys-inverse-primary",
      hexFromArgb(scheme.inversePrimary),
    );
    root.style.setProperty(
      "--mat-sys-primary-fixed",
      hexFromArgb(palettes.primary.tone(90)),
    );
    root.style.setProperty(
      "--mat-sys-primary-fixed-dim",
      hexFromArgb(palettes.primary.tone(80)),
    );
    root.style.setProperty(
      "--mat-sys-on-primary-fixed",
      hexFromArgb(palettes.primary.tone(10)),
    );
    root.style.setProperty(
      "--mat-sys-on-primary-fixed-variant",
      hexFromArgb(palettes.primary.tone(30)),
    );

    // Secondary 色系
    root.style.setProperty(
      "--mat-sys-secondary",
      hexFromArgb(scheme.secondary),
    );
    root.style.setProperty(
      "--mat-sys-on-secondary",
      hexFromArgb(scheme.onSecondary),
    );
    root.style.setProperty(
      "--mat-sys-secondary-container",
      hexFromArgb(scheme.secondaryContainer),
    );
    root.style.setProperty(
      "--mat-sys-on-secondary-container",
      hexFromArgb(scheme.onSecondaryContainer),
    );
    root.style.setProperty(
      "--mat-sys-secondary-fixed",
      hexFromArgb(palettes.secondary.tone(90)),
    );
    root.style.setProperty(
      "--mat-sys-secondary-fixed-dim",
      hexFromArgb(palettes.secondary.tone(80)),
    );
    root.style.setProperty(
      "--mat-sys-on-secondary-fixed",
      hexFromArgb(palettes.secondary.tone(10)),
    );
    root.style.setProperty(
      "--mat-sys-on-secondary-fixed-variant",
      hexFromArgb(palettes.secondary.tone(30)),
    );

    // Tertiary 色系
    root.style.setProperty("--mat-sys-tertiary", hexFromArgb(scheme.tertiary));
    root.style.setProperty(
      "--mat-sys-on-tertiary",
      hexFromArgb(scheme.onTertiary),
    );
    root.style.setProperty(
      "--mat-sys-tertiary-container",
      hexFromArgb(scheme.tertiaryContainer),
    );
    root.style.setProperty(
      "--mat-sys-on-tertiary-container",
      hexFromArgb(scheme.onTertiaryContainer),
    );
    root.style.setProperty(
      "--mat-sys-tertiary-fixed",
      hexFromArgb(palettes.tertiary.tone(90)),
    );
    root.style.setProperty(
      "--mat-sys-tertiary-fixed-dim",
      hexFromArgb(palettes.tertiary.tone(80)),
    );
    root.style.setProperty(
      "--mat-sys-on-tertiary-fixed",
      hexFromArgb(palettes.tertiary.tone(10)),
    );
    root.style.setProperty(
      "--mat-sys-on-tertiary-fixed-variant",
      hexFromArgb(palettes.tertiary.tone(30)),
    );

    // Error 色系
    root.style.setProperty("--mat-sys-error", hexFromArgb(scheme.error));
    root.style.setProperty("--mat-sys-on-error", hexFromArgb(scheme.onError));
    root.style.setProperty(
      "--mat-sys-error-container",
      hexFromArgb(scheme.errorContainer),
    );
    root.style.setProperty(
      "--mat-sys-on-error-container",
      hexFromArgb(scheme.onErrorContainer),
    );

    // Surface 色系
    root.style.setProperty("--mat-sys-surface", hexFromArgb(scheme.surface));
    root.style.setProperty(
      "--mat-sys-on-surface",
      hexFromArgb(scheme.onSurface),
    );
    root.style.setProperty(
      "--mat-sys-surface-variant",
      hexFromArgb(scheme.surfaceVariant),
    );
    root.style.setProperty(
      "--mat-sys-on-surface-variant",
      hexFromArgb(scheme.onSurfaceVariant),
    );
    root.style.setProperty(
      "--mat-sys-inverse-surface",
      hexFromArgb(scheme.inverseSurface),
    );
    root.style.setProperty(
      "--mat-sys-inverse-on-surface",
      hexFromArgb(scheme.inverseOnSurface),
    );

    // Surface Container 色系 (MD3 新增)
    const isDark = this.darkMode();
    root.style.setProperty(
      "--mat-sys-surface-dim",
      hexFromArgb(palettes.neutral.tone(isDark ? 6 : 87)),
    );
    root.style.setProperty(
      "--mat-sys-surface-bright",
      hexFromArgb(palettes.neutral.tone(isDark ? 24 : 98)),
    );
    root.style.setProperty(
      "--mat-sys-surface-container-lowest",
      hexFromArgb(palettes.neutral.tone(isDark ? 4 : 100)),
    );
    root.style.setProperty(
      "--mat-sys-surface-container-low",
      hexFromArgb(palettes.neutral.tone(isDark ? 10 : 96)),
    );
    root.style.setProperty(
      "--mat-sys-surface-container",
      hexFromArgb(palettes.neutral.tone(isDark ? 12 : 94)),
    );
    root.style.setProperty(
      "--mat-sys-surface-container-high",
      hexFromArgb(palettes.neutral.tone(isDark ? 17 : 92)),
    );
    root.style.setProperty(
      "--mat-sys-surface-container-highest",
      hexFromArgb(palettes.neutral.tone(isDark ? 22 : 90)),
    );
    root.style.setProperty(
      "--mat-sys-surface-tint",
      hexFromArgb(scheme.primary),
    );

    // Background & Outline
    root.style.setProperty(
      "--mat-sys-background",
      hexFromArgb(scheme.background),
    );
    root.style.setProperty(
      "--mat-sys-on-background",
      hexFromArgb(scheme.onBackground),
    );
    root.style.setProperty("--mat-sys-outline", hexFromArgb(scheme.outline));
    root.style.setProperty(
      "--mat-sys-outline-variant",
      hexFromArgb(scheme.outlineVariant),
    );

    // Scrim & Shadow
    root.style.setProperty("--mat-sys-scrim", hexFromArgb(scheme.scrim));
    root.style.setProperty("--mat-sys-shadow", hexFromArgb(scheme.shadow));
  }

  /** 移除自定义主题色 */
  private removeAccentColor() {
    const root = document.documentElement;
    const props = [
      // Primary
      "--mat-sys-primary",
      "--mat-sys-on-primary",
      "--mat-sys-primary-container",
      "--mat-sys-on-primary-container",
      "--mat-sys-inverse-primary",
      "--mat-sys-primary-fixed",
      "--mat-sys-primary-fixed-dim",
      "--mat-sys-on-primary-fixed",
      "--mat-sys-on-primary-fixed-variant",
      // Secondary
      "--mat-sys-secondary",
      "--mat-sys-on-secondary",
      "--mat-sys-secondary-container",
      "--mat-sys-on-secondary-container",
      "--mat-sys-secondary-fixed",
      "--mat-sys-secondary-fixed-dim",
      "--mat-sys-on-secondary-fixed",
      "--mat-sys-on-secondary-fixed-variant",
      // Tertiary
      "--mat-sys-tertiary",
      "--mat-sys-on-tertiary",
      "--mat-sys-tertiary-container",
      "--mat-sys-on-tertiary-container",
      "--mat-sys-tertiary-fixed",
      "--mat-sys-tertiary-fixed-dim",
      "--mat-sys-on-tertiary-fixed",
      "--mat-sys-on-tertiary-fixed-variant",
      // Error
      "--mat-sys-error",
      "--mat-sys-on-error",
      "--mat-sys-error-container",
      "--mat-sys-on-error-container",
      // Surface
      "--mat-sys-surface",
      "--mat-sys-on-surface",
      "--mat-sys-surface-variant",
      "--mat-sys-on-surface-variant",
      "--mat-sys-inverse-surface",
      "--mat-sys-inverse-on-surface",
      // Surface Container
      "--mat-sys-surface-dim",
      "--mat-sys-surface-bright",
      "--mat-sys-surface-container-lowest",
      "--mat-sys-surface-container-low",
      "--mat-sys-surface-container",
      "--mat-sys-surface-container-high",
      "--mat-sys-surface-container-highest",
      "--mat-sys-surface-tint",
      // Background & Outline
      "--mat-sys-background",
      "--mat-sys-on-background",
      "--mat-sys-outline",
      "--mat-sys-outline-variant",
      // Scrim & Shadow
      "--mat-sys-scrim",
      "--mat-sys-shadow",
    ];
    props.forEach((prop) => root.style.removeProperty(prop));
  }
}
