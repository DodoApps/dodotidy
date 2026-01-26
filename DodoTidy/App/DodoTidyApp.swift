import SwiftUI
import ServiceManagement

@main
struct DodoTidyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("DodoTidy", id: "main") {
            MainWindowView()
                .frame(minWidth: 1000, minHeight: 700)
                .background(Color.dodoBackground)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }

            // View menu - Navigation shortcuts
            CommandMenu("View") {
                Button("Dashboard") {
                    NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.dashboard)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Cleaner") {
                    NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.cleaner)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Analyzer") {
                    NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.analyzer)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Optimizer") {
                    NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.optimizer)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Apps") {
                    NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.apps)
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("History") {
                    NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.history)
                }
                .keyboardShortcut("6", modifiers: .command)

                Button("Scheduled") {
                    NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.scheduled)
                }
                .keyboardShortcut("7", modifiers: .command)
            }

            // Actions menu
            CommandMenu("Actions") {
                Button("Refresh Status") {
                    Task {
                        await DodoTidyService.shared.status.fetchMetrics()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Scan for Cleanable Items") {
                    Task {
                        await DodoTidyService.shared.cleaner.scanForCleanableItems()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Analyze Home Directory") {
                    Task {
                        await DodoTidyService.shared.analyzer.scanHome()
                    }
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateTo = Notification.Name("navigateTo")
}

// MARK: - App Settings Manager

@Observable
final class AppSettings {
    static let shared = AppSettings()

    // General settings
    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }
    var showMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon") }
    }
    var refreshInterval: Int {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }

    // Cleaning settings
    var confirmBeforeCleaning: Bool {
        didSet { UserDefaults.standard.set(confirmBeforeCleaning, forKey: "confirmBeforeCleaning") }
    }
    var moveToTrash: Bool {
        didSet { UserDefaults.standard.set(moveToTrash, forKey: "moveToTrash") }
    }
    var excludedPaths: [String] {
        didSet { UserDefaults.standard.set(excludedPaths, forKey: "excludedPaths") }
    }
    var protectedPaths: [String] {
        didSet { UserDefaults.standard.set(protectedPaths, forKey: "protectedPaths") }
    }
    var minimumFileAgeDays: Int {
        didSet { UserDefaults.standard.set(minimumFileAgeDays, forKey: "minimumFileAgeDays") }
    }
    var enableDryRunMode: Bool {
        didSet { UserDefaults.standard.set(enableDryRunMode, forKey: "enableDryRunMode") }
    }
    var confirmScheduledTasks: Bool {
        didSet { UserDefaults.standard.set(confirmScheduledTasks, forKey: "confirmScheduledTasks") }
    }

    // Analyzer settings
    var showHiddenFiles: Bool {
        didSet { UserDefaults.standard.set(showHiddenFiles, forKey: "showHiddenFiles") }
    }
    var minFileSizeForLargeFiles: Int {
        didSet { UserDefaults.standard.set(minFileSizeForLargeFiles, forKey: "minFileSizeForLargeFiles") }
    }

    // Notification settings
    var showNotifications: Bool {
        didSet { UserDefaults.standard.set(showNotifications, forKey: "showNotifications") }
    }
    var notifyOnLowDiskSpace: Bool {
        didSet { UserDefaults.standard.set(notifyOnLowDiskSpace, forKey: "notifyOnLowDiskSpace") }
    }
    var lowDiskSpaceThreshold: Int {
        didSet { UserDefaults.standard.set(lowDiskSpaceThreshold, forKey: "lowDiskSpaceThreshold") }
    }

    private init() {
        // Load settings from UserDefaults with defaults
        self.launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false
        self.showMenuBarIcon = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        self.refreshInterval = UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 2
        self.confirmBeforeCleaning = UserDefaults.standard.object(forKey: "confirmBeforeCleaning") as? Bool ?? true
        self.moveToTrash = UserDefaults.standard.object(forKey: "moveToTrash") as? Bool ?? true
        self.excludedPaths = UserDefaults.standard.object(forKey: "excludedPaths") as? [String] ?? []
        self.protectedPaths = UserDefaults.standard.object(forKey: "protectedPaths") as? [String] ?? CleanerProvider.defaultProtectedPaths
        self.minimumFileAgeDays = UserDefaults.standard.object(forKey: "minimumFileAgeDays") as? Int ?? 0
        self.enableDryRunMode = UserDefaults.standard.object(forKey: "enableDryRunMode") as? Bool ?? false
        self.confirmScheduledTasks = UserDefaults.standard.object(forKey: "confirmScheduledTasks") as? Bool ?? true
        self.showHiddenFiles = UserDefaults.standard.object(forKey: "showHiddenFiles") as? Bool ?? false
        self.minFileSizeForLargeFiles = UserDefaults.standard.object(forKey: "minFileSizeForLargeFiles") as? Int ?? 100
        self.showNotifications = UserDefaults.standard.object(forKey: "showNotifications") as? Bool ?? true
        self.notifyOnLowDiskSpace = UserDefaults.standard.object(forKey: "notifyOnLowDiskSpace") as? Bool ?? true
        self.lowDiskSpaceThreshold = UserDefaults.standard.object(forKey: "lowDiskSpaceThreshold") as? Int ?? 10

        // Sync launch at login state with system on startup
        syncLaunchAtLoginState()
    }

    /// Update the system's launch at login setting
    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error.localizedDescription)")
            }
        }
    }

    /// Sync the stored setting with the actual system state
    private func syncLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            let systemState = SMAppService.mainApp.status == .enabled
            // Directly update the backing storage without triggering didSet
            // This avoids the circular update issue
            if UserDefaults.standard.bool(forKey: "launchAtLogin") != systemState {
                UserDefaults.standard.set(systemState, forKey: "launchAtLogin")
                // Note: We don't update the property here to avoid triggering didSet
                // The property will be initialized with the correct value on next launch
            }
        }
    }

    func resetToDefaults() {
        launchAtLogin = false
        showMenuBarIcon = true
        refreshInterval = 2
        confirmBeforeCleaning = true
        moveToTrash = true
        excludedPaths = []
        showHiddenFiles = false
        minFileSizeForLargeFiles = 100
        showNotifications = true
        notifyOnLowDiskSpace = true
        lowDiskSpaceThreshold = 10
    }
}

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            cleaningSettings
                .tabItem {
                    Label("Cleaning", systemImage: "trash")
                }
                .tag(1)

            analyzerSettings
                .tabItem {
                    Label("Analyzer", systemImage: "chart.pie")
                }
                .tag(2)

            notificationSettings
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
                .tag(3)
        }
        .frame(width: 450, height: 320)
    }

    private var generalSettings: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)

                Picker("Status refresh interval", selection: $settings.refreshInterval) {
                    Text("1 second").tag(1)
                    Text("2 seconds").tag(2)
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                }
            } header: {
                Text("Startup & display")
            }

            Section {
                Button("Reset all settings to defaults") {
                    settings.resetToDefaults()
                }
                .foregroundColor(.dodoDanger)
            }
        }
        .formStyle(.grouped)
    }

    private var cleaningSettings: some View {
        Form {
            Section {
                Toggle("Confirm before cleaning", isOn: $settings.confirmBeforeCleaning)
                Toggle("Move to Trash instead of permanent delete", isOn: $settings.moveToTrash)
            } header: {
                Text("Safety")
            }

            Section {
                Text("Excluded paths will be skipped during scans")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if settings.excludedPaths.isEmpty {
                    Text("No excluded paths")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(settings.excludedPaths, id: \.self) { path in
                        HStack {
                            Text(path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                settings.excludedPaths.removeAll { $0 == path }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button("Add excluded path...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        if !settings.excludedPaths.contains(url.path) {
                            settings.excludedPaths.append(url.path)
                        }
                    }
                }
            } header: {
                Text("Excluded paths")
            }
        }
        .formStyle(.grouped)
    }

    private var analyzerSettings: some View {
        Form {
            Section {
                Toggle("Show hidden files", isOn: $settings.showHiddenFiles)

                Picker("Minimum size for large files", selection: $settings.minFileSizeForLargeFiles) {
                    Text("50 MB").tag(50)
                    Text("100 MB").tag(100)
                    Text("250 MB").tag(250)
                    Text("500 MB").tag(500)
                    Text("1 GB").tag(1000)
                }
            } header: {
                Text("Display options")
            }
        }
        .formStyle(.grouped)
    }

    private var notificationSettings: some View {
        Form {
            Section {
                Toggle("Show notifications", isOn: $settings.showNotifications)
            } header: {
                Text("General")
            }

            Section {
                Toggle("Alert when disk space is low", isOn: $settings.notifyOnLowDiskSpace)
                    .disabled(!settings.showNotifications)

                Picker("Low disk space threshold", selection: $settings.lowDiskSpaceThreshold) {
                    Text("5 GB").tag(5)
                    Text("10 GB").tag(10)
                    Text("20 GB").tag(20)
                    Text("50 GB").tag(50)
                }
                .disabled(!settings.showNotifications || !settings.notifyOnLowDiskSpace)
            } header: {
                Text("Disk space alerts")
            }
        }
        .formStyle(.grouped)
    }
}
