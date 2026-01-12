import { Component, inject } from "@angular/core";
import { FormBuilder, ReactiveFormsModule, Validators } from "@angular/forms";
import {
  MatDialogRef,
  MAT_DIALOG_DATA,
  MatDialogModule,
} from "@angular/material/dialog";
import { MatFormFieldModule } from "@angular/material/form-field";
import { MatInputModule } from "@angular/material/input";
import { MatButtonModule } from "@angular/material/button";
import { MatCheckboxModule } from "@angular/material/checkbox";
import { MatIconModule } from "@angular/material/icon";
import { MatRadioModule } from "@angular/material/radio";
import { TranslateModule } from "@ngx-translate/core";
import { open } from "@tauri-apps/plugin-dialog";
import { CommandType } from "../../models/process.model";

export interface AddProcessDialogData {
  mode: "fork" | "import";
}

export interface AddProcessDialogResult {
  mode: "fork" | "import";
  name: string;
  workingDir: string;
  executablePath?: string;
  path: string; // 保留用于 import 模式
  args: string[];
  autoRestart: boolean;
  autoStart: boolean;
  commandType: CommandType;
}

@Component({
  selector: "app-add-process-dialog",
  standalone: true,
  imports: [
    ReactiveFormsModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatCheckboxModule,
    MatIconModule,
    MatRadioModule,
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

        <!-- 命令类型选择器 -->
        <div class="command-type-section">
          <label class="section-label">{{
            "process.commandType" | translate
          }}</label>
          <mat-radio-group
            formControlName="commandType"
            class="command-type-group"
          >
            <mat-radio-button value="executable">
              <div class="radio-content">
                <mat-icon>terminal</mat-icon>
                <span>{{ "process.commandTypeExecutable" | translate }}</span>
              </div>
            </mat-radio-button>
            <mat-radio-button value="shell">
              <div class="radio-content">
                <mat-icon>code</mat-icon>
                <span>{{ "process.commandTypeShell" | translate }}</span>
              </div>
            </mat-radio-button>
          </mat-radio-group>
          @if (form.value.commandType === "shell") {
            <p class="command-type-hint">
              {{ "process.shellCommandHint" | translate }}
            </p>
          }
        </div>

        @if (data.mode === "fork") {
          <mat-form-field appearance="outline">
            <mat-label>{{ "process.workingDir" | translate }}</mat-label>
            <input matInput formControlName="workingDir" readonly />
            <button
              mat-icon-button
              matSuffix
              type="button"
              (click)="browseWorkingDir()"
            >
              <mat-icon>folder_open</mat-icon>
            </button>
            <mat-hint>{{ "process.workingDirHint" | translate }}</mat-hint>
          </mat-form-field>

          @if (form.value.commandType === "executable") {
            <mat-form-field appearance="outline">
              <mat-label>{{ "process.executablePath" | translate }}</mat-label>
              <input matInput formControlName="executablePath" readonly />
              <button
                mat-icon-button
                matSuffix
                type="button"
                (click)="browseExecutable()"
              >
                <mat-icon>insert_drive_file</mat-icon>
              </button>
              <mat-hint>{{
                "process.executablePathHint" | translate
              }}</mat-hint>
            </mat-form-field>
          } @else {
            <mat-form-field appearance="outline">
              <mat-label>{{ "process.shellCommand" | translate }}</mat-label>
              <input
                matInput
                formControlName="executablePath"
                placeholder="npm start"
              />
              <mat-hint>{{
                "process.shellCommandInputHint" | translate
              }}</mat-hint>
            </mat-form-field>
          }
        } @else {
          <mat-form-field appearance="outline">
            <mat-label>{{ "process.sourceFolder" | translate }}</mat-label>
            <input matInput formControlName="path" readonly />
            <button
              mat-icon-button
              matSuffix
              type="button"
              (click)="browsePath()"
            >
              <mat-icon>folder_open</mat-icon>
            </button>
            <mat-hint>{{ "process.importHint" | translate }}</mat-hint>
          </mat-form-field>

          @if (form.value.commandType === "executable") {
            <mat-form-field appearance="outline">
              <mat-label>{{ "process.executablePath" | translate }}</mat-label>
              <input matInput formControlName="executablePath" readonly />
              <button
                mat-icon-button
                matSuffix
                type="button"
                (click)="browseExecutable()"
              >
                <mat-icon>insert_drive_file</mat-icon>
              </button>
              <mat-hint>{{
                "process.executablePathHint" | translate
              }}</mat-hint>
            </mat-form-field>
          } @else {
            <mat-form-field appearance="outline">
              <mat-label>{{ "process.shellCommand" | translate }}</mat-label>
              <input
                matInput
                formControlName="executablePath"
                placeholder="npm start"
              />
              <mat-hint>{{
                "process.shellCommandInputHint" | translate
              }}</mat-hint>
            </mat-form-field>
          }
        }

        <mat-form-field appearance="outline">
          <mat-label>{{ "process.args" | translate }}</mat-label>
          <input
            matInput
            formControlName="args"
            placeholder="--port 8080 --host localhost"
          />
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
      <button mat-button mat-dialog-close>
        {{ "common.cancel" | translate }}
      </button>
      <button
        mat-raised-button
        color="primary"
        [disabled]="form.invalid"
        (click)="submit()"
      >
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

      .command-type-section {
        margin-bottom: 8px;
      }

      .section-label {
        display: block;
        font-size: 12px;
        color: var(--mat-form-field-label-text-color, rgba(0, 0, 0, 0.6));
        margin-bottom: 8px;
      }

      .command-type-group {
        display: flex;
        gap: 16px;
      }

      .radio-content {
        display: flex;
        align-items: center;
        gap: 4px;
      }

      .radio-content mat-icon {
        font-size: 18px;
        width: 18px;
        height: 18px;
      }

      .command-type-hint {
        font-size: 12px;
        color: var(--mat-form-field-hint-text-color, rgba(0, 0, 0, 0.6));
        margin-top: 4px;
        margin-bottom: 0;
      }

      @media (max-width: 480px) {
        .process-form {
          gap: 4px;
        }

        .command-type-group {
          flex-direction: column;
          gap: 8px;
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
    name: ["", Validators.required],
    workingDir: [""], // fork 模式必填，在构造函数中动态设置验证
    executablePath: [""], // fork 模式可选
    path: [""], // import 模式必填
    args: [""],
    autoRestart: [false],
    autoStart: [false],
    commandType: ["executable" as CommandType], // 默认为 executable
  });

  constructor() {
    // 根据模式动态设置验证规则
    if (this.data.mode === "fork") {
      this.form.get("workingDir")?.setValidators(Validators.required);
    } else {
      this.form.get("path")?.setValidators(Validators.required);
    }
  }

  async browseWorkingDir() {
    const path = await open({ directory: true });
    if (path) {
      this.form.patchValue({ workingDir: path as string });
      if (!this.form.value.name) {
        const folderName = (path as string).split(/[/\\]/).pop() || "";
        this.form.patchValue({ name: folderName });
      }
    }
  }

  async browseExecutable() {
    const path = await open({
      filters: [
        { name: "Executable", extensions: ["exe", "bat", "cmd", "sh", "*"] },
      ],
    });
    if (path) {
      this.form.patchValue({ executablePath: path as string });
      if (!this.form.value.name) {
        const fileName = (path as string).split(/[/\\]/).pop() || "";
        const name = fileName.replace(/\.[^.]+$/, "");
        this.form.patchValue({ name });
      }
    }
  }

  async browsePath() {
    const path = await open({ directory: true });
    if (path) {
      this.form.patchValue({ path: path as string });
      if (!this.form.value.name) {
        const folderName = (path as string).split(/[/\\]/).pop() || "";
        this.form.patchValue({ name: folderName });
      }
    }
  }

  submit() {
    if (this.form.valid) {
      const value = this.form.value;
      const result: AddProcessDialogResult = {
        mode: this.data.mode,
        name: value.name!,
        workingDir: value.workingDir || "",
        executablePath: value.executablePath || undefined,
        path: value.path || "",
        args: value.args ? value.args.split(/\s+/).filter(Boolean) : [],
        autoRestart: value.autoRestart || false,
        autoStart: value.autoStart || false,
        commandType: (value.commandType as CommandType) || "executable",
      };
      this.dialogRef.close(result);
    }
  }
}
