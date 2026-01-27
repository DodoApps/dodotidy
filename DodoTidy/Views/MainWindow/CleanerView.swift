import SwiftUI

struct CleanerView: View {
    @State private var dodoService = DodoTidyService.shared
    @State private var showConfirmation = false
    @State private var showFilePreview = false
    @State private var previewFiles: [FilePreviewItem] = []
    @State private var isLoadingPreview = false

    // Filtering
    @State private var searchText = ""
    @State private var minSizeFilter: SizeFilter = .any
    @State private var selectedCategories: Set<String> = []
    @State private var showFilterPopover = false

    enum SizeFilter: String, CaseIterable {
        case any = "Any size"
        case over10MB = "> 10 MB"
        case over100MB = "> 100 MB"
        case over500MB = "> 500 MB"
        case over1GB = "> 1 GB"

        var minBytes: Int64 {
            switch self {
            case .any: return 0
            case .over10MB: return 10_000_000
            case .over100MB: return 100_000_000
            case .over500MB: return 500_000_000
            case .over1GB: return 1_000_000_000
            }
        }

        var localizedName: String {
            switch self {
            case .any: return String(localized: "cleaner.anySize")
            case .over10MB: return "> 10 MB"
            case .over100MB: return "> 100 MB"
            case .over500MB: return "> 500 MB"
            case .over1GB: return "> 1 GB"
            }
        }
    }

    private var filteredCategories: [CleaningCategory] {
        var result = dodoService.cleaner.categories

        // Filter by search text
        if !searchText.isEmpty {
            result = result.compactMap { category in
                let filteredItems = category.items.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.path.localizedCaseInsensitiveContains(searchText)
                }
                if filteredItems.isEmpty { return nil }
                var newCategory = category
                newCategory.items = filteredItems
                return newCategory
            }
        }

        // Filter by minimum size
        if minSizeFilter != .any {
            result = result.compactMap { category in
                let filteredItems = category.items.filter { $0.size >= minSizeFilter.minBytes }
                if filteredItems.isEmpty { return nil }
                var newCategory = category
                newCategory.items = filteredItems
                return newCategory
            }
        }

        // Filter by selected categories
        if !selectedCategories.isEmpty {
            result = result.filter { selectedCategories.contains($0.name) }
        }

