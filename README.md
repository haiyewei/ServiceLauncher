# ServiceLauncher

一个轻量级的本地服务/进程管理工具，基于 Tauri + Angular 构建。

## 功能特性

- **进程管理**：启动、停止、监控本地可执行程序
- **两种添加模式**：
  - Fork 模式：直接选择可执行文件运行
  - Import 模式：导入整个文件夹到应用目录
- **实时输出**：查看进程的 stdout/stderr 输出
- **自动启动**：支持进程跟随应用启动
- **开机自启**：支持应用开机自动启动（静默模式）
- **系统托盘**：最小化到托盘，关闭窗口不退出
- **多语言**：支持中文、英文、日文、韩文
- **主题适配**：自动跟随 Windows 系统主题色

## 项目结构

```
ServiceLauncher/
├── src/                          # Angular 前端源码
│   ├── app/
│   │   ├── components/           # 公共组件
│   │   │   ├── logo/             # Logo 组件
│   │   │   ├── sidebar/          # 侧边栏导航
│   │   │   └── topbar/           # 顶部栏
│   │   ├── models/               # 数据模型定义
│   │   ├── pages/                # 页面组件
│   │   │   ├── dashboard/        # 仪表盘页面
│   │   │   ├── processes/        # 进程管理页面
│   │   │   └── settings/         # 设置页面
│   │   ├── services/             # 服务层
│   │   │   ├── language.service.ts      # 多语言服务
│   │   │   ├── process.service.ts       # 进程管理服务
│   │   │   ├── theme.service.ts         # 主题服务
│   │   │   └── titlebar-sync.service.ts # 标题栏同步服务
│   │   ├── app.config.ts         # 应用配置
│   │   └── app.routes.ts         # 路由配置
│   ├── assets/
│   │   └── i18n/                 # 国际化翻译文件
│   └── styles.scss               # 全局样式
├── src-tauri/                    # Tauri/Rust 后端源码
│   ├── src/
│   │   ├── core/
│   │   │   └── process_manager/  # 进程管理核心模块
│   │   │       ├── config.rs     # 进程配置管理
│   │   │       ├── lifecycle.rs  # 进程生命周期（启动/停止）
│   │   │       ├── output.rs     # 输出缓冲管理
│   │   │       ├── runner.rs     # 进程启动核心逻辑
│   │   │       ├── state.rs      # 状态管理
│   │   │       └── types.rs      # 类型定义
│   │   ├── lib.rs                # Tauri 应用入口
│   │   ├── storage.rs            # SQLite 数据库操作
│   │   └── system_theme.rs       # Windows 主题色监听
│   ├── icons/                    # 应用图标
│   └── tauri.conf.json           # Tauri 配置
├── angular.json                  # Angular CLI 配置
├── package.json                  # Node.js 依赖
└── tsconfig.json                 # TypeScript 配置
```

## 技术栈

- **前端**：Angular 21 + Angular Material
- **后端**：Tauri 2 (Rust)
- **数据库**：SQLite (rusqlite)

## 开发

```bash
# 安装依赖
npm install

# 开发模式
npm run tauri dev

# 构建
npm run tauri build
```

## 下载

前往 [Releases](https://github.com/haiyewei/ServiceLauncher/releases) 下载最新版本。

## License

[GPL-3.0](LICENSE)
