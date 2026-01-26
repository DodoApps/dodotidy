# DodoTidy - macOS System Cleaner

A native macOS application for system monitoring, disk analysis, and cleanup. Built with SwiftUI for macOS 14+.

## Features

- **Dashboard**: Real-time system metrics (CPU, memory, disk, battery, Bluetooth devices)
- **Cleaner**: Scan and remove caches, logs, and temporary files
- **Analyzer**: Visual disk space analysis with interactive navigation
- **Optimizer**: System optimization tasks (DNS flush, Spotlight reset, font cache rebuild, etc.)
- **Apps**: View installed applications and uninstall with related file cleanup
- **History**: Track all cleaning operations
- **Scheduled tasks**: Automate cleanup routines

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for building)

## Building

### Using XcodeGen (Recommended)

```bash
# Install dependencies
make install-dependencies

# Generate Xcode project
make generate-project

# Build the app
make build

# Run the app
make run
```

### Using Xcode directly

1. Run `make generate-project` to create the Xcode project
2. Open `DodoTidy.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## Project structure

```
DodoTidy/
├── App/
│   ├── MoleApp.swift              # Main app entry point
│   ├── AppDelegate.swift          # Menu bar management
│   └── StatusItemManager.swift    # Status bar icon
├── Views/
│   ├── MainWindow/                # Main window views
│   │   ├── MainWindowView.swift
│   │   ├── SidebarView.swift
│   │   ├── DashboardView.swift
│   │   ├── CleanerView.swift
│   │   ├── AnalyzerView.swift
│   │   ├── OptimizerView.swift
│   │   ├── AppsView.swift
│   │   ├── HistoryView.swift
│   │   └── ScheduledTasksView.swift
│   └── MenuBar/
│       └── MenuBarView.swift      # Menu bar popover
├── Services/
│   └── MoleService.swift          # Core service providers
├── Models/
│   ├── SystemMetrics.swift        # System metrics models
│   └── ScanResult.swift           # Scan result models
├── Utilities/
│   ├── ProcessRunner.swift        # Process execution helper
│   └── DesignSystem.swift         # Colors, fonts, styles
└── Resources/
    └── Assets.xcassets            # App icons
```

## Architecture

The app uses a provider-based architecture:

- **DodoTidyService**: Main coordinator that manages all providers
- **StatusProvider**: System metrics collection using native macOS APIs
- **AnalyzerProvider**: Disk space analysis using FileManager
- **CleanerProvider**: Cache and temporary file cleanup
- **OptimizerProvider**: System optimization tasks
- **UninstallProvider**: App uninstallation with related file detection

All providers use Swift's `@Observable` macro for reactive state management.

## Design system

- **Primary color**: #13715B (Green)
- **Background**: #0F1419 (Dark)
- **Text primary**: #F9FAFB
- **Border radius**: 4px
- **Button height**: 34px

## License

MIT License