        return result
    }

    private var isFiltering: Bool {
        !searchText.isEmpty || minSizeFilter != .any || !selectedCategories.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()
                .background(Color.dodoBorder.opacity(0.2))

            if dodoService.cleaner.isScanning {
                // Loading state
                loadingView
            } else if let error = dodoService.cleaner.error {
                // Error state
                errorView(error: error)
            } else if dodoService.cleaner.categories.isEmpty {
                // Empty state
                emptyStateView
            } else {
                // Content
                contentView
            }

            // Footer with action buttons
            if !dodoService.cleaner.categories.isEmpty {
                Divider()
                    .background(Color.dodoBorder.opacity(0.2))

                footerSection
            }
        }
        .task {
            if dodoService.cleaner.categories.isEmpty {
                await dodoService.cleaner.scanForCleanableItems()
            }
        }
        .alert(String(localized: "cleaner.confirmTitle"), isPresented: $showConfirmation) {
            Button(String(localized: "common.cancel"), role: .cancel) { }
            Button(String(localized: "cleaner.moveToTrash"), role: .destructive) {
                Task {
                    await dodoService.cleaner.cleanSelectedItems()
                    // Show toast notification
                    ToastManager.shared.show(ToastData(
                        type: .success,
                        title: String(localized: "cleaner.completeTitle"),
                        message: String(format: String(localized: "cleaner.freedMessage"), dodoService.cleaner.lastCleanedSize.formattedBytes)
                    ))
                }
            }
        } message: {
            Text(String(format: String(localized: "cleaner.confirmMessage"), dodoService.cleaner.totalSelectedCount, dodoService.cleaner.totalSelectedSize.formattedBytes))
        }
        .sheet(isPresented: $showFilePreview) {
            FilePreviewSheet(
                previewFiles: previewFiles,
                totalSize: dodoService.cleaner.totalSelectedSize,
                totalCount: dodoService.cleaner.totalSelectedCount,
                isLoading: isLoadingPreview,
                onConfirm: {
                    showFilePreview = false
                    Task {
                        await dodoService.cleaner.cleanSelectedItems()
                        ToastManager.shared.show(ToastData(
                            type: .success,
                            title: String(localized: "cleaner.completeTitle"),
                            message: String(format: String(localized: "cleaner.freedMessage"), dodoService.cleaner.lastCleanedSize.formattedBytes)
                        ))
                    }
                },
                onCancel: {
                    showFilePreview = false
                }
            )
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await dodoService.cleaner.scanForCleanableItems()
                    }
                } label: {
                    Label(String(localized: "cleaner.rescan"), systemImage: "arrow.clockwise")
                }
                .help(String(localized: "cleaner.rescan"))
                .disabled(dodoService.cleaner.isScanning)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "cleaner.title"))
                        .font(.dodoTitle)
                        .foregroundColor(.dodoTextPrimary)

                    Text(String(localized: "cleaner.subtitle"))
                        .font(.dodoCaption)
                        .foregroundColor(.dodoTextTertiary)
                }

                Spacer()

                Button {
                    Task {
                        await dodoService.cleaner.scanForCleanableItems()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text(String(localized: "cleaner.rescan"))
                    }
                }
                .buttonStyle(.dodoSecondary)
            }

            // Filter bar
            if !dodoService.cleaner.categories.isEmpty {
                filterBar
            }
        }
        .padding(DodoTidyDimensions.cardPaddingLarge)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.dodoTextTertiary)

                TextField(String(localized: "cleaner.searchItems"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.dodoBody)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.dodoTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: DodoTidyDimensions.buttonHeight)
            .background(Color.dodoBackgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadius))
            .frame(maxWidth: 220)

            // Size filter
            Menu {
                ForEach(SizeFilter.allCases, id: \.self) { filter in
                    Button {
                        minSizeFilter = filter
                    } label: {
                        HStack {
                            Text(filter.localizedName)
                            if minSizeFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(minSizeFilter.localizedName)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                }
                .foregroundColor(minSizeFilter == .any ? .dodoTextSecondary : .dodoPrimary)
            }
            .buttonStyle(.dodoSecondary)

            // Category filter
            Menu {
                Button(String(localized: "cleaner.allCategories")) {
                    selectedCategories.removeAll()
                }

                Divider()

                ForEach(dodoService.cleaner.categories, id: \.id) { category in
                    Button {
                        if selectedCategories.contains(category.name) {
                            selectedCategories.remove(category.name)
                        } else {
                            selectedCategories.insert(category.name)
                        }
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.name)
                            if selectedCategories.contains(category.name) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(selectedCategories.isEmpty ? String(localized: "cleaner.categories") : String(localized: "cleaner.selected \(selectedCategories.count)"))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                }
                .foregroundColor(selectedCategories.isEmpty ? .dodoTextSecondary : .dodoPrimary)
            }
            .buttonStyle(.dodoSecondary)

            Spacer()

            // Quick actions
            HStack(spacing: 8) {
                Button {
                    selectAllVisible()
                } label: {
                    Text(String(localized: "cleaner.selectAll"))
                }
                .buttonStyle(.plain)
                .foregroundColor(.dodoPrimary)
                .font(.dodoCaption)

                Text("•")
                    .foregroundColor(.dodoTextTertiary)

                Button {
                    deselectAllVisible()
                } label: {
                    Text(String(localized: "cleaner.deselectAll"))
                }
                .buttonStyle(.plain)
                .foregroundColor(.dodoTextSecondary)
                .font(.dodoCaption)
            }

            // Clear filters
            if isFiltering {
                Button {
                    searchText = ""
                    minSizeFilter = .any
                    selectedCategories.removeAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text(String(localized: "cleaner.clearFilters"))
                    }
                    .font(.dodoCaption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.dodoDanger)
            }
        }
    }

    private func selectAllVisible() {
        for category in filteredCategories {
            dodoService.cleaner.selectAll(categoryId: category.id)
        }
    }

    private func deselectAllVisible() {
        for category in filteredCategories {
            dodoService.cleaner.deselectAll(categoryId: category.id)
        }
    }

    private func loadFilePreview() {
        isLoadingPreview = true
        previewFiles = []

        Task {
            var files: [FilePreviewItem] = []

            for category in dodoService.cleaner.categories {
                for item in category.items where item.isSelected {
                    // Get sample files from this item
                    let sampleFiles = await getSampleFiles(at: item.path, limit: 20)
                    files.append(FilePreviewItem(
                        categoryName: category.name,
                        itemName: item.name,
                        itemPath: item.path,
                        itemSize: item.size,
                        fileCount: item.fileCount,
                        sampleFiles: sampleFiles,
                        warning: category.warning
                    ))
                }
            }

            await MainActor.run {
                previewFiles = files
                isLoadingPreview = false
                showFilePreview = true
            }
        }
    }

    private func getSampleFiles(at path: String, limit: Int) async -> [SampleFile] {
        var sampleFiles: [SampleFile] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey])
                if resourceValues.isRegularFile == true {
                    let size = Int64(resourceValues.fileSize ?? 0)
                    let modDate = resourceValues.contentModificationDate
                    sampleFiles.append(SampleFile(
                        path: fileURL.path,
                        name: fileURL.lastPathComponent,
                        size: size,
                        modificationDate: modDate
                    ))
                }
            } catch {
                continue
            }

            if sampleFiles.count >= limit { break }
        }

        // Sort by size descending
        sampleFiles.sort { $0.size > $1.size }
        return sampleFiles
    }

    // MARK: - Loading View

    @State private var fileAnimationOffsets: [CGFloat] = [0, 0, 0]
    @State private var fileAnimationOpacities: [Double] = [1, 1, 1]
    @State private var trashPulseScale: CGFloat = 1.0

    private var loadingView: some View {
        VStack(spacing: 24) {
            // Animated trash with files
            ZStack {
                // Trash can icon
                Image(systemName: "trash")
                    .font(.system(size: 56))
                    .foregroundColor(.dodoPrimary)
                    .scaleEffect(trashPulseScale)

                // Animated file icons
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "doc.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.dodoTextTertiary)
                        .offset(x: CGFloat(index - 1) * 18, y: fileAnimationOffsets[index] - 50)
                        .opacity(fileAnimationOpacities[index])
                }

                // Progress overlay
                Circle()
                    .trim(from: 0, to: dodoService.cleaner.scanProgress)
                    .stroke(Color.dodoPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
            }
            .frame(height: 100)
            .onAppear {
                startLoadingAnimation()
            }

            VStack(spacing: 8) {
                Text(String(localized: "cleaner.scanning"))
                    .font(.dodoBody)
                    .foregroundColor(.dodoTextSecondary)

                // Progress percentage
                Text("\(Int(dodoService.cleaner.scanProgress * 100))%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.dodoPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                if !dodoService.cleaner.currentScanItem.isEmpty {
                    Text(dodoService.cleaner.currentScanItem)
                        .font(.dodoCaption)
                        .foregroundColor(.dodoTextTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 300)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startLoadingAnimation() {
        // Animate files falling into trash
        for index in 0..<3 {
            let delay = Double(index) * 0.25
            withAnimation(.easeIn(duration: 0.5).delay(delay).repeatForever(autoreverses: false)) {
                fileAnimationOffsets[index] = 70
                fileAnimationOpacities[index] = 0
            }
        }

        // Pulse trash can
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            trashPulseScale = 1.08
        }
    }

    // MARK: - Error State

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.dodoDanger)

            Text(String(localized: "common.somethingWrong"))
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            Text(error.localizedDescription)
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button {
                Task {
                    await dodoService.cleaner.scanForCleanableItems()
                }
            } label: {
                Text(String(localized: "optimizer.tryAgain"))
            }
            .buttonStyle(.dodoPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.dodoPrimary)

            Text(String(localized: "cleaner.systemClean"))
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            Text(String(localized: "cleaner.noUnnecessary"))
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)

            Button {
                Task {
                    await dodoService.cleaner.scanForCleanableItems()
                }
            } label: {
                Text(String(localized: "cleaner.scanAgain"))
            }
            .buttonStyle(.dodoPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(spacing: DodoTidyDimensions.spacing) {
                // Show filter results info
                if isFiltering {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.dodoTextTertiary)
                        Text(String(format: String(localized: "cleaner.showingItems"), filteredCategories.flatMap { $0.items }.count, filteredCategories.count))
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }

                ForEach(filteredCategories) { category in
                    CleaningCategoryView(
                        category: category,
                        onToggleItem: { itemId in
                            dodoService.cleaner.toggleSelection(categoryId: category.id, itemId: itemId)
                        },
                        onSelectAll: {
                            dodoService.cleaner.selectAll(categoryId: category.id)
                        },
                        onDeselectAll: {
                            dodoService.cleaner.deselectAll(categoryId: category.id)
                        }
                    )
                }

                // No results from filter
                if isFiltering && filteredCategories.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.dodoTextTertiary)

                        Text(String(localized: "cleaner.noItemsMatch"))
                            .font(.dodoBody)
                            .foregroundColor(.dodoTextSecondary)

                        Button {
                            searchText = ""
                            minSizeFilter = .any
                            selectedCategories.removeAll()
                        } label: {
                            Text(String(localized: "cleaner.clearFilters"))
                        }
                        .buttonStyle(.dodoSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(DodoTidyDimensions.cardPaddingLarge)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "cleaner.totalSelected"))
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextTertiary)

                HStack(spacing: 8) {
                    Text(dodoService.cleaner.totalSelectedSize.formattedBytes)
                        .font(.dodoHeadline)
                        .foregroundColor(.dodoTextPrimary)

                    Text(String(localized: "cleaner.items \(dodoService.cleaner.totalSelectedCount)"))
                        .font(.dodoCaption)
                        .foregroundColor(.dodoTextSecondary)
                }
            }

            Spacer()

            // Info about safe deletion
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                Text(String(localized: "cleaner.movedToTrash"))
                    .font(.dodoCaptionSmall)
            }
            .foregroundColor(.dodoTextTertiary)
            .padding(.trailing, 12)

            Button {
                loadFilePreview()
            } label: {
                HStack(spacing: 6) {
                    if dodoService.cleaner.isCleaning || isLoadingPreview {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text(dodoService.cleaner.isCleaning ? String(localized: "cleaner.cleaning") : (isLoadingPreview ? String(localized: "cleaner.loading") : String(localized: "cleaner.cleanSelected")))
                }
            }
            .buttonStyle(.dodoPrimary)
            .disabled(dodoService.cleaner.totalSelectedCount == 0 || dodoService.cleaner.isCleaning || isLoadingPreview)
        }
        .padding(DodoTidyDimensions.cardPaddingLarge)
        .background(Color.dodoBackgroundSecondary)
    }
}

