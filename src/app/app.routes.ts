import { Routes } from "@angular/router";
import { DashboardComponent } from "./pages/dashboard/dashboard.component";
import { ProcessesComponent } from "./pages/processes/processes.component";
import { SettingsComponent } from "./pages/settings/settings.component";

export const routes: Routes = [
  { path: "", redirectTo: "dashboard", pathMatch: "full" },
  { path: "dashboard", component: DashboardComponent },
  { path: "processes", component: ProcessesComponent },
  { path: "settings", component: SettingsComponent },
];
