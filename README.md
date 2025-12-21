# servicelauncher

servicelauncher is a cross-platform desktop application built with Tauri and Angular designed for managing subscriptions and scraping content from creator platforms.

## Supported Websites

- OnlyFans (`onlyfans.com`)
- FansOne (`fansone.co`)
- My.Club (`my.club`)

![Supported Sites](docs/supported_sites.png)

## Features

- **Subscription Management**: Import and manage creator subscriptions.
- **Content Scraping**: Automated scraping of posts and media from subscribed accounts.
- **Embedded Browser**: Integrated WebView for authentication and navigation.
- **Media Processing**: Utilizes `aria2c` and `ffmpeg` for efficient media downloading and processing.

## Project Structure

```text
servicelauncher/
├── .angular/              # Angular configuration cache
├── .github/               # GitHub workflows and templates
├── .vscode/               # VS Code workspace settings
├── dev/                   # Development scripts and resources
├── dist/                  # Build output directory
├── docs/                  # Documentation and screenshots
├── models/                # Shared data models
├── public/                # Static public assets
├── src/                   # Frontend source code (Angular)
│   ├── app/
│   │   ├── components/    # Reusable UI components
│   │   ├── models/        # Frontend interfaces and types
│   │   ├── pages/         # Route components (Dashboard, Scrape, etc.)
│   │   ├── services/      # Service layer (API, State, Logic)
│   │   └── app.config.ts  # Application configuration
│   ├── assets/            # Frontend static assets
│   ├── environments/      # Environment configurations
│   ├── main.ts            # Application entry point
│   └── styles.scss        # Global styles
├── src-tauri/             # Backend source code (Rust/Tauri)
│   ├── binaries/          # External binaries (aria2c, ffmpeg)
│   ├── icons/             # Application icons
│   ├── src/               # Rust source files
│   ├── Cargo.toml         # Rust package configuration
│   └── tauri.conf.json    # Tauri configuration
├── angular.json           # Angular CLI configuration
├── package.json           # Node.js dependencies and scripts
└── tsconfig.json          # TypeScript configuration
```

## Development

1.  **Install dependencies:**

    ```bash
    npm install
    ```

2.  **Run development server:**

    ```bash
    npm run tauri dev
    ```

3.  **Build for production:**

    ```bash
    npm run tauri build
    ```