// MARK: - Cleaning Category View

struct CleaningCategoryView: View {
    let category: CleaningCategory
    let onToggleItem: (UUID) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Category header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.system(size: 18))
                        .foregroundColor(.dodoPrimary)
                        .frame(width: 24)

                    Text(category.name)
                        .font(.dodoSubheadline)
                        .foregroundColor(.dodoTextPrimary)

                    Spacer()

                    Text(category.totalSize.formattedBytes)
                        .font(.dodoBody)
                        .foregroundColor(.dodoTextSecondary)
                        .monospacedDigit()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.dodoTextTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(DodoTidyDimensions.cardPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .background(Color.dodoBorder.opacity(0.2))

                // Category items
                VStack(spacing: 0) {
                    ForEach(category.items) { item in
                        CleaningItemRow(
                            item: item,
                            onToggle: { onToggleItem(item.id) }
                        )

                        if item.id != category.items.last?.id {
                            Divider()
                                .background(Color.dodoBorder.opacity(0.1))
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .background(Color.dodoBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadiusMedium)
                .stroke(Color.dodoBorder.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Cleaning Item Row

struct CleaningItemRow: View {
    let item: CleaningItem
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(item.isSelected ? Color.dodoPrimary : Color.dodoBorder, lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if item.isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.dodoPrimary)
                            .frame(width: 18, height: 18)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // Item info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.dodoBody)
                    .foregroundColor(.dodoTextPrimary)

                HStack(spacing: 6) {
                    Text(String(format: String(localized: "cleaner.files"), item.fileCount.formattedWithSeparator))
                        .font(.dodoCaptionSmall)
                        .foregroundColor(.dodoTextTertiary)

                    // Show location hint for orphaned items
                    if let location = item.locationHint {
                        Text("•")
                            .font(.dodoCaptionSmall)
                            .foregroundColor(.dodoTextTertiary)
                        Text(location)
                            .font(.dodoCaptionSmall)
                            .foregroundColor(.dodoTextTertiary)
                    }
                }
            }

            Spacer()

            // Size
            Text(item.size.formattedBytes)
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, DodoTidyDimensions.cardPadding)
        .padding(.vertical, 10)
        .background(isHovering ? Color.dodoBackgroundTertiary.opacity(0.5) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - File Preview Types

struct FilePreviewItem: Identifiable {
    let id = UUID()
    let categoryName: String
    let itemName: String
    let itemPath: String
    let itemSize: Int64
    let fileCount: Int
    let sampleFiles: [SampleFile]
    let warning: String?
}

struct SampleFile: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let modificationDate: Date?
}

// MARK: - File Preview Sheet

struct FilePreviewSheet: View {
    let previewFiles: [FilePreviewItem]
    let totalSize: Int64
    let totalCount: Int
    let isLoading: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var expandedItems: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.dodoWarning)
                            .font(.system(size: 20))
                        Text(String(localized: "preview.title"))
                            .font(.dodoTitle)
                            .foregroundColor(.dodoTextPrimary)
                    }
                    Text(String(localized: "preview.subtitle"))
                        .font(.dodoCaption)
                        .foregroundColor(.dodoTextTertiary)
                }

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.dodoTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(DodoTidyDimensions.cardPaddingLarge)
            .background(Color.dodoBackgroundSecondary)

            Divider()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(String(localized: "preview.loadingPreview"))
                        .font(.dodoBody)
                        .foregroundColor(.dodoTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Content
                ScrollView {
                    VStack(spacing: 12) {
                        // Warnings first
                        ForEach(previewFiles.filter { $0.warning != nil }) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.dodoWarning)
                                Text(item.warning ?? "")
                                    .font(.dodoCaption)
                                    .foregroundColor(.dodoWarning)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.dodoWarning.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadius))
                        }

                        // File items
                        ForEach(previewFiles) { item in
                            FilePreviewItemView(
                                item: item,
                                isExpanded: expandedItems.contains(item.id),
                                onToggle: {
                                    if expandedItems.contains(item.id) {
                                        expandedItems.remove(item.id)
                                    } else {
                                        expandedItems.insert(item.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(DodoTidyDimensions.cardPaddingLarge)
                }
            }

            Divider()

            // Footer
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "preview.totalToRemove"))
                        .font(.dodoCaption)
                        .foregroundColor(.dodoTextTertiary)

                    HStack(spacing: 8) {
                        Text(totalSize.formattedBytes)
                            .font(.dodoHeadline)
                            .foregroundColor(.dodoTextPrimary)

                        Text(String(format: String(localized: "cleaner.items"), totalCount))
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(String(localized: "common.cancel")) {
                        onCancel()
                    }
                    .buttonStyle(.dodoSecondary)

                    Button {
                        onConfirm()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text(String(localized: "cleaner.moveToTrash"))
                        }
                    }
                    .buttonStyle(.dodoPrimary)
                }
            }
            .padding(DodoTidyDimensions.cardPaddingLarge)
            .background(Color.dodoBackgroundSecondary)
        }
        .frame(width: 600, height: 500)
        .background(Color.dodoBackground)
    }
}

