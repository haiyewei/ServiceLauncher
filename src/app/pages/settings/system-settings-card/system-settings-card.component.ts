import {
  Component,
  ChangeDetectionStrategy,
  inject,
  signal,
  OnInit,
} from "@angular/core";
import { MatCardModule } from "@angular/material/card";
import { MatFormFieldModule } from "@angular/material/form-field";
import { MatIconModule } from "@angular/material/icon";
import { MatSelectModule } from "@angular/material/select";
import { MatSlideToggleModule } from "@angular/material/slide-toggle";
import { TranslateModule } from "@ngx-translate/core";
import { LanguageService } from "../../../services/language.service";
import { ThemeService, PaletteType } from "../../../services/theme.service";
import { enable, disable, isEnabled } from "@tauri-apps/plugin-autostart";
import { invoke } from "@tauri-apps/api/core";

@Component({
  selector: "app-system-settings-card",
  imports: [
    MatCardModule,
    MatFormFieldModule,
    MatIconModule,
    MatSelectModule,
    MatSlideToggleModule,
    TranslateModule,
  ],
  templateUrl: "./system-settings-card.component.html",
  styleUrl: "./system-settings-card.component.scss",
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SystemSettingsCardComponent implements OnInit {
  langService = inject(LanguageService);
  themeService = inject(ThemeService);

  autoStartEnabled = signal(false);
  silentStartEnabled = signal(false);
  showPalettePanel = signal(false);

  async ngOnInit() {
    await this.loadAutoStartState();
    await this.loadSilentStartState();
  }

  private async loadAutoStartState() {
    try {
      const enabled = await isEnabled();
      this.autoStartEnabled.set(enabled);
    } catch (e) {
      console.error("Failed to check autostart state:", e);
    }
  }

  private async loadSilentStartState() {
    try {
      const value = await invoke<string | null>("get_download_setting", {
        key: "silent_start",
      });
      this.silentStartEnabled.set(value === "true");
    } catch (e) {
      console.error("Failed to check silent start state:", e);
    }
  }

  async onAutoStartChange(enabled: boolean) {
    try {
      if (enabled) {
        await enable();
      } else {
        await disable();
      }
      this.autoStartEnabled.set(enabled);
    } catch (e) {
      console.error("Failed to toggle autostart:", e);
      // 恢复原状态
      this.autoStartEnabled.set(!enabled);
    }
  }

  async onSilentStartChange(enabled: boolean) {
    try {
      await invoke("set_download_setting", {
        key: "silent_start",
        value: enabled ? "true" : "false",
      });
      this.silentStartEnabled.set(enabled);
    } catch (e) {
      console.error("Failed to toggle silent start:", e);
      // 恢复原状态
      this.silentStartEnabled.set(!enabled);
    }
  }

  togglePalettePanel() {
    this.showPalettePanel.update((v) => !v);
  }

  getCurrentPaletteColor(): string {
    const palette = this.themeService.paletteOptions.find(
      (p) => p.value === this.themeService.selectedPalette(),
    );
    return palette?.color ?? "#03a9f4";
  }

  selectPalette(value: PaletteType) {
    this.themeService.setPalette(value);
    this.showPalettePanel.set(false);
  }
}
