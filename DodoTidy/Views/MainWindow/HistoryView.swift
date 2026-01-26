import SwiftUI

struct HistoryView: View {
    @State private var historyManager = OperationHistoryManager.shared
    @State private var selectedFilter: OperationType? = nil
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()
                .background(Color.dodoBorder.opacity(0.2))

            if historyManager.operations.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Operation history")
                    .font(.dodoTitle)
                    .foregroundColor(.dodoTextPrimary)

                Text("View past cleaning, optimization, and analysis operations")
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextTertiary)
            }

            Spacer()

            // Filter menu
            Menu {
                Button("All operations") {
                    selectedFilter = nil
                }

                Divider()

                ForEach(OperationType.allCases, id: \.self) { type in
                    Button {
                        selectedFilter = type
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                            if selectedFilter == type {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(selectedFilter?.rawValue ?? "Filter")
                }
            }
            .buttonStyle(.dodoSecondary)

            Button {
                historyManager.clearHistory()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Clear")
                }
            }
            .buttonStyle(.dodoSecondary)
            .disabled(historyManager.operations.isEmpty)
        }
        .padding(DodoTidyDimensions.cardPaddingLarge)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.dodoTextTertiary)

            Text("No operations yet")
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            Text("Operations you perform will appear here")
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)
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

            // Operations list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredOperations) { operation in
                        OperationRow(operation: operation)

                        if operation.id != filteredOperations.last?.id {
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
                label: "Total operations",
                value: "\(historyManager.operations.count)"
            )

            Divider()
                .frame(height: 30)

            StatItem(
                label: "Space freed",
                value: historyManager.totalSpaceFreed.formattedBytes
            )

            Divider()
                .frame(height: 30)

            StatItem(
                label: "Success rate",
                value: "\(historyManager.successRate)%"
            )

            Spacer()
        }
        .padding(.horizontal, DodoTidyDimensions.cardPaddingLarge)
        .padding(.vertical, 12)
        .background(Color.dodoBackgroundSecondary)
    }

    private var filteredOperations: [OperationRecord] {
        var result = historyManager.operations

        if let filter = selectedFilter {
            result = result.filter { $0.type == filter }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Operation Row

struct OperationRow: View {
    let operation: OperationRecord

    @State private var isHovering = false
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: operation.type.icon)
                            .font(.system(size: 16))
                            .foregroundColor(statusColor)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(operation.name)
                            .font(.dodoBody)
                            .foregroundColor(.dodoTextPrimary)

                        HStack(spacing: 8) {
                            Text(operation.type.rawValue)
                                .font(.dodoCaptionSmall)
                                .foregroundColor(.dodoTextTertiary)

                            Text("•")
                                .foregroundColor(.dodoTextTertiary)

                            Text(operation.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.dodoCaptionSmall)
                                .foregroundColor(.dodoTextTertiary)
                        }
                    }

                    Spacer()

                    // Status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)

                        Text(operation.status.rawValue)
                            .font(.dodoCaption)
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Capsule())

                    // Expand indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.dodoTextTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, DodoTidyDimensions.cardPaddingLarge)
                .padding(.vertical, 12)
                .background(isHovering ? Color.dodoBackgroundTertiary.opacity(0.5) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if let details = operation.details {
                        Text(details)
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)
                    }

                    HStack(spacing: DodoTidyDimensions.spacingLarge) {
                        if operation.itemsProcessed > 0 {
                            DetailItem(label: "Items processed", value: "\(operation.itemsProcessed)")
                        }

                        if operation.spaceFreed > 0 {
                            DetailItem(label: "Space freed", value: operation.spaceFreed.formattedBytes)
                        }

                        if operation.duration > 0 {
                            DetailItem(label: "Duration", value: formatDuration(operation.duration))
                        }
                    }

                    if let errorMessage = operation.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.dodoDanger)
                            Text(errorMessage)
                                .font(.dodoCaption)
                                .foregroundColor(.dodoDanger)
                        }
                    }
                }
                .padding(.horizontal, DodoTidyDimensions.cardPaddingLarge)
                .padding(.bottom, 12)
                .padding(.leading, 52) // Align with text
            }
        }
    }

    private var statusColor: Color {
        switch operation.status {
        case .success: return .dodoSuccess
        case .failed: return .dodoDanger
        case .partial: return .dodoWarning
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(minutes)m \(secs)s"
        }
    }
}

struct DetailItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.dodoCaptionSmall)
                .foregroundColor(.dodoTextTertiary)

            Text(value)
                .font(.dodoCaption)
                .foregroundColor(.dodoTextPrimary)
        }
    }
}

// MARK: - Operation History Manager

@Observable
final class OperationHistoryManager {
    static let shared = OperationHistoryManager()

    private(set) var operations: [OperationRecord] = []

    private let maxOperations = 100
    private let userDefaultsKey = "operationHistory"

    private init() {
        loadFromDisk()
    }

    func addOperation(_ operation: OperationRecord) {
        operations.insert(operation, at: 0)

        // Keep only the most recent operations
        if operations.count > maxOperations {
            operations = Array(operations.prefix(maxOperations))
        }

        saveToDisk()
    }

    func clearHistory() {
        operations = []
        saveToDisk()
    }

    var totalSpaceFreed: Int64 {
        operations.reduce(0) { $0 + $1.spaceFreed }
    }

    var successRate: Int {
        guard !operations.isEmpty else { return 0 }
        let successful = operations.filter { $0.status == .success }.count
        return Int(Double(successful) / Double(operations.count) * 100)
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(operations)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save operation history: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            operations = try JSONDecoder().decode([OperationRecord].self, from: data)
        } catch {
            print("Failed to load operation history: \(error)")
        }
    }
}

// MARK: - Models

struct OperationRecord: Identifiable, Codable {
    let id: UUID
    let type: OperationType
    let name: String
    let timestamp: Date
    let status: OperationStatus
    let details: String?
    let itemsProcessed: Int
    let spaceFreed: Int64
    let duration: TimeInterval
    let errorMessage: String?

    init(
        id: UUID = UUID(),
        type: OperationType,
        name: String,
        timestamp: Date = Date(),
        status: OperationStatus,
        details: String? = nil,
        itemsProcessed: Int = 0,
        spaceFreed: Int64 = 0,
        duration: TimeInterval = 0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.timestamp = timestamp
        self.status = status
        self.details = details
        self.itemsProcessed = itemsProcessed
        self.spaceFreed = spaceFreed
        self.duration = duration
        self.errorMessage = errorMessage
    }
}

enum OperationType: String, Codable, CaseIterable {
    case cleaning = "Cleaning"
    case optimization = "Optimization"
    case analysis = "Analysis"
    case uninstall = "Uninstall"

    var icon: String {
        switch self {
        case .cleaning: return "trash"
        case .optimization: return "bolt"
        case .analysis: return "chart.pie"
        case .uninstall: return "xmark.app"
        }
    }
}

enum OperationStatus: String, Codable {
    case success = "Success"
    case failed = "Failed"
    case partial = "Partial"
}
