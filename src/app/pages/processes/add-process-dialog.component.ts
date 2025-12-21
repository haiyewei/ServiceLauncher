import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import {
  MatDialogRef,
  MAT_DIALOG_DATA,
  MatDialogModule,
} from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatIconModule } from '@angular/material/icon';
import { TranslateModule } from '@ngx-translate/core';
import { open } from '@tauri-apps/plugin-dialog';

export interface AddProcessDialogData {
  mode: 'fork' | 'import';
}

export interface AddProcessDialogResult {
  mode: 'fork' | 'import';
  name: string;
  path: string;
  args: string[];
  autoRestart: boolean;
  autoStart: boolean;
}

@Component({
  selector: 'app-add-process-dialog',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatCheckboxModule,
    MatIconModule,
    TranslateModule,
  ],
  template: `
    <h2 mat-dialog-title>{{ "process.addTitle" | translate }}</h2>
    <mat-dialog-content>
      <form [formGroup]="form" class="process-form">
        <mat-form-field appearance="outline">
          <mat-label>{{ "process.name" | translate }}</mat-label>
          <input matInput formControlName="name" />
        </mat-form-field>

        <mat-form-field appearance="outline">
          <mat-label>{{ data.mode === 'fork' ? ("process.executablePath" | translate) : ("process.sourceFolder" | translate) }}</mat-label>
          <input matInput formControlName="path" readonly />
          <button mat-icon-button matSuffix type="button" (click)="browsePath()">
            <mat-icon>folder_open</mat-icon>
          </button>
          <mat-hint>{{ data.mode === 'fork' ? ("process.forkHint" | translate) : ("process.importHint" | translate) }}</mat-hint>
        </mat-form-field>

        <mat-form-field appearance="outline">
          <mat-label>{{ "process.args" | translate }}</mat-label>
          <input matInput formControlName="args" placeholder="--port 8080 --host localhost" />
          <mat-hint>{{ "process.argsHint" | translate }}</mat-hint>
        </mat-form-field>

        <mat-checkbox formControlName="autoRestart">
          {{ "process.autoRestart" | translate }}
        </mat-checkbox>

        <mat-checkbox formControlName="autoStart">
          {{ "process.autoStart" | translate }}
        </mat-checkbox>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>{{ "common.cancel" | translate }}</button>
      <button mat-raised-button color="primary" [disabled]="form.invalid" (click)="submit()">
        {{ "common.confirm" | translate }}
      </button>
    </mat-dialog-actions>
  `,
  styles: [
    `
      :host {
        display: block;
        width: 100%;
      }

      .process-form {
        display: flex;
        flex-direction: column;
        gap: 8px;
        width: 100%;
      }

      mat-form-field {
        width: 100%;
      }

      @media (max-width: 480px) {
        .process-form {
          gap: 4px;
        }
      }
    `,
  ],
})
export class AddProcessDialogComponent {
  private readonly fb = inject(FormBuilder);
  private readonly dialogRef = inject(MatDialogRef<AddProcessDialogComponent>);
  readonly data = inject<AddProcessDialogData>(MAT_DIALOG_DATA);

  form = this.fb.group({
    name: ['', Validators.required],
    path: ['', Validators.required],
    args: [''],
    autoRestart: [false],
    autoStart: [false],
  });

  async browsePath() {
    if (this.data.mode === 'fork') {
      const path = await open({
        filters: [
          { name: 'Executable', extensions: ['exe', 'bat', 'cmd', 'sh', '*'] },
        ],
      });
      if (path) {
        this.form.patchValue({ path: path as string });
        if (!this.form.value.name) {
          const fileName = (path as string).split(/[/\\]/).pop() || '';
          const name = fileName.replace(/\.[^.]+$/, '');
          this.form.patchValue({ name });
        }
      }
    } else {
      const path = await open({ directory: true });
      if (path) {
        this.form.patchValue({ path: path as string });
        if (!this.form.value.name) {
          const folderName = (path as string).split(/[/\\]/).pop() || '';
          this.form.patchValue({ name: folderName });
        }
      }
    }
  }

  submit() {
    if (this.form.valid) {
      const value = this.form.value;
      const result: AddProcessDialogResult = {
        mode: this.data.mode,
        name: value.name!,
        path: value.path!,
        args: value.args ? value.args.split(/\s+/).filter(Boolean) : [],
        autoRestart: value.autoRestart || false,
        autoStart: value.autoStart || false,
      };
      this.dialogRef.close(result);
    }
  }
}
