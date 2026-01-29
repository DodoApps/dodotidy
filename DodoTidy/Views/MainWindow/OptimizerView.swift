import SwiftUI

struct OptimizerView: View {
    @State private var dodoService = DodoTidyService.shared
    @State private var taskToConfirm: OptimizationTask?
    @State private var showConfirmation = false
    @State private var showRunAllConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            if dodoService.optimizer.isAnalyzing {
                loadingView
            } else if let error = dodoService.optimizer.error {
                errorView(error: error)
            } else if dodoService.optimizer.tasks.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await dodoService.optimizer.analyzeSystem()
                    }
                } label: {
                    Label(String(localized: "optimizer.reanalyze"), systemImage: "arrow.clockwise")
                }
                .help(String(localized: "optimizer.reanalyze"))
                .disabled(dodoService.optimizer.isAnalyzing)
            }

            ToolbarItem(placement: .automatic) {
                if !dodoService.optimizer.tasks.isEmpty {
                    Button {
                        showRunAllConfirmation = true
                    } label: {
                        Label(String(localized: "optimizer.runAll"), systemImage: "play.fill")
                    }
                    .help(String(localized: "optimizer.runAll"))
                    .disabled(dodoService.optimizer.pendingTaskCount == 0)
                }
            }
        }
        .task {
            if dodoService.optimizer.tasks.isEmpty {
                await dodoService.optimizer.analyzeSystem()
            }
        }
        .alert(String(localized: "optimizer.confirmTitle"), isPresented: $showConfirmation) {
            Button(String(localized: "common.cancel"), role: .cancel) {
                taskToConfirm = nil
            }
            Button(String(localized: "optimizer.run")) {
                if let task = taskToConfirm {
                    Task {
                        await dodoService.optimizer.runTask(task.id)
                        // Show toast based on result
                        if let updatedTask = dodoService.optimizer.tasks.first(where: { $0.id == task.id }) {
                            switch updatedTask.status {
                            case .completed:
                                ToastManager.shared.show(ToastData(
                                    type: .success,
                                    title: String(localized: "optimizer.optimizationComplete"),
                                    message: updatedTask.benefit
                                ))
                            case .failed(let error):
                                ToastManager.shared.show(ToastData(
                                    type: .error,
                                    title: String(localized: "optimizer.optimizationFailed"),
                                    message: error
                                ))
                            default:
                                break
                            }
                        }
                    }
                }
                taskToConfirm = nil
            }
        } message: {
            if let task = taskToConfirm {
                Text(String(format: String(localized: "optimizer.confirmMessage"), task.name, task.description))
            }
        }
        .alert(String(localized: "optimizer.confirmAllTitle"), isPresented: $showRunAllConfirmation) {
            Button(String(localized: "common.cancel"), role: .cancel) { }
            Button(String(localized: "optimizer.runAll")) {
                Task {
                    let beforeCompleted = dodoService.optimizer.completedTaskCount
                    let beforeFailed = dodoService.optimizer.failedTaskCount
                    await dodoService.optimizer.runAllTasks()
                    let newCompleted = dodoService.optimizer.completedTaskCount - beforeCompleted
                    let newFailed = dodoService.optimizer.failedTaskCount - beforeFailed

                    if newFailed > 0 {
                        ToastManager.shared.show(ToastData(
                            type: .warning,
                            title: String(localized: "optimizer.optimizationsCompleted"),
                            message: String(format: String(localized: "optimizer.completedWithFailures"), newCompleted, newFailed)
                        ))
                    } else {
                        ToastManager.shared.show(ToastData(
                            type: .success,
                            title: String(localized: "optimizer.allComplete"),
                            message: String(format: String(localized: "optimizer.tasksCompleted"), newCompleted)
                        ))
                    }
                }
            }
        } message: {
            Text(String(format: String(localized: "optimizer.confirmAllMessage"), dodoService.optimizer.pendingTaskCount, pendingTaskNames))
        }
    }

    private var pendingTaskNames: String {
        dodoService.optimizer.tasks
            .filter { if case .pending = $0.status { return true } else { return false } }
            .map { "• \($0.name)" }
            .joined(separator: "\n")
    }

    // MARK: - Loading View

    @State private var boltOpacities: [Double] = [0.3, 0.3, 0.3]
    @State private var boltScales: [CGFloat] = [0.8, 0.8, 0.8]

    private var loadingView: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.dodoWarning)
                        .opacity(boltOpacities[index])
                        .scaleEffect(boltScales[index])
                }
            }
            .frame(height: 60)

            VStack(spacing: 8) {
                Text(String(localized: "optimizer.analyzing"))
                    .font(.dodoBody)
                    .foregroundColor(.dodoTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startBoltAnimation()
        }
    }

    private func startBoltAnimation() {
        for index in 0..<3 {
            let delay = Double(index) * 0.2

            withAnimation(.easeInOut(duration: 0.5).delay(delay).repeatForever(autoreverses: true)) {
                boltOpacities[index] = 1.0
                boltScales[index] = 1.2
            }
        }
    }

    // MARK: - Error State

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.dodoDanger)

            Text(String(localized: "optimizer.analysisFailed"))
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            Text(error.localizedDescription)
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button {
                Task {
                    await dodoService.optimizer.analyzeSystem()
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
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(.dodoSuccess)

            Text(String(localized: "optimizer.systemOptimized"))
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            Text(String(localized: "optimizer.noTasksNeeded"))
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)

            Button {
                Task {
                    await dodoService.optimizer.analyzeSystem()
                }
            } label: {
                Text(String(localized: "optimizer.checkAgain"))
            }
            .buttonStyle(.dodoPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DodoTidyDimensions.spacing) {
                    ForEach(dodoService.optimizer.tasks) { task in
                        OptimizationTaskCard(task: task) {
                            taskToConfirm = task
                            showConfirmation = true
                        }
                    }
                }
                .padding(DodoTidyDimensions.cardPaddingLarge)
            }

            Divider()
                .background(Color.dodoBorder.opacity(0.2))

            // Footer
            footerSection
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            // Status summary
            HStack(spacing: 16) {
                if dodoService.optimizer.pendingTaskCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.dodoInfo)
                            .frame(width: 8, height: 8)
                        Text("optimizer.pending \(dodoService.optimizer.pendingTaskCount)")
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)
                    }
                }

                if dodoService.optimizer.completedTaskCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.dodoSuccess)
                            .frame(width: 8, height: 8)
                        Text(String(localized: "optimizer.completed \(dodoService.optimizer.completedTaskCount)"))
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)
                    }
                }

                if dodoService.optimizer.failedTaskCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.dodoDanger)
                            .frame(width: 8, height: 8)
                        Text(String(localized: "optimizer.failed \(dodoService.optimizer.failedTaskCount)"))
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                if dodoService.optimizer.failedTaskCount > 0 {
                    Button {
                        Task {
                            await dodoService.optimizer.retryAllFailedTasks()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text(String(localized: "optimizer.retryFailed"))
                        }
                    }
                    .buttonStyle(.dodoSecondary)
                }

                Button {
                    showRunAllConfirmation = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text(String(localized: "optimizer.runAll"))
                    }
                }
                .buttonStyle(.dodoPrimary)
                .disabled(dodoService.optimizer.pendingTaskCount == 0)
            }
        }
        .padding(DodoTidyDimensions.cardPaddingLarge)
        .background(Color.dodoBackgroundSecondary)
    }
}

