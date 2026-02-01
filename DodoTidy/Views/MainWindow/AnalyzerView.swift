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
        .navigationTitle("")
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "analyzer.title"))
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
                Button(String(localized: "analyzer.home")) {
                    currentPath = FileManager.default.homeDirectoryForCurrentUser.path
                    scanPath()
                }
                Button(String(localized: "analyzer.desktop")) {
                    currentPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
                    scanPath()
                }
                Button(String(localized: "analyzer.documents")) {
                    currentPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path
                    scanPath()
                }
                Button(String(localized: "analyzer.downloads")) {
                    currentPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
                    scanPath()
                }
                Button(String(localized: "analyzer.applications")) {
                    currentPath = "/Applications"
                    scanPath()
                }
                Divider()
                Button(String(localized: "analyzer.chooseFolder")) {
                    chooseFolder()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text(String(localized: "analyzer.location"))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.dodoSecondary)

            Button {
                scanPath()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text(String(localized: "analyzer.scan"))
                }
            }
            .buttonStyle(.dodoPrimary)
        }
        .padding(DodoTidyDimensions.cardPaddingLarge)
    }

    // MARK: - Loading View

    @State private var analyzerRotation: Double = 0
    @State private var analyzerFillAmount: CGFloat = 0

    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.dodoBackgroundTertiary, lineWidth: 6)
                    .frame(width: 80, height: 80)

                // Animated arc
                Circle()
                    .trim(from: 0, to: analyzerFillAmount)
                    .stroke(
                        AngularGradient(
                            colors: [.dodoPrimary, .dodoInfo, .dodoWarning, .dodoPrimary],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(analyzerRotation - 90))

                // Center icon
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.dodoPrimary)
            }
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    analyzerRotation = 360
                }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    analyzerFillAmount = 0.7
                }
            }

            VStack(spacing: 8) {
                Text(String(localized: "optimizer.analyzing"))
                    .font(.dodoBody)
                    .foregroundColor(.dodoTextSecondary)

                Text(currentPath)
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(.dodoTextTertiary)

            Text(String(localized: "analyzer.analyzeUsage"))
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            Text(String(localized: "analyzer.selectLocation"))
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button {
                scanPath()
            } label: {
                Text(String(localized: "analyzer.scanHome"))
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
                title: String(localized: "analyzer.totalSize"),
                value: result.totalSize.formattedBytes
            )

            Divider()
                .frame(height: 40)

            SummaryItem(
                icon: "doc",
                title: String(localized: "analyzer.filesScanned"),
                value: result.totalFiles.formattedWithSeparator
            )

            Divider()
                .frame(height: 40)

            SummaryItem(
                icon: "folder.fill",
                title: String(localized: "analyzer.directories"),
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
                TabButton(title: String(localized: "analyzer.directories"), isSelected: selectedTab == 0) {
                    selectedTab = 0
                }

                TabButton(title: String(localized: "analyzer.largeFiles"), isSelected: selectedTab == 1) {
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

                // Reveal in Finder button
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: entry.path)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(.dodoTextTertiary)
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0)
                .help(String(localized: "common.revealInFinder"))
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
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundColor(.dodoTextTertiary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .help(String(localized: "common.revealInFinder"))
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
