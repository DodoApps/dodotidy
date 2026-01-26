import SwiftUI

// MARK: - Scheduled Tasks Manager

@Observable
final class ScheduledTasksManager {
    static let shared = ScheduledTasksManager()

    private(set) var scheduledTasks: [ScheduledTask] = []
    private var timers: [UUID: Timer] = [:]

    private let userDefaultsKey = "scheduledTasks"

    private init() {
        loadFromDisk()
        startAllEnabledTasks()
    }

    func addTask(_ task: ScheduledTask) {
        scheduledTasks.append(task)
        saveToDisk()

        if task.isEnabled {
            scheduleTask(task)
        }
    }

    func removeTask(_ taskId: UUID) {
        cancelTask(taskId)
        scheduledTasks.removeAll { $0.id == taskId }
        saveToDisk()
    }

    func toggleTask(_ taskId: UUID) {
        guard let index = scheduledTasks.firstIndex(where: { $0.id == taskId }) else { return }
        scheduledTasks[index].isEnabled.toggle()
        saveToDisk()

        if scheduledTasks[index].isEnabled {
            scheduleTask(scheduledTasks[index])
        } else {
            cancelTask(taskId)
        }
    }

    func updateLastRun(_ taskId: UUID) {
        guard let index = scheduledTasks.firstIndex(where: { $0.id == taskId }) else { return }
        scheduledTasks[index].lastRun = Date()
        saveToDisk()
    }

    private func scheduleTask(_ task: ScheduledTask) {
        cancelTask(task.id)

        let interval: TimeInterval
        switch task.frequency {
        case .hourly: interval = 3600
        case .daily: interval = 86400
        case .weekly: interval = 604800
        case .monthly: interval = 2592000
        }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.executeTask(task)
        }

        timers[task.id] = timer
    }

    private func cancelTask(_ taskId: UUID) {
        timers[taskId]?.invalidate()
        timers.removeValue(forKey: taskId)
    }

    private func executeTask(_ task: ScheduledTask) {
        Task { @MainActor in
            // If confirmation is required, send a notification instead of auto-executing
            if AppSettings.shared.confirmScheduledTasks {
                sendPendingTaskNotification(for: task)
                return
            }

            await performTaskExecution(task)
        }
    }

    /// Actually perform the task execution (called after confirmation if required)
    private func performTaskExecution(_ task: ScheduledTask) async {
        switch task.taskType {
        case .cleanCaches:
            // SAFETY: Only scan safe auto-clean paths for scheduled tasks
            await DodoTidyService.shared.cleaner.scanForScheduledClean()
            DodoTidyService.shared.cleaner.selectAllItems()
            await DodoTidyService.shared.cleaner.cleanSelectedItems()

        case .cleanLogs:
            // SAFETY: Only scan safe auto-clean paths for scheduled tasks
            await DodoTidyService.shared.cleaner.scanForScheduledClean()
            DodoTidyService.shared.cleaner.deselectAllItems()
            DodoTidyService.shared.cleaner.selectItemsInCategories(containing: "log")
            await DodoTidyService.shared.cleaner.cleanSelectedItems()

        case .runOptimizations:
            await DodoTidyService.shared.optimizer.analyzeSystem()
            await DodoTidyService.shared.optimizer.runAllTasks()

        case .analyzeHome:
            await DodoTidyService.shared.analyzer.scanHome()
        }

        updateLastRun(task.id)

        // Send completion notification if enabled
        if AppSettings.shared.showNotifications {
            sendNotification(for: task)
        }
    }

    private func sendPendingTaskNotification(for task: ScheduledTask) {
        let content = UNMutableNotificationContent()
        content.title = "Scheduled task ready"
        content.body = "\(task.name) is ready to run. Open DodoTidy to review and confirm."
        content.sound = .default
        content.categoryIdentifier = "SCHEDULED_TASK_PENDING"

        let request = UNNotificationRequest(
            identifier: "pending-\(task.id.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func sendNotification(for task: ScheduledTask) {
        let content = UNMutableNotificationContent()
        content.title = "Scheduled task completed"
        content.body = "\(task.name) has finished running."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func startAllEnabledTasks() {
        for task in scheduledTasks where task.isEnabled {
            scheduleTask(task)
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(scheduledTasks)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save scheduled tasks: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            scheduledTasks = try JSONDecoder().decode([ScheduledTask].self, from: data)
        } catch {
            print("Failed to load scheduled tasks: \(error)")
        }
    }
}

// MARK: - Models

struct ScheduledTask: Identifiable, Codable {
    let id: UUID
    var name: String
    var taskType: ScheduledTaskType
    var frequency: TaskFrequency
    var isEnabled: Bool
    var lastRun: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        taskType: ScheduledTaskType,
        frequency: TaskFrequency,
        isEnabled: Bool = true,
        lastRun: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.taskType = taskType
        self.frequency = frequency
        self.isEnabled = isEnabled
        self.lastRun = lastRun
        self.createdAt = createdAt
    }
}

