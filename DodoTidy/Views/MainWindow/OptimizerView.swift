import SwiftUI

struct OptimizerView: View {
    @State private var dodoService = DodoTidyService.shared

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
        .navigationTitle("Optimizer")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await dodoService.optimizer.analyzeSystem()
                    }
                } label: {
                    Label("Reanalyze", systemImage: "arrow.clockwise")
                }
                .help("Reanalyze system for optimization tasks")
                .disabled(dodoService.optimizer.isAnalyzing)
            }

            ToolbarItem(placement: .automatic) {
                if !dodoService.optimizer.tasks.isEmpty {
                    Button {
                        Task {
                            await dodoService.optimizer.runAllTasks()
                        }
                    } label: {
                        Label("Run all", systemImage: "play.fill")
                    }
                    .help("Run all pending optimization tasks")
                    .disabled(dodoService.optimizer.pendingTaskCount == 0)
                }
            }
        }
        .task {
            if dodoService.optimizer.tasks.isEmpty {
                await dodoService.optimizer.analyzeSystem()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing system...")
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.dodoDanger)

            Text("Analysis failed")
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
                Text("Try again")
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

            Text("System is optimized")
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            Text("No optimization tasks needed")
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)

            Button {
                Task {
                    await dodoService.optimizer.analyzeSystem()
                }
            } label: {
                Text("Check again")
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
                            Task {
                                await dodoService.optimizer.runTask(task.id)
                            }
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
                        Text("\(dodoService.optimizer.pendingTaskCount) pending")
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)
                    }
                }

                if dodoService.optimizer.completedTaskCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.dodoSuccess)
                            .frame(width: 8, height: 8)
                        Text("\(dodoService.optimizer.completedTaskCount) completed")
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)
                    }
                }

                if dodoService.optimizer.failedTaskCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.dodoDanger)
                            .frame(width: 8, height: 8)
                        Text("\(dodoService.optimizer.failedTaskCount) failed")
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
                            Text("Retry failed")
                        }
                    }
                    .buttonStyle(.dodoSecondary)
                }

                Button {
                    Task {
                        await dodoService.optimizer.runAllTasks()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text("Run all")
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
                        .font(.system(size: 10))

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
                Text("Run")
            }
            .buttonStyle(.dodoSecondary)

        case .running:
            Text("Running...")
                .font(.dodoCaption)
                .foregroundColor(.dodoTextSecondary)

        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Done")
            }
            .font(.dodoCaption)
            .foregroundColor(.dodoSuccess)

        case .failed(let error):
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("Failed")
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
                        Text("Retry")
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
