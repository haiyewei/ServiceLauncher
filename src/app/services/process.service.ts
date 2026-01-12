import { Injectable, signal, computed } from "@angular/core";
import { invoke } from "@tauri-apps/api/core";
import { listen, UnlistenFn } from "@tauri-apps/api/event";
import {
  ProcessInfo,
  ProcessConfig,
  AddProcessForkParams,
  AddProcessImportParams,
  UpdateProcessParams,
  ProcessOutputEvent,
  ProcessOutputLine,
} from "../models/process.model";

@Injectable({ providedIn: "root" })
export class ProcessService {
  private readonly _processes = signal<ProcessInfo[]>([]);
  private readonly _loading = signal(false);
  private outputListeners = new Map<string, UnlistenFn>();

  readonly processes = this._processes.asReadonly();
  readonly loading = this._loading.asReadonly();

  readonly runningCount = computed(
    () => this._processes().filter((p) => p.status === "running").length,
  );

  readonly stoppedCount = computed(
    () => this._processes().filter((p) => p.status === "stopped").length,
  );

  constructor() {
    this.setupEventListener();
  }

  private async setupEventListener() {
    await listen("process-status-changed", () => {
      this.refresh();
    });
  }

  async refresh(): Promise<void> {
    this._loading.set(true);
    try {
      const processes = await invoke<ProcessInfo[]>("list_processes");
      this._processes.set(processes);
    } catch (error) {
      console.error("Failed to list processes:", error);
    } finally {
      this._loading.set(false);
    }
  }

  /** Fork 模式：选择可执行文件 */
  async addProcessFork(params: AddProcessForkParams): Promise<ProcessConfig> {
    const config = await invoke<ProcessConfig>("add_process_fork", {
      name: params.name,
      workingDir: params.working_dir,
      executablePath: params.executable_path,
      args: params.args,
      autoRestart: params.auto_restart,
      autoStart: params.auto_start,
      commandType: params.command_type,
    });
    await this.refresh();
    return config;
  }

  /** 导入模式：选择文件夹 */
  async addProcessImport(
    params: AddProcessImportParams,
  ): Promise<ProcessConfig> {
    const config = await invoke<ProcessConfig>("add_process_import", {
      name: params.name,
      sourceFolder: params.source_folder,
      executablePath: params.executable_path,
      args: params.args,
      autoRestart: params.auto_restart,
      autoStart: params.auto_start,
      commandType: params.command_type,
    });
    await this.refresh();
    return config;
  }

  /** 更新进程配置 */
  async updateProcess(params: UpdateProcessParams): Promise<ProcessConfig> {
    const config = await invoke<ProcessConfig>("update_process", {
      id: params.id,
      name: params.name,
      workingDir: params.working_dir,
      executablePath: params.executable_path,
      args: params.args,
      autoRestart: params.auto_restart,
      autoStart: params.auto_start,
      commandType: params.command_type,
    });
    await this.refresh();
    return config;
  }

  /** 启动所有设置为跟随应用启动的进程 */
  async startAutoStartProcesses(): Promise<string[]> {
    return invoke<string[]>("start_auto_start_processes");
  }

  async removeProcess(id: string): Promise<void> {
    await invoke("remove_process", { id });
    await this.refresh();
  }

  async startProcess(id: string): Promise<ProcessInfo> {
    const info = await invoke<ProcessInfo>("start_process", { id });
    await this.refresh();
    return info;
  }

  async stopProcess(id: string): Promise<void> {
    await invoke("stop_process", { id });
    await this.refresh();
  }

  async getProcess(id: string): Promise<ProcessInfo> {
    return invoke<ProcessInfo>("get_process", { id });
  }

  /** 获取进程输出历史 */
  async getProcessOutput(id: string): Promise<ProcessOutputLine[]> {
    return invoke<ProcessOutputLine[]>("get_process_output", { id });
  }

  /** 清空进程输出 */
  async clearProcessOutput(id: string): Promise<void> {
    await invoke("clear_process_output", { id });
  }

  /** 订阅进程输出事件 */
  async subscribeOutput(
    id: string,
    callback: (event: ProcessOutputEvent) => void,
  ): Promise<void> {
    // 先取消之前的订阅
    await this.unsubscribeOutput(id);

    const unlisten = await listen<ProcessOutputEvent>(
      "process-output",
      (event) => {
        if (event.payload.id === id) {
          callback(event.payload);
        }
      },
    );

    this.outputListeners.set(id, unlisten);
  }

  /** 取消订阅进程输出事件 */
  async unsubscribeOutput(id: string): Promise<void> {
    const unlisten = this.outputListeners.get(id);
    if (unlisten) {
      unlisten();
      this.outputListeners.delete(id);
    }
  }
}
