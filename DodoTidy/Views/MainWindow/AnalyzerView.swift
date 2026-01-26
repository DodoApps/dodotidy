import SwiftUI

struct AnalyzerView: View {
    @State private var dodoService = DodoTidyService.shared
    @State private var selectedEntry: DirEntry?
    @State private var currentPath: String = FileManager.default.homeDirectoryForCurrentUser.path

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()
                .background(Color.dodoBorder.opacity(0.2))

            if dodoService.analyzer.isScanning {
                loadingView
            } else if let result = dodoService.analyzer.scanResult {
                contentView(result: result)
            } else {
                emptyStateView
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Disk analyzer")
                    .font(.dodoTitle)
                    .foregroundColor(.dodoTextPrimary)

                Text(currentPath)
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Path picker
            Menu {
                Button("Home") {
                    currentPath = FileManager.default.homeDirectoryForCurrentUser.path
                    scanPath()
                }
                Button("Desktop") {
                    currentPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
                    scanPath()
                }
                Button("Documents") {
                    currentPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path
                    scanPath()
                }
                Button("Downloads") {
                    currentPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
                    scanPath()
                }
                Button("Applications") {
                    currentPath = "/Applications"
                    scanPath()
                }
                Divider()
                Button("Choose folder...") {
                    chooseFolder()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text("Location")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
            }
            .buttonStyle(.dodoSecondary)

            Button {
                scanPath()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("Scan")
                }
            }
            .buttonStyle(.dodoPrimary)
        }
        .padding(DodoTidyDimensions.cardPaddingLarge)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning \(currentPath)...")
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(.dodoTextTertiary)

            Text("Analyze your disk usage")
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            Text("Select a location and click Scan to see what's using your disk space")
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button {
                scanPath()
            } label: {
                Text("Scan home folder")
            }
            .buttonStyle(.dodoPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content View

    private func contentView(result: ScanResult) -> some View {
        HSplitView {
            // Left side: Sunburst chart
            VStack(spacing: DodoTidyDimensions.spacing) {
                // Chart
                SunburstChartView(
                    entries: result.entries,
                    totalSize: result.totalSize,
                    selectedEntry: $selectedEntry
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Summary
                summarySection(result: result)
            }
            .padding(DodoTidyDimensions.cardPaddingLarge)
            .frame(minWidth: 400)

            // Right side: List view
            VStack(spacing: 0) {
                // Tabs for directories and large files
                tabsSection(result: result)
            }
            .frame(minWidth: 350)
        }
    }

    // MARK: - Summary Section

    private func summarySection(result: ScanResult) -> some View {
        HStack(spacing: DodoTidyDimensions.spacingLarge) {
            SummaryItem(
                icon: "folder",
                title: "Total size",
                value: result.totalSize.formattedBytes
            )

            Divider()
                .frame(height: 40)

            SummaryItem(
                icon: "doc",
                title: "Files scanned",
                value: result.totalFiles.formattedWithSeparator
            )

            Divider()
                .frame(height: 40)

            SummaryItem(
                icon: "folder.fill",
                title: "Directories",
                value: "\(result.entries.filter { $0.isDir }.count)"
            )
        }
        .padding(DodoTidyDimensions.cardPadding)
        .background(Color.dodoBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadiusMedium))
    }

    // MARK: - Tabs Section

    @State private var selectedTab = 0

    private func tabsSection(result: ScanResult) -> some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "Directories", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }

                TabButton(title: "Large files", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }

                Spacer()
            }
            .padding(.horizontal, DodoTidyDimensions.cardPadding)
            .padding(.top, DodoTidyDimensions.cardPadding)

            Divider()
                .background(Color.dodoBorder.opacity(0.2))

            // Tab content
            if selectedTab == 0 {
                directoryList(entries: result.entries)
            } else {
                largeFilesList(files: result.largeFiles)
            }
        }
        .background(Color.dodoBackgroundSecondary)
    }

    private func directoryList(entries: [DirEntry]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    EntryRow(entry: entry, isSelected: selectedEntry?.id == entry.id) {
                        selectedEntry = entry
                    }

                    if entry.id != entries.last?.id {
                        Divider()
                            .background(Color.dodoBorder.opacity(0.1))
                    }
                }
            }
        }
    }

    private func largeFilesList(files: [FileEntry]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(files) { file in
                    FileRow(file: file)

                    if file.id != files.last?.id {
                        Divider()
                            .background(Color.dodoBorder.opacity(0.1))
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func scanPath() {
        Task {
            await dodoService.analyzer.scan(path: currentPath)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            currentPath = url.path
            scanPath()
        }
    }
}

// MARK: - Supporting Views

struct SummaryItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.dodoPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.dodoCaptionSmall)
                    .foregroundColor(.dodoTextTertiary)

                Text(value)
                    .font(.dodoSubheadline)
                    .foregroundColor(.dodoTextPrimary)
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.dodoSubheadline)
                .foregroundColor(isSelected ? .dodoPrimary : .dodoTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ?
                    Color.dodoPrimary.opacity(0.1) :
                    Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadius))
        }
        .buttonStyle(.plain)
    }
}

struct EntryRow: View {
    let entry: DirEntry
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: entry.isDir ? "folder.fill" : "doc.fill")
                    .font(.system(size: 16))
                    .foregroundColor(entry.isDir ? .dodoWarning : .dodoTextTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.dodoBody)
                        .foregroundColor(.dodoTextPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Text(entry.size.formattedBytes)
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, DodoTidyDimensions.cardPadding)
            .padding(.vertical, 10)
            .background(isSelected ? Color.dodoPrimary.opacity(0.15) : (isHovering ? Color.dodoBackgroundTertiary.opacity(0.5) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct FileRow: View {
    let file: FileEntry

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForFile(file.name))
                .font(.system(size: 16))
                .foregroundColor(.dodoTextTertiary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.dodoBody)
                    .foregroundColor(.dodoTextPrimary)
                    .lineLimit(1)
            }

            Spacer()

            Text(file.size.formattedBytes)
                .font(.dodoCaption)
                .foregroundColor(.dodoTextSecondary)
                .monospacedDigit()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
            } label: {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.dodoTextTertiary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, DodoTidyDimensions.cardPadding)
        .padding(.vertical, 10)
        .background(isHovering ? Color.dodoBackgroundTertiary.opacity(0.5) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "avi", "mkv": return "film"
        case "mp3", "wav", "m4a", "aac": return "music.note"
        case "jpg", "jpeg", "png", "gif", "heic": return "photo"
        case "pdf": return "doc.text"
        case "zip", "tar", "gz", "dmg": return "archivebox"
        case "app": return "app"
        default: return "doc.fill"
        }
    }
}
