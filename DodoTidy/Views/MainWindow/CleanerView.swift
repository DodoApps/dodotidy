import SwiftUI

struct CleanerView: View {
    @State private var dodoService = DodoTidyService.shared
    @State private var showConfirmation = false
    @State private var showCleanedAlert = false

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
        .alert("Confirm cleaning", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                Task {
                    await dodoService.cleaner.cleanSelectedItems()
                    showCleanedAlert = true
                }
            }
        } message: {
            Text("Are you sure you want to move \(dodoService.cleaner.totalSelectedCount) items (\(dodoService.cleaner.totalSelectedSize.formattedBytes)) to Trash?\n\nThis action can be undone by restoring items from Trash.")
        }
        .alert("Cleaning complete", isPresented: $showCleanedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Successfully freed \(dodoService.cleaner.lastCleanedSize.formattedBytes) of disk space.\n\nItems have been moved to Trash.")
        }
        .navigationTitle("Cleaner")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await dodoService.cleaner.scanForCleanableItems()
                    }
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .help("Scan for cleanable items")
                .disabled(dodoService.cleaner.isScanning)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System cleaner")
                        .font(.dodoTitle)
                        .foregroundColor(.dodoTextPrimary)

                    Text("Remove unnecessary files to free up disk space")
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
                        Text("Rescan")
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

                TextField("Search items...", text: $searchText)
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
            .padding(.vertical, 6)
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
                            Text(filter.rawValue)
                            if minSizeFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(minSizeFilter.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(minSizeFilter == .any ? .dodoTextSecondary : .dodoPrimary)
            }
            .buttonStyle(.dodoSecondary)

            // Category filter
            Menu {
                Button("All categories") {
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
                    Text(selectedCategories.isEmpty ? "Categories" : "\(selectedCategories.count) selected")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
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
                    Text("Select all")
                }
                .buttonStyle(.plain)
                .foregroundColor(.dodoPrimary)
                .font(.dodoCaption)

                Text("•")
                    .foregroundColor(.dodoTextTertiary)

                Button {
                    deselectAllVisible()
                } label: {
                    Text("Deselect all")
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
                        Text("Clear filters")
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

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.dodoBackgroundTertiary, lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: dodoService.cleaner.scanProgress)
                    .stroke(Color.dodoPrimary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: dodoService.cleaner.scanProgress)

                Text("\(Int(dodoService.cleaner.scanProgress * 100))%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.dodoTextPrimary)
                    .monospacedDigit()
            }

            VStack(spacing: 4) {
                Text("Scanning for cleanable items...")
                    .font(.dodoBody)
                    .foregroundColor(.dodoTextSecondary)

                if !dodoService.cleaner.currentScanItem.isEmpty {
                    Text(dodoService.cleaner.currentScanItem)
                        .font(.dodoCaption)
                        .foregroundColor(.dodoTextTertiary)
                        .animation(.easeInOut(duration: 0.1), value: dodoService.cleaner.currentScanItem)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.dodoDanger)

            Text("Something went wrong")
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
                Text("Try again")
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

            Text("Your system is clean")
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            Text("No unnecessary files were found")
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)

            Button {
                Task {
                    await dodoService.cleaner.scanForCleanableItems()
                }
            } label: {
                Text("Scan again")
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
                        Text("Showing \(filteredCategories.flatMap { $0.items }.count) items in \(filteredCategories.count) categories")
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

                        Text("No items match your filters")
                            .font(.dodoBody)
                            .foregroundColor(.dodoTextSecondary)

                        Button {
                            searchText = ""
                            minSizeFilter = .any
                            selectedCategories.removeAll()
                        } label: {
                            Text("Clear filters")
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
                Text("Total selected")
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextTertiary)

                HStack(spacing: 8) {
                    Text(dodoService.cleaner.totalSelectedSize.formattedBytes)
                        .font(.dodoHeadline)
                        .foregroundColor(.dodoTextPrimary)

                    Text("(\(dodoService.cleaner.totalSelectedCount) items)")
                        .font(.dodoCaption)
                        .foregroundColor(.dodoTextSecondary)
                }
            }

            Spacer()

            // Info about safe deletion
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                Text("Items are moved to Trash")
                    .font(.dodoCaptionSmall)
            }
            .foregroundColor(.dodoTextTertiary)
            .padding(.trailing, 12)

            Button {
                showConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    if dodoService.cleaner.isCleaning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text(dodoService.cleaner.isCleaning ? "Cleaning..." : "Clean selected")
                }
            }
            .buttonStyle(.dodoPrimary)
            .disabled(dodoService.cleaner.totalSelectedCount == 0 || dodoService.cleaner.isCleaning)
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
                            .font(.system(size: 10, weight: .bold))
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

                Text("\(item.fileCount.formattedWithSeparator) files")
                    .font(.dodoCaptionSmall)
                    .foregroundColor(.dodoTextTertiary)
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