// MARK: - File Preview Item View

struct FilePreviewItemView: View {
    let item: FilePreviewItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.dodoTextTertiary)
                        .frame(width: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.itemName)
                            .font(.dodoSubheadline)
                            .foregroundColor(.dodoTextPrimary)

                        Text(item.categoryName)
                            .font(.dodoCaptionSmall)
                            .foregroundColor(.dodoTextTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.itemSize.formattedBytes)
                            .font(.dodoBody)
                            .foregroundColor(.dodoTextSecondary)
                            .monospacedDigit()

                        Text("\(item.fileCount.formattedWithSeparator) files")
                            .font(.dodoCaptionSmall)
                            .foregroundColor(.dodoTextTertiary)
                    }
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.leading, 36)

                VStack(spacing: 0) {
                    // Path info
                    HStack {
                        Text(String(localized: "preview.path"))
                            .font(.dodoCaptionSmall)
                            .foregroundColor(.dodoTextTertiary)
                        Text(item.itemPath)
                            .font(.dodoCaptionSmall)
                            .foregroundColor(.dodoTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.dodoBackgroundTertiary.opacity(0.5))

                    // Sample files
                    if !item.sampleFiles.isEmpty {
                        VStack(spacing: 0) {
                            HStack {
                                Text(String(format: String(localized: "preview.sampleFiles"), item.sampleFiles.count, item.fileCount.formattedWithSeparator))
                                    .font(.dodoCaptionSmall)
                                    .foregroundColor(.dodoTextTertiary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)

                            ForEach(item.sampleFiles) { file in
                                HStack(spacing: 8) {
                                    Image(systemName: "doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(.dodoTextTertiary)
                                        .frame(width: 16)

                                    Text(file.name)
                                        .font(.dodoCaptionSmall)
                                        .foregroundColor(.dodoTextSecondary)
                                        .lineLimit(1)

                                    Spacer()

                                    if let modDate = file.modificationDate {
                                        Text(modDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.dodoCaptionSmall)
                                            .foregroundColor(.dodoTextTertiary)
                                    }

                                    Text(file.size.formattedBytes)
                                        .font(.dodoCaptionSmall)
                                        .foregroundColor(.dodoTextTertiary)
                                        .monospacedDigit()
                                        .frame(width: 60, alignment: .trailing)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.dodoBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadius)
                .stroke(Color.dodoBorder.opacity(0.2), lineWidth: 1)
        )
    }
}
