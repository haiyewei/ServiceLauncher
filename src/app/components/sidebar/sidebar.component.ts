import { Component, ChangeDetectionStrategy, inject } from "@angular/core";
import { RouterLink, RouterLinkActive } from "@angular/router";
import { MatListModule } from "@angular/material/list";
import { MatIconModule } from "@angular/material/icon";
import { TranslatePipe } from "@ngx-translate/core";
import { SidebarService } from "../../services/sidebar.service";

@Component({
  selector: "app-sidebar",
  imports: [
    RouterLink,
    RouterLinkActive,
    MatListModule,
    MatIconModule,
    TranslatePipe,
  ],
  host: { "[class.collapsed]": "sidebar.collapsed()" },
  templateUrl: "./sidebar.component.html",
  styleUrl: "./sidebar.component.scss",
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SidebarComponent {
  sidebar = inject(SidebarService);
  toggle() {
    this.sidebar.toggle();
  }
}
