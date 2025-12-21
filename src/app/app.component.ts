import { Component, inject, OnInit } from "@angular/core";
import { RouterOutlet } from "@angular/router";
import { SidebarComponent } from "./components/sidebar/sidebar.component";
import { TopbarComponent } from "./components/topbar/topbar.component";
import { ThemeService } from "./services/theme.service";
import { TitlebarSyncService } from "./services/titlebar-sync.service";

@Component({
  selector: "app-root",
  imports: [RouterOutlet, SidebarComponent, TopbarComponent],
  templateUrl: "./app.component.html",
  styleUrl: "./app.component.scss",
})
export class AppComponent implements OnInit {
  // 初始化主题服务
  private themeService = inject(ThemeService);
  private titlebarSyncService = inject(TitlebarSyncService);

  ngOnInit(): void {
    this.titlebarSyncService.init();
  }
}