// MARK: - Optimization Task Card

struct OptimizationTaskCard: View {
    let task: OptimizationTask
    let onRun: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)

                if case .running = task.status {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: statusIcon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
            }

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.dodoSubheadline)
                    .foregroundColor(.dodoTextPrimary)

                Text(task.description)
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextSecondary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))

                    Text(task.benefit)
                        .font(.dodoCaptionSmall)
                }
                .foregroundColor(.dodoPrimary)
            }

            Spacer()

            // Action button or status
            actionView
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

    @ViewBuilder
    private var actionView: some View {
        switch task.status {
        case .pending:
            Button(action: onRun) {
                Text(String(localized: "optimizer.run"))
            }
            .buttonStyle(.dodoSecondary)

        case .running:
            Text(String(localized: "optimizer.running"))
                .font(.dodoCaption)
                .foregroundColor(.dodoTextSecondary)

        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(String(localized: "optimizer.done"))
            }
            .font(.dodoCaption)
            .foregroundColor(.dodoSuccess)

        case .failed(let error):
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(String(localized: "optimizer.failedStatus"))
                    }
                    .font(.dodoCaption)
                    .foregroundColor(.dodoDanger)

                    Text(error)
                        .font(.dodoCaptionSmall)
                        .foregroundColor(.dodoTextTertiary)
                        .lineLimit(1)
                        .frame(maxWidth: 120)
                }

                Button(action: onRun) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text(String(localized: "optimizer.retry"))
                    }
                }
                .buttonStyle(.dodoSecondary)
            }
        }
    }

    private var statusIcon: String {
        switch task.status {
        case .pending: return task.icon
        case .running: return task.icon
        case .completed: return "checkmark"
        case .failed: return "xmark"
        }
    }

    private var iconColor: Color {
        switch task.status {
        case .pending: return .dodoPrimary
        case .running: return .dodoPrimary
        case .completed: return .dodoSuccess
        case .failed: return .dodoDanger
        }
    }

    private var iconBackgroundColor: Color {
        switch task.status {
        case .pending: return Color.dodoPrimary.opacity(0.15)
        case .running: return Color.dodoPrimary.opacity(0.15)
        case .completed: return Color.dodoSuccess.opacity(0.15)
        case .failed: return Color.dodoDanger.opacity(0.15)
        }
    }
}
