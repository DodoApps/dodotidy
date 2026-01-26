import SwiftUI

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let icon: NSImage?
    let lastUsed: Date?
}

struct AppsView: View {
    @State private var apps: [InstalledApp] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOrder: AppSortOrder = .size
    @State private var selectedApp: InstalledApp?
    @State private var appToDelete: InstalledApp?
    @State private var showDeleteConfirmation = false
    @State private var showDeleteSuccess = false
    @State private var deletedAppName = ""
    @State private var errorMessage: String?
    @State private var showError = false

    enum AppSortOrder: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case lastUsed = "Last used"
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if filteredApps.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .navigationTitle("Apps")
        .searchable(text: $searchText, prompt: "Search apps")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await loadApps()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh app list")
                .disabled(isLoading)
            }

            ToolbarItem(placement: .automatic) {
                Picker("Sort by", selection: $sortOrder) {
                    ForEach(AppSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .task(id: "loadApps") {
            // Only load if apps haven't been loaded yet
            if apps.isEmpty {
                await loadApps()
            }
        }
        .alert("Uninstall application", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                appToDelete = nil
            }
            Button("Move to Trash", role: .destructive) {
                if let app = appToDelete {
                    deleteApp(app)
                }
            }
        } message: {
            if let app = appToDelete {
                Text("Are you sure you want to uninstall \"\(app.name)\"?\n\nThis will move the application (\(app.size.formattedBytes)) to Trash.")
            }
        }
        .alert("Application uninstalled", isPresented: $showDeleteSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\"\(deletedAppName)\" has been moved to Trash.\n\nYou can restore it from Trash if needed.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private func deleteApp(_ app: InstalledApp) {
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
            deletedAppName = app.name
            apps.removeAll { $0.id == app.id }
            selectedApp = nil
            appToDelete = nil
            showDeleteSuccess = true
        } catch {
            errorMessage = "Could not uninstall \"\(app.name)\".\n\nThe app may be in use or protected by the system."
            appToDelete = nil
            showError = true
        }
    }

    // MARK: - Header

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading applications...")
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(.dodoTextTertiary)

            Text(searchText.isEmpty ? "No applications found" : "No matching applications")
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Text("Clear search")
                }
                .buttonStyle(.dodoSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: 0) {
            // Stats bar
            statsBar

            Divider()
                .background(Color.dodoBorder.opacity(0.2))

            // Apps list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredApps) { app in
                        AppRow(
                            app: app,
                            isSelected: selectedApp?.id == app.id,
                            onSelect: {
                                selectedApp = app
                            },
                            onDelete: {
                                appToDelete = app
                                showDeleteConfirmation = true
                            }
                        )

                        if app.id != filteredApps.last?.id {
                            Divider()
                                .background(Color.dodoBorder.opacity(0.1))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: DodoTidyDimensions.spacingLarge) {
            StatItem(
                label: "Total apps",
                value: "\(apps.count)"
            )

            Divider()
                .frame(height: 30)

            StatItem(
                label: "Total size",
                value: totalSize.formattedBytes
            )

            Spacer()
        }
        .padding(.horizontal, DodoTidyDimensions.cardPaddingLarge)
        .padding(.vertical, 12)
        .background(Color.dodoBackgroundSecondary)
    }

    // MARK: - Computed Properties

    private var filteredApps: [InstalledApp] {
        var result = apps

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch sortOrder {
        case .name:
            result.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .size:
            result.sort { $0.size > $1.size }
        case .lastUsed:
            result.sort { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        }

        return result
    }

    private var totalSize: Int64 {
        apps.reduce(0) { $0 + $1.size }
    }

    // MARK: - Actions

    private func loadApps() async {
        isLoading = true

        // Scan /Applications directory
        let applicationsPath = "/Applications"
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: applicationsPath)

            var loadedApps: [InstalledApp] = []

            for item in contents where item.hasSuffix(".app") {
                let appPath = (applicationsPath as NSString).appendingPathComponent(item)
                let appName = (item as NSString).deletingPathExtension

                // Get app size
                let size = getDirectorySize(at: appPath)

                // Get app icon
                let icon = NSWorkspace.shared.icon(forFile: appPath)
                icon.size = NSSize(width: 32, height: 32)

                // Get last used date (simplified)
                let attributes = try? fileManager.attributesOfItem(atPath: appPath)
                let lastUsed = attributes?[.modificationDate] as? Date

                loadedApps.append(InstalledApp(
                    name: appName,
                    path: appPath,
                    size: size,
                    icon: icon,
                    lastUsed: lastUsed
                ))
            }

            await MainActor.run {
                apps = loadedApps
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func getDirectorySize(at path: String) -> Int64 {
        // Use a faster method - get the allocated size from the file system
        let url = URL(fileURLWithPath: path)

        // Try to get the total allocated size (much faster than enumerating)
        if let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]),
           let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
            return Int64(size)
        }

        // Fallback: enumerate but with a limit to avoid hanging
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        var fileCount = 0
        let maxFiles = 5000 // Limit to prevent hanging

        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                fileCount += 1
                if fileCount > maxFiles { break }

                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        return totalSize
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.dodoCaptionSmall)
                .foregroundColor(.dodoTextTertiary)

            Text(value)
                .font(.dodoSubheadline)
                .foregroundColor(.dodoTextPrimary)
        }
    }
}

struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // App icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.dodoTextTertiary)
                        .frame(width: 40, height: 40)
                }

                // App info
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.dodoBody)
                        .foregroundColor(.dodoTextPrimary)

                    Text(app.path)
                        .font(.dodoCaptionSmall)
                        .foregroundColor(.dodoTextTertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Size
                Text(app.size.formattedBytes)
                    .font(.dodoBody)
                    .foregroundColor(.dodoTextSecondary)
                    .monospacedDigit()

                // Action buttons (show on hover)
                if isHovering {
                    HStack(spacing: 8) {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.dodoTextTertiary)
                        .help("Show in Finder")

                        Button {
                            NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
                        } label: {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.dodoTextTertiary)
                        .help("Open app")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.dodoDanger)
                        .help("Uninstall app")
                    }
                }
            }
            .padding(.horizontal, DodoTidyDimensions.cardPaddingLarge)
            .padding(.vertical, 12)
            .background(isSelected ? Color.dodoPrimary.opacity(0.15) : (isHovering ? Color.dodoBackgroundTertiary.opacity(0.5) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
