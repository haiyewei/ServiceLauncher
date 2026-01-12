import {
  Component,
  ChangeDetectionStrategy,
  inject,
  OnInit,
} from "@angular/core";
import { MatCardModule } from "@angular/material/card";
import { MatIconModule } from "@angular/material/icon";
import { MatButtonModule } from "@angular/material/button";
import { MatTableModule } from "@angular/material/table";
import { MatChipsModule } from "@angular/material/chips";
import { MatMenuModule } from "@angular/material/menu";
import { MatTooltipModule } from "@angular/material/tooltip";
import { MatProgressSpinnerModule } from "@angular/material/progress-spinner";
import { MatDialog, MatDialogModule } from "@angular/material/dialog";
import { TranslateModule } from "@ngx-translate/core";
import { ProcessService } from "../../services/process.service";
import { ProcessInfo } from "../../models/process.model";
import {
  AddProcessDialogComponent,
  AddProcessDialogResult,
} from "./add-process-dialog.component";
import {
  EditProcessDialogComponent,
  EditProcessDialogResult,
} from "./edit-process-dialog.component";
import { ProcessOutputDialogComponent } from "./process-output-dialog.component";

@Component({
  selector: "app-processes",
  standalone: true,
  imports: [
    MatCardModule,
    MatIconModule,
    MatButtonModule,
    MatTableModule,
    MatChipsModule,
    MatMenuModule,
    MatTooltipModule,
    MatProgressSpinnerModule,
    MatDialogModule,
    TranslateModule,
  ],
  templateUrl: "./processes.component.html",
  styleUrl: "./processes.component.scss",
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ProcessesComponent implements OnInit {
  private readonly dialog = inject(MatDialog);
  readonly processService = inject(ProcessService);

  displayedColumns = [
    "status",
    "name",
    "command",
    "mode",
    "commandType",
    "pid",
    "actions",
  ];

  ngOnInit() {
    this.processService.refresh();
  }

  openAddDialog(mode: "fork" | "import") {
    const dialogRef = this.dialog.open(AddProcessDialogComponent, {
      width: "90vw",
      maxWidth: "500px",
      data: { mode },
    });

    dialogRef
      .afterClosed()
      .subscribe(async (result: AddProcessDialogResult) => {
        if (result) {
          try {
            if (result.mode === "fork") {
              await this.processService.addProcessFork({
                name: result.name,
                working_dir: result.workingDir,
                executable_path: result.executablePath,
                args: result.args,
                auto_restart: result.autoRestart,
                auto_start: result.autoStart,
                command_type: result.commandType,
              });
            } else {
              await this.processService.addProcessImport({
                name: result.name,
                source_folder: result.path,
                executable_path: result.executablePath,
                args: result.args,
                auto_restart: result.autoRestart,
                auto_start: result.autoStart,
                command_type: result.commandType,
              });
            }
          } catch (error) {
            console.error("Failed to add process:", error);
          }
        }
      });
  }

  openEditDialog(process: ProcessInfo) {
    const dialogRef = this.dialog.open(EditProcessDialogComponent, {
      width: "90vw",
      maxWidth: "500px",
      data: { process },
    });

    dialogRef
      .afterClosed()
      .subscribe(async (result: EditProcessDialogResult) => {
        if (result) {
          try {
            await this.processService.updateProcess({
              id: result.id,
              name: result.name,
              working_dir: result.workingDir,
              executable_path: result.executablePath,
              args: result.args,
              auto_restart: result.autoRestart,
              auto_start: result.autoStart,
              command_type: result.commandType,
            });
          } catch (error) {
            console.error("Failed to update process:", error);
          }
        }
      });
  }

  openOutputDialog(process: ProcessInfo) {
    this.dialog.open(ProcessOutputDialogComponent, {
      width: "90vw",
      maxWidth: "800px",
      data: { id: process.id, name: process.name },
    });
  }

  async toggleProcess(process: ProcessInfo) {
    if (process.status === "running") {
      await this.processService.stopProcess(process.id);
    } else {
      await this.processService.startProcess(process.id);
    }
  }

  async removeProcess(id: string) {
    await this.processService.removeProcess(id);
  }

  getStatusIcon(status: string): string {
    switch (status) {
      case "running":
        return "play_circle";
      case "stopped":
        return "stop_circle";
      case "error":
        return "error";
      default:
        return "help";
    }
  }
}
