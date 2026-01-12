import { Component, ChangeDetectionStrategy } from "@angular/core";
import { SystemSettingsCardComponent } from "./system-settings-card/system-settings-card.component";

@Component({
  selector: "app-settings",
  imports: [SystemSettingsCardComponent],
  templateUrl: "./settings.component.html",
  styleUrl: "./settings.component.scss",
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SettingsComponent {}
