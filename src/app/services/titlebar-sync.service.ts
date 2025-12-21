import { Injectable, inject, effect } from "@angular/core";
import { MatDialog } from "@angular/material/dialog";
import { invoke } from "@tauri-apps/api/core";
import { ThemeService } from "./theme.service";

/** Titlebar 颜色同步服务 */
@Injectable({
    providedIn: "root",
})
export class TitlebarSyncService {
    private openDialogCount = 0;
    private themeService = inject(ThemeService);

    constructor(private dialog: MatDialog) {
        this.setupDialogListener();
        this.setupThemeListener();
    }

    /** 初始化 titlebar 颜色 */
    init(): void {
        setTimeout(() => this.syncToSurface(), 100);
    }

    /** 设置 MatDialog 监听器 */
    private setupDialogListener(): void {
        // 监听对话框打开事件
        this.dialog.afterOpened.subscribe(() => {
            this.openDialogCount++;
            if (this.openDialogCount === 1) {
                this.setDarkOverlay();
            }
        });

        // 监听对话框关闭事件
        this.dialog.afterAllClosed.subscribe(() => {
            this.openDialogCount = 0;
            this.syncToSurface();
        });
    }

    /** 设置主题变化监听器 */
    private setupThemeListener(): void {
        // 监听主题变化，同步 titlebar 颜色
        effect(() => {
            // 读取 darkMode 和 themeVersion signal 触发依赖
            this.themeService.darkMode();
            this.themeService.themeVersion();
            // 延迟执行以确保 CSS 变量已更新
            setTimeout(() => this.syncToSurface(), 50);
        });
    }

    /** 同步 titlebar 颜色到默认表面颜色 */
    async syncToSurface(): Promise<void> {
        const color = getComputedStyle(document.documentElement)
            .getPropertyValue("--mat-sys-surface")
            .trim();
        const rgb = this.parseColor(color);
        if (rgb) {
            await invoke("set_titlebar_color", rgb);
        }
    }

    /** 设置 titlebar 为暗色（对话框打开时） */
    async setDarkOverlay(): Promise<void> {
        const color = getComputedStyle(document.documentElement)
            .getPropertyValue("--mat-sys-surface")
            .trim();
        const rgb = this.parseColor(color);
        if (rgb) {
            // MatDialog 默认使用 rgba(0,0,0,0.32) 作为背景遮罩
            // 计算公式: result = surface * (1 - alpha) + overlay * alpha
            // 其中 overlay = 0 (黑色), alpha = 0.32
            const alpha = 0.32;
            const darkRgb = {
                r: Math.round(rgb.r * (1 - alpha)),
                g: Math.round(rgb.g * (1 - alpha)),
                b: Math.round(rgb.b * (1 - alpha)),
            };
            await invoke("set_titlebar_color", darkRgb);
        }
    }

    /** 设置自定义颜色 */
    async setColor(r: number, g: number, b: number): Promise<void> {
        await invoke("set_titlebar_color", { r, g, b });
    }

    parseColor(color: string): { r: number; g: number; b: number } | null {
        const rgbMatch = color.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/);
        if (rgbMatch) {
            return { r: +rgbMatch[1], g: +rgbMatch[2], b: +rgbMatch[3] };
        }
        const hexMatch = color.match(/^#([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i);
        if (hexMatch) {
            return {
                r: parseInt(hexMatch[1], 16),
                g: parseInt(hexMatch[2], 16),
                b: parseInt(hexMatch[3], 16),
            };
        }
        return null;
    }
}
