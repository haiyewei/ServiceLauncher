import { Injectable, signal } from "@angular/core";

const STORAGE_KEY = "sidebar_collapsed";

@Injectable({ providedIn: "root" })
export class SidebarService {
  collapsed = signal(this.loadState());

  toggle() {
    this.collapsed.update((v) => {
      const newValue = !v;
      this.saveState(newValue);
      return newValue;
    });
  }

  private loadState(): boolean {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      return stored === "true";
    } catch {
      return false;
    }
  }

  private saveState(collapsed: boolean): void {
    try {
      localStorage.setItem(STORAGE_KEY, String(collapsed));
    } catch {
      // ignore
    }
  }
}
