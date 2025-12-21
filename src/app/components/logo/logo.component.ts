import {
  Component,
  ChangeDetectionStrategy,
  inject,
  computed,
} from "@angular/core";
import { Router, NavigationEnd } from "@angular/router";
import { toSignal } from "@angular/core/rxjs-interop";
import { filter, map, switchMap, startWith } from "rxjs/operators";
import { SidebarService } from "../../services/sidebar.service";
import { APP_NAME, APP_LOGO } from "../../constants";
import { TranslateService } from "@ngx-translate/core";

const TITLE_KEYS: Record<string, string> = {
  dashboard: "sidebar.dashboard",
  scrape: "sidebar.scrape",
  downloads: "sidebar.downloads",
  settings: "sidebar.settings",
};

@Component({
  selector: "app-logo",
  templateUrl: "./logo.component.html",
  styleUrl: "./logo.component.scss",
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LogoComponent {
  sidebar = inject(SidebarService);
  private router = inject(Router);
  private translate = inject(TranslateService);
  logo = APP_LOGO;

  private pageTitle = toSignal(
    this.router.events.pipe(
      filter((e) => e instanceof NavigationEnd),
      map(
        (e) =>
          TITLE_KEYS[(e as NavigationEnd).urlAfterRedirects.split("/")[1]] ||
          "",
      ),
      startWith(TITLE_KEYS[this.router.url.split("/")[1]] || ""),
      switchMap((key) =>
        key
          ? this.translate.stream(key)
          : this.translate.onLangChange.pipe(
              map(() => ""),
              startWith(""),
            ),
      ),
    ),
    { initialValue: "" },
  );

  title = computed(() =>
    this.sidebar.collapsed() ? `${APP_NAME} - ${this.pageTitle()}` : APP_NAME,
  );
}
