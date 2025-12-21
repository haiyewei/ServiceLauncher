import { Component } from "@angular/core";
import { LogoComponent } from "../logo/logo.component";

@Component({
  selector: "app-topbar",
  imports: [LogoComponent],
  templateUrl: "./topbar.component.html",
  styleUrl: "./topbar.component.scss",
})
export class TopbarComponent {}