enum ScheduledTaskType: String, Codable, CaseIterable {
    case cleanCaches = "Clean caches"
    case cleanLogs = "Clean logs"
    case runOptimizations = "Run optimizations"
    case analyzeHome = "Analyze home directory"

    var icon: String {
        switch self {
        case .cleanCaches: return "folder.badge.minus"
        case .cleanLogs: return "doc.text"
        case .runOptimizations: return "bolt"
        case .analyzeHome: return "chart.pie"
        }
    }

    var description: String {
        switch self {
        case .cleanCaches: return "Clear browser caches, app caches, and developer caches"
        case .cleanLogs: return "Remove old system and crash logs"
        case .runOptimizations: return "Run all available system optimizations"
        case .analyzeHome: return "Scan home directory for disk usage"
        }
    }
}

enum TaskFrequency: String, Codable, CaseIterable {
    case hourly = "Hourly"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

// MARK: - Scheduled Tasks View

struct ScheduledTasksView: View {
    @State private var manager = ScheduledTasksManager.shared
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()
                .background(Color.dodoBorder.opacity(0.2))

            if manager.scheduledTasks.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddScheduledTaskSheet { task in
                manager.addTask(task)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Scheduled tasks")
                    .font(.dodoTitle)
                    .foregroundColor(.dodoTextPrimary)

                Text("Automate cleaning and optimization tasks")
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextTertiary)
            }

            Spacer()

            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add task")
                }
            }
            .buttonStyle(.dodoPrimary)
        }
        .padding(DodoTidyDimensions.cardPaddingLarge)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.dodoTextTertiary)

            Text("No scheduled tasks")
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            Text("Create automated tasks to keep your system clean")
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)

            Button {
                showAddSheet = true
            } label: {
                Text("Add your first task")
            }
            .buttonStyle(.dodoPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: DodoTidyDimensions.spacing) {
                ForEach(manager.scheduledTasks) { task in
                    ScheduledTaskCard(
                        task: task,
                        onToggle: { manager.toggleTask(task.id) },
                        onDelete: { manager.removeTask(task.id) }
                    )
                }
            }
            .padding(DodoTidyDimensions.cardPaddingLarge)
        }
    }
}

// MARK: - Scheduled Task Card

struct ScheduledTaskCard: View {
    let task: ScheduledTask
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(task.isEnabled ? Color.dodoPrimary.opacity(0.15) : Color.dodoBackgroundTertiary)
                    .frame(width: 44, height: 44)

                Image(systemName: task.taskType.icon)
                    .font(.system(size: 18))
                    .foregroundColor(task.isEnabled ? .dodoPrimary : .dodoTextTertiary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.dodoSubheadline)
                    .foregroundColor(.dodoTextPrimary)

                Text(task.taskType.description)
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextSecondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(task.frequency.rawValue, systemImage: "clock")
                        .font(.dodoCaptionSmall)
                        .foregroundColor(.dodoTextTertiary)

                    if let lastRun = task.lastRun {
                        Text("•")
                            .foregroundColor(.dodoTextTertiary)
                        Text("Last run: \(lastRun.formatted(date: .abbreviated, time: .shortened))")
                            .font(.dodoCaptionSmall)
                            .foregroundColor(.dodoTextTertiary)
                    }
                }
            }

            Spacer()

            // Toggle and delete
            HStack(spacing: 12) {
                Toggle("", isOn: .init(
                    get: { task.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()

                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.dodoDanger)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DodoTidyDimensions.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadiusMedium)
                .fill(isHovering ? Color.dodoBackgroundTertiary : Color.dodoBackgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadiusMedium)
                .stroke(Color.dodoBorder.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Add Scheduled Task Sheet

struct AddScheduledTaskSheet: View {
    let onAdd: (ScheduledTask) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var taskType: ScheduledTaskType = .cleanCaches
    @State private var frequency: TaskFrequency = .daily

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add scheduled task")
                    .font(.dodoHeadline)
                    .foregroundColor(.dodoTextPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.dodoTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(DodoTidyDimensions.cardPaddingLarge)

            Divider()

            // Form
            Form {
                Section {
                    TextField("Task name", text: $name)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Name")
                }

                Section {
                    Picker("Task type", selection: $taskType) {
                        ForEach(ScheduledTaskType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text(taskType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Action")
                }

                Section {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(TaskFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Schedule")
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.dodoSecondary)

                Spacer()

                Button("Add task") {
                    let task = ScheduledTask(
                        name: name.isEmpty ? taskType.rawValue : name,
                        taskType: taskType,
                        frequency: frequency
                    )
                    onAdd(task)
                    dismiss()
                }
                .buttonStyle(.dodoPrimary)
            }
            .padding(DodoTidyDimensions.cardPaddingLarge)
        }
        .frame(width: 450, height: 480)
    }
}

import UserNotifications
