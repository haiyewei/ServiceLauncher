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
import { TranslateModule } from '@ngx-translate/core';
import { ProcessInfo } from '../../models/process.model';

export interface EditProcessDialogData {
    process: ProcessInfo;
}

export interface EditProcessDialogResult {
    id: string;
    name: string;
    args: string[];
    autoRestart: boolean;
    autoStart: boolean;
}

@Component({
    selector: 'app-edit-process-dialog',
    standalone: true,
    imports: [
        ReactiveFormsModule,
        MatDialogModule,
        MatFormFieldModule,
        MatInputModule,
        MatButtonModule,
        MatCheckboxModule,
        TranslateModule,
    ],
    template: `
    <h2 mat-dialog-title>{{ 'process.editTitle' | translate }}</h2>
    <mat-dialog-content>
      <form [formGroup]="form" class="process-form">
        <mat-form-field appearance="outline">
          <mat-label>{{ 'process.name' | translate }}</mat-label>
          <input matInput formControlName="name" />
        </mat-form-field>

        <mat-form-field appearance="outline">
          <mat-label>{{ 'process.command' | translate }}</mat-label>
          <input matInput [value]="data.process.command" readonly disabled />
        </mat-form-field>

        <mat-form-field appearance="outline">
          <mat-label>{{ 'process.args' | translate }}</mat-label>
          <input
            matInput
            formControlName="args"
            placeholder="--port 8080 --host localhost"
          />
          <mat-hint>{{ 'process.argsHint' | translate }}</mat-hint>
        </mat-form-field>

        <mat-checkbox formControlName="autoRestart">
          {{ 'process.autoRestart' | translate }}
        </mat-checkbox>

        <mat-checkbox formControlName="autoStart">
          {{ 'process.autoStart' | translate }}
        </mat-checkbox>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>{{ 'common.cancel' | translate }}</button>
      <button
        mat-raised-button
        color="primary"
        [disabled]="form.invalid"
        (click)="submit()"
      >
        {{ 'common.confirm' | translate }}
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
    `,
    ],
})
export class EditProcessDialogComponent {
    private readonly fb = inject(FormBuilder);
    private readonly dialogRef = inject(MatDialogRef<EditProcessDialogComponent>);
    readonly data = inject<EditProcessDialogData>(MAT_DIALOG_DATA);

    form = this.fb.group({
        name: [this.data.process.name, Validators.required],
        args: [this.data.process.args.join(' ')],
        autoRestart: [this.data.process.auto_restart],
        autoStart: [this.data.process.auto_start],
    });

    submit() {
        if (this.form.valid) {
            const value = this.form.value;
            const result: EditProcessDialogResult = {
                id: this.data.process.id,
                name: value.name!,
                args: value.args ? value.args.split(/\s+/).filter(Boolean) : [],
                autoRestart: value.autoRestart || false,
                autoStart: value.autoStart || false,
            };
            this.dialogRef.close(result);
        }
    }
}
