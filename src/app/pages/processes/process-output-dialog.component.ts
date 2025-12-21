import {
  Component,
  inject,
  OnInit,
  OnDestroy,
  signal,
  ElementRef,
  ViewChild,
  AfterViewChecked,
} from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { TranslateModule } from '@ngx-translate/core';
import { ProcessService } from '../../services/process.service';
import { ProcessOutputEvent } from '../../models/process.model';

export interface ProcessOutputDialogData {
  id: string;
  name: string;
}

interface OutputLine {
  timestamp: number;
  type: string;
  line: string;
}

@Component({
  selector: 'app-process-output-dialog',
  standalone: true,
  imports: [MatDialogModule, MatButtonModule, MatIconModule, TranslateModule],
  template: `
    <h2 mat-dialog-title>{{ data.name }} - {{ "process.output" | translate }}</h2>
    <mat-dialog-content>
      <div class="output-container" #outputContainer>
        @for (line of outputLines(); track $index) {
        <div class="output-line" [class.stderr]="line.type === 'stderr'">
          <span class="timestamp">{{ formatTime(line.timestamp) }}</span>
          <span class="content">{{ line.line }}</span>
        </div>
        }
        @if (outputLines().length === 0) {
        <div class="empty-output">{{ "process.noOutput" | translate }}</div>
        }
      </div>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button (click)="clearOutput()">
        <mat-icon>delete</mat-icon>
        {{ "process.clearOutput" | translate }}
      </button>
      <button mat-button mat-dialog-close>{{ "common.close" | translate }}</button>
    </mat-dialog-actions>
  `,
  styles: [
    `
      :host {
        display: block;
        width: 100%;
      }

      .output-container {
        width: 100%;
        min-height: 200px;
        max-height: 60vh;
        overflow-y: auto;
        background: var(--mat-sys-surface-container);
        border-radius: 8px;
        padding: 12px;
        font-family: monospace;
        font-size: 13px;
        box-sizing: border-box;
      }

      .output-line {
        display: flex;
        gap: 12px;
        padding: 2px 0;
        line-height: 1.4;

        &.stderr {
          color: var(--mat-sys-error);
        }
      }

      .timestamp {
        color: var(--mat-sys-outline);
        flex-shrink: 0;
      }

      .content {
        white-space: pre-wrap;
        word-break: break-all;
        flex: 1;
      }

      .empty-output {
        color: var(--mat-sys-on-surface-variant);
        text-align: center;
        padding: 48px;
      }

      @media (max-width: 600px) {
        .output-container {
          font-size: 12px;
          padding: 8px;
        }

        .output-line {
          flex-direction: column;
          gap: 4px;
        }

        .timestamp {
          font-size: 11px;
        }
      }
    `,
  ],
})
export class ProcessOutputDialogComponent
  implements OnInit, OnDestroy, AfterViewChecked {
  private readonly processService = inject(ProcessService);
  readonly data = inject<ProcessOutputDialogData>(MAT_DIALOG_DATA);

  @ViewChild('outputContainer') outputContainer!: ElementRef<HTMLDivElement>;

  outputLines = signal<OutputLine[]>([]);
  private shouldScroll = true;

  ngOnInit() {
    this.loadOutput();
    this.subscribeOutput();
  }

  ngOnDestroy() {
    this.processService.unsubscribeOutput(this.data.id);
  }

  ngAfterViewChecked() {
    if (this.shouldScroll) {
      this.scrollToBottom();
    }
  }

  private async loadOutput() {
    const lines = await this.processService.getProcessOutput(this.data.id);
    this.outputLines.set(
      lines.map(([timestamp, type, line]) => ({ timestamp, type, line }))
    );
  }

  private async subscribeOutput() {
    await this.processService.subscribeOutput(
      this.data.id,
      (event: ProcessOutputEvent) => {
        this.outputLines.update((lines) => [
          ...lines,
          {
            timestamp: event.timestamp,
            type: event.output_type,
            line: event.line,
          },
        ]);
        this.shouldScroll = true;
      }
    );
  }

  private scrollToBottom() {
    if (this.outputContainer) {
      const el = this.outputContainer.nativeElement;
      el.scrollTop = el.scrollHeight;
      this.shouldScroll = false;
    }
  }

  async clearOutput() {
    await this.processService.clearProcessOutput(this.data.id);
    this.outputLines.set([]);
  }

  formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return date.toLocaleTimeString('en-US', { hour12: false });
  }
}
