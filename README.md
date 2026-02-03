# DodoTidy - macOS System Cleaner, Analysis and Monitor

<p align="center">
  <img src="dodotidy.png" alt="DodoTidy Logo" width="150">
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)

🌍 **Translations:** [Türkçe](README.tr.md) | [Deutsch](README.de.md) | [Français](README.fr.md)

A native macOS application for system monitoring, disk analysis, and cleanup. Built with SwiftUI for macOS 14+.



https://github.com/user-attachments/assets/30fbedeb-1083-4c42-beac-9de65b2d9c6c


## Features

- **Dashboard**: Real-time system metrics (CPU, memory, disk, battery, Bluetooth devices)
- **Cleaner**: Scan and remove caches, logs, and temporary files
- **Analyzer**: Visual disk space analysis with interactive navigation
- **Optimizer**: System optimization tasks (DNS flush, Spotlight reset, font cache rebuild, etc.)
- **Apps**: View installed applications and uninstall with related file cleanup
- **History**: Track all cleaning operations
- **Scheduled tasks**: Automate cleanup routines

## Comparison with Paid Alternatives

DodoTidy is a free and open-source alternative to paid macOS system cleaners like CleanMyMac X, MacKeeper, and DaisyDisk. It offers comparable features without the subscription fees or one-time purchase costs.

| Feature | **DodoTidy** | **CleanMyMac X** | **MacKeeper** | **DaisyDisk** |
|---------|-------------|------------------|---------------|---------------|
| **Price** | Free (Open Source) | $39.95/year or $89.95 one-time | $71.40/year ($5.95/mo) | $9.99 one-time |
| **System Monitoring** | ✅ CPU, RAM, Disk, Battery, Bluetooth | ✅ CPU, RAM, Disk | ✅ Memory monitoring | ❌ |
| **Cache/Junk Cleaning** | ✅ | ✅ | ✅ | ❌ |
| **Disk Space Analyzer** | ✅ Visual sunburst chart | ✅ Space Lens | ❌ | ✅ Visual rings |
| **App Uninstaller** | ✅ With related files | ✅ With related files | ✅ Smart Uninstaller | ❌ |
| **System Optimization** | ✅ DNS, Spotlight, fonts, Dock | ✅ Maintenance scripts | ✅ Startup items, RAM | ❌ |
| **Scheduled Cleaning** | ✅ | ✅ | ❌ | ❌ |
| **Trash-based Deletion** | ✅ Always recoverable | ✅ | ✅ | ✅ |
| **Dry Run Mode** | ✅ | ❌ | ❌ | ❌ |
| **Protected Paths** | ✅ Customizable | ✅ | ✅ | N/A |
| **macOS Version** | 14.0+ (Sonoma) | 10.13+ | 10.13+ | 10.13+ |
| **Open Source** | ✅ MIT License | ❌ | ❌ | ❌ |

## Safety Guardrails

DodoTidy is designed with multiple safety mechanisms to protect your data:

### 1. Trash-based deletion (Recoverable)

All file deletions use macOS's `trashItem()` API, which moves files to Trash instead of permanently deleting them. You can always recover accidentally deleted files from Trash.

### 2. Protected paths

The following paths are protected by default and will never be cleaned:

- `~/Documents` - Your documents
- `~/Desktop` - Desktop files
- `~/Pictures`, `~/Movies`, `~/Music` - Media libraries
- `~/.ssh`, `~/.gnupg` - Security keys
- `~/.aws`, `~/.kube` - Cloud credentials
- `~/Library/Keychains` - System keychains
- `~/Library/Application Support/MobileSync` - iOS device backups

You can customize protected paths in Settings.

### 3. Safe vs manual-only categories

**Safe auto-clean paths** (used by scheduled tasks):
- Browser caches (Safari, Chrome, Firefox)
- Application caches (Spotify, Slack, Discord, VS Code, Zoom, Teams)
- Xcode DerivedData

**Manual-only paths** (require explicit user action, never auto-cleaned):
- **Downloads** - May contain important unprocessed files
- **Trash** - Emptying is IRREVERSIBLE
- **System logs** - May be needed for troubleshooting
- **Developer caches** (npm, Yarn, Homebrew, pip, CocoaPods, Gradle, Maven) - May require lengthy re-downloads

### 4. Dry run mode

Enable "Dry run mode" in Settings to preview exactly what files would be deleted without actually deleting anything. This shows:
- File paths
- File sizes
- Modification dates
- Total count and size

### 5. File age filter

Set a minimum file age (in days) to only clean files older than a specified threshold. This prevents accidentally deleting recently created or modified files.

Example: Set to 7 days to only clean files that haven't been modified in the past week.

### 6. Scheduled task confirmation

When "Confirm scheduled tasks" is enabled (default), scheduled cleaning tasks will:
- Send a notification when ready to run
- Wait for user confirmation before executing
- Never auto-clean without user review

### 7. User-space only operations

DodoTidy operates entirely within user space:
- No sudo or root privileges required
- Cannot modify system files
- Cannot affect other users' data
- All operations limited to `~/` paths

### 8. Safe optimizer commands

The optimizer only runs well-known, safe system commands:
- `dscacheutil -flushcache` - Flush DNS cache
- `qlmanage -r cache` - Reset Quick Look thumbnails
- `lsregister` - Rebuild Launch Services database

No destructive or risky system commands are included.

## Installation

### Homebrew (Recommended)

```bash
brew tap dodoapps/tap
brew install --cask dodotidy
xattr -cr /Applications/DodoTidy.app
```

### Manual Installation

1. Download the latest DMG from [Releases](https://github.com/dodoapps/dodotidy/releases)
2. Open the DMG and drag DodoTidy to Applications
3. Right-click and select "Open" on first launch (required for unsigned apps)

Or run: `xattr -cr /Applications/DodoTidy.app`

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for building from source)

## Building from Source

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
│   ├── DodoTidyApp.swift          # Main app entry point
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
│   └── DodoTidyService.swift      # Core service providers
├── Models/
│   ├── SystemMetrics.swift        # System metrics models
│   └── ScanResult.swift           # Scan result models
├── Utilities/
│   ├── ProcessRunner.swift        # Process execution helper
│   ├── DesignSystem.swift         # Colors, fonts, styles
│   └── Extensions.swift           # Formatting helpers
└── Resources/
    └── Assets.xcassets            # App icons
```

## Architecture

The app uses a provider-based architecture:

- **DodoTidyService**: Main coordinator that manages all providers
- **StatusProvider**: System metrics collection using native macOS APIs
- **AnalyzerProvider**: Disk space analysis using FileManager
- **CleanerProvider**: Cache and temporary file cleanup with safety guardrails
- **OptimizerProvider**: System optimization tasks
- **UninstallProvider**: App uninstallation with related file detection

All providers use Swift's `@Observable` macro for reactive state management.

## Settings

Access Settings from the app menu or sidebar to configure:

- **General**: Launch at login, menu bar icon, refresh interval
- **Cleaning**: Confirm before cleaning, dry run mode, file age filter
- **Protected paths**: Paths that should never be cleaned
- **Notifications**: Low disk space alerts, scheduled task notifications

## Design system

- **Primary color**: #13715B (Green)
- **Background**: #0F1419 (Dark)
- **Text primary**: #F9FAFB
- **Border radius**: 4px
- **Button height**: 34px

## License

MIT License

---

Part of the Dodo app family ([DodoPulse](https://github.com/dodoapps/dodopulse), [DodoTidy](https://github.com/dodoapps/dodotidy), [DodoClip](https://github.com/dodoapps/dodoclip), [DodoNest](https://github.com/dodoapps/dodonest))
