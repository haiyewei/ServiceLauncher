/** 进程启动模式 */
export type ProcessMode = "fork" | "import";

/** 进程状态 */
export type ProcessStatus = "running" | "stopped" | "error";

/** 命令类型 */
export type CommandType = "executable" | "shell";

/** 进程配置 */
export interface ProcessConfig {
  id: string;
  name: string;
  mode: ProcessMode;
  command: string;
  args: string[];
  working_dir: string;
  source_path?: string;
  env: Record<string, string>;
  auto_restart: boolean;
  auto_start: boolean;
  created_at: number;
  command_type: CommandType; // 命令类型：executable 或 shell
}

/** 进程信息（运行时状态） */
export interface ProcessInfo {
  id: string;
  name: string;
  mode: ProcessMode;
  command: string;
  args: string[];
  working_dir: string;
  source_path?: string;
  status: ProcessStatus;
  pid?: number;
  auto_restart: boolean;
  auto_start: boolean;
  started_at?: number;
  created_at: number;
  has_output: boolean;
  command_type: CommandType; // 命令类型：executable 或 shell
}

/** Fork 模式添加进程参数 */
export interface AddProcessForkParams {
  name: string;
  working_dir: string; // 必选：工作目录
  executable_path?: string; // 可选：可执行程序路径
  args: string[];
  auto_restart: boolean;
  auto_start: boolean;
  command_type: CommandType; // 命令类型
}

/** 导入模式添加进程参数 */
export interface AddProcessImportParams {
  name: string;
  source_folder: string;
  executable_path?: string; // 可选：可执行程序路径
  args: string[];
  auto_restart: boolean;
  auto_start: boolean;
  command_type: CommandType; // 命令类型
}

/** 更新进程参数 */
export interface UpdateProcessParams {
  id: string;
  name: string;
  working_dir?: string; // 可选：工作目录
  executable_path?: string; // 可选：可执行程序路径
  args: string[];
  auto_restart: boolean;
  auto_start: boolean;
  command_type: CommandType; // 命令类型
}

/** 进程输出事件 */
export interface ProcessOutputEvent {
  id: string;
  output_type: "stdout" | "stderr";
  line: string;
  timestamp: number;
}

/** 进程输出行 */
export type ProcessOutputLine = [number, string, string]; // [timestamp, type, line]
