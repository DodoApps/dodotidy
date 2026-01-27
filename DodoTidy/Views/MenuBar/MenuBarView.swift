import SwiftUI

struct MenuBarView: View {
    @State private var dodoService = DodoTidyService.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header with health score
            healthHeader

            Divider()
                .background(Color.dodoBorder.opacity(0.3))

            // System metrics
            metricsSection

            Divider()
                .background(Color.dodoBorder.opacity(0.3))

            // Battery & Network row
            statusRow

            Divider()
                .background(Color.dodoBorder.opacity(0.3))

            // Quick actions
            quickActionsSection

            Divider()
                .background(Color.dodoBorder.opacity(0.3))

            // Footer actions
            footerSection
        }
        .frame(width: 320)
        .background(Color.dodoBackground)
        .task {
            await dodoService.startMonitoring()
        }
    }

    // MARK: - Health Header

    private var healthHeader: some View {
        HStack(spacing: 12) {
            // Health score ring
            ZStack {
                Circle()
                    .stroke(Color.dodoBackgroundTertiary, lineWidth: 6)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: CGFloat(healthScore) / 100)
                    .stroke(healthScoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: healthScore)

                Text("\(healthScore)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.dodoTextPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("System health")
                    .font(.dodoSubheadline)
                    .foregroundColor(.dodoTextPrimary)

                Text(healthMessage)
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextSecondary)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        VStack(spacing: 12) {
            MetricRow(
                icon: "cpu",
                label: "CPU",
                value: cpuUsage.formattedPercentInt,
                progress: cpuUsage / 100,
                color: colorForUsage(cpuUsage)
            )

            MetricRow(
                icon: "memorychip",
                label: "Memory",
                value: memoryUsage.formattedPercentInt,
                progress: memoryUsage / 100,
                color: colorForUsage(memoryUsage)
            )

            MetricRow(
                icon: "internaldrive",
                label: "Disk",
                value: diskUsage.formattedPercentInt,
                progress: diskUsage / 100,
                color: colorForUsage(diskUsage),
                warning: diskUsage > 85
            )
        }
        .padding(16)
    }

    // MARK: - Status Row (Battery & Network)

    private var statusRow: some View {
        HStack(spacing: 16) {
            // Battery status
            if let battery = dodoService.status.metrics?.batteries.first {
                HStack(spacing: 6) {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 14))
                        .foregroundColor(batteryColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(Int(battery.percent))%")
                            .font(.dodoCaptionSmall)
                            .foregroundColor(.dodoTextPrimary)
                            .monospacedDigit()

                        Text(battery.status == "Charging" ? "Charging" : battery.timeLeft)
                            .font(.system(size: 11))
                            .foregroundColor(.dodoTextTertiary)
                    }
                }
            }

            Spacer()

            // Thermal status
            if let thermal = dodoService.status.metrics?.thermal {
                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 14))
                        .foregroundColor(thermalColor(thermal.cpuTemp))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(Int(thermal.cpuTemp))°C")
                            .font(.dodoCaptionSmall)
                            .foregroundColor(.dodoTextPrimary)
                            .monospacedDigit()

                        Text("CPU")
                            .font(.system(size: 11))
                            .foregroundColor(.dodoTextTertiary)
                    }
                }
            }

            Spacer()

            // Network status
            if let networks = dodoService.status.metrics?.network, let activeNetwork = networks.first {
                HStack(spacing: 6) {
                    Image(systemName: activeNetwork.name.contains("en") ? "wifi" : "network")
                        .font(.system(size: 14))
                        .foregroundColor(.dodoInfo)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10))
                            Text(String(format: "%.1f", activeNetwork.rxRateMBs))
                                .font(.dodoCaptionSmall)
                                .monospacedDigit()
                        }
                        .foregroundColor(.dodoTextPrimary)

                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10))
                            Text(String(format: "%.1f", activeNetwork.txRateMBs))
                                .font(.system(size: 11))
                                .monospacedDigit()
                        }
                        .foregroundColor(.dodoTextTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Quick Actions

    @State private var isQuickCleaning = false
    @State private var quickCleanResult: String?

    private var quickActionsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: isQuickCleaning ? "hourglass" : "trash",
                    title: isQuickCleaning ? "Cleaning..." : "Quick clean",
                    isLoading: isQuickCleaning,
                    action: {
                        Task {
                            await performQuickClean()
                        }
                    }
                )
                .disabled(isQuickCleaning)

                QuickActionButton(
                    icon: "chart.pie",
                    title: "Analyze",
                    action: {
                        Task {
                            await dodoService.analyzer.scanHome()
                        }
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                        NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.analyzer)
                    }
                )
            }

            // Show result if available
            if let result = quickCleanResult {
                Text(result)
                    .font(.dodoCaptionSmall)
                    .foregroundColor(.dodoSuccess)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .animation(.easeInOut(duration: 0.2), value: quickCleanResult)
    }

    private func performQuickClean() async {
        isQuickCleaning = true
        quickCleanResult = nil

        // Scan and auto-select safe items
        await dodoService.cleaner.scanForCleanableItems()

        // Auto-select only cache items (safe to delete)
        for category in dodoService.cleaner.categories {
            if category.name.lowercased().contains("cache") {
                dodoService.cleaner.selectAll(categoryId: category.id)
            }
        }

        // Perform the clean
        let sizeBeforeClean = dodoService.cleaner.totalSelectedSize
        if sizeBeforeClean > 0 {
            await dodoService.cleaner.cleanSelectedItems()
            let cleaned = dodoService.cleaner.lastCleanedSize
            quickCleanResult = "Freed \(cleaned.formattedBytes)"
        } else {
            quickCleanResult = "System is clean"
        }

        isQuickCleaning = false

        // Clear result after 3 seconds
        try? await Task.sleep(for: .seconds(3))
        quickCleanResult = nil
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open DodoTidy")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.dodoTextPrimary)

            Divider()
                .background(Color.dodoBorder.opacity(0.3))

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.dodoTextSecondary)
        }
    }

    // MARK: - Computed Properties

    private var healthScore: Int {
        dodoService.status.metrics?.healthScore ?? 0
    }

    private var healthMessage: String {
        dodoService.status.metrics?.healthScoreMsg ?? "Loading..."
    }

    private var healthScoreColor: Color {
        if healthScore >= 80 { return .dodoSuccess }
        if healthScore >= 60 { return .dodoWarning }
        return .dodoDanger
    }

    private var cpuUsage: Double {
        dodoService.status.metrics?.cpu.usage ?? 0
    }

    private var memoryUsage: Double {
        dodoService.status.metrics?.memory.usedPercent ?? 0
    }

    private var diskUsage: Double {
        dodoService.status.metrics?.disks.first?.usedPercent ?? 0
    }

    private func colorForUsage(_ usage: Double) -> Color {
        if usage < 60 { return .dodoSuccess }
        if usage < 85 { return .dodoWarning }
        return .dodoDanger
    }

    // Battery helpers
    private var batteryIcon: String {
        guard let battery = dodoService.status.metrics?.batteries.first else { return "battery.0" }
        let percent = battery.percent
        if battery.status == "Charging" {
            return "battery.100.bolt"
        }
        if percent >= 75 { return "battery.100" }
        if percent >= 50 { return "battery.75" }
        if percent >= 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        guard let battery = dodoService.status.metrics?.batteries.first else { return .dodoTextTertiary }
        if battery.status == "Charging" { return .dodoSuccess }
        if battery.percent >= 50 { return .dodoSuccess }
        if battery.percent >= 20 { return .dodoWarning }
        return .dodoDanger
    }

    private func thermalColor(_ temp: Double) -> Color {
        if temp < 50 { return .dodoSuccess }
        if temp < 70 { return .dodoInfo }
        if temp < 85 { return .dodoWarning }
        return .dodoDanger
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let progress: Double
    let color: Color
    var warning: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.dodoTextSecondary)
                .frame(width: 20)

            Text(label)
                .font(.dodoBody)
                .foregroundColor(.dodoTextSecondary)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.dodoBackgroundTertiary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * min(max(progress, 0), 1))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)

            HStack(spacing: 4) {
                Text(value)
                    .font(.dodoCaptionSmall)
                    .foregroundColor(.dodoTextPrimary)
                    .monospacedDigit()

                if warning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.dodoWarning)
                }
            }
            .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.dodoPrimary)
                }

                Text(title)
                    .font(.dodoCaption)
                    .foregroundColor(.dodoTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadiusMedium)
                    .fill(isHovering ? Color.dodoBackgroundTertiary : Color.dodoBackgroundSecondary)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    MenuBarView()
        .frame(width: 320, height: 400)
}
