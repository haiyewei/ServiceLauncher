import {
  Component,
  ChangeDetectionStrategy,
  inject,
  OnInit,
  OnDestroy,
  signal,
} from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatListModule } from '@angular/material/list';
import { MatMenuModule } from '@angular/material/menu';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { TranslateModule } from '@ngx-translate/core';
import { ProcessService } from '../../services/process.service';
import {
  AddProcessDialogComponent,
  AddProcessDialogResult,
} from '../processes/add-process-dialog.component';

@Component({
  selector: 'app-dashboard',
  imports: [
    RouterLink,
    MatCardModule,
    MatIconModule,
    MatButtonModule,
    MatListModule,
    MatMenuModule,
    MatDialogModule,
    TranslateModule,
  ],
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DashboardComponent implements OnInit, OnDestroy {
  private readonly dialog = inject(MatDialog);
  readonly processService = inject(ProcessService);

  // 用于触发时间更新的信号
  readonly tick = signal(Date.now());
  private tickInterval?: ReturnType<typeof setInterval>;

  ngOnInit() {
    this.processService.refresh();
    // 每秒更新一次时间显示
    this.tickInterval = setInterval(() => {
      this.tick.set(Date.now());
    }, 1000);
  }

  ngOnDestroy() {
    if (this.tickInterval) {
      clearInterval(this.tickInterval);
    }
  }

  openAddDialog(mode: 'fork' | 'import') {
    const dialogRef = this.dialog.open(AddProcessDialogComponent, {
      width: '90vw',
      maxWidth: '500px',
      data: { mode },
    });

    dialogRef.afterClosed().subscribe(async (result: AddProcessDialogResult) => {
      if (result) {
        try {
          if (result.mode === 'fork') {
            await this.processService.addProcessFork({
              name: result.name,
              executable_path: result.path,
              args: result.args,
              auto_restart: result.autoRestart,
              auto_start: result.autoStart,
            });
          } else {
            await this.processService.addProcessImport({
              name: result.name,
              source_folder: result.path,
              args: result.args,
              auto_restart: result.autoRestart,
              auto_start: result.autoStart,
            });
          }
        } catch (error) {
          console.error('Failed to add process:', error);
        }
      }
    });
  }

  async toggleProcess(id: string, status: string) {
    if (status === 'running') {
      await this.processService.stopProcess(id);
    } else {
      await this.processService.startProcess(id);
    }
  }

  getStatusIcon(status: string): string {
    switch (status) {
      case 'running':
        return 'play_circle';
      case 'stopped':
        return 'stop_circle';
      case 'error':
        return 'error';
      default:
        return 'help';
    }
  }

  getRunningTime(startedAt: number): string {
    // 使用 tick 信号触发更新
    const now = Math.floor(this.tick() / 1000);
    const diff = now - startedAt;

    if (diff < 60) {
      return `${diff}s`;
    } else if (diff < 3600) {
      const mins = Math.floor(diff / 60);
      const secs = diff % 60;
      return `${mins}m ${secs}s`;
    } else if (diff < 86400) {
      const hours = Math.floor(diff / 3600);
      const mins = Math.floor((diff % 3600) / 60);
      return `${hours}h ${mins}m`;
    } else {
      const days = Math.floor(diff / 86400);
      const hours = Math.floor((diff % 86400) / 3600);
      return `${days}d ${hours}h`;
    }
  }
}
