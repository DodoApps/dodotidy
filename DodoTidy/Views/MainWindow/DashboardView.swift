import SwiftUI

struct DashboardView: View {
    @State private var dodoService = DodoTidyService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: DodoTidyDimensions.spacing) {
                // Metric cards
                metricsSection

                // Battery & Thermal
                batteryThermalSection

                // Bluetooth devices
                bluetoothSection

                // Quick actions
                quickActionsSection

                // System info
                systemInfoSection
            }
            .padding(DodoTidyDimensions.cardPaddingLarge)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await dodoService.status.fetchMetrics()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh system metrics")
            }

            ToolbarItem(placement: .automatic) {
                if let metrics = dodoService.status.metrics {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.dodoTextTertiary)
                        Text(metrics.uptime)
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        // Always use 2x2 grid: CPU, Memory, Disk, Battery (or thermal if no battery)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DodoTidyDimensions.spacing) {
            MetricCard(
                title: "CPU",
                value: cpuUsage.formattedPercentInt,
                icon: "cpu",
                progress: cpuUsage / 100,
                color: colorForUsage(cpuUsage),
                subtitle: "\(coreCount) cores"
            )

            MetricCard(
                title: "Memory",
                value: memoryUsage.formattedPercentInt,
                icon: "memorychip",
                progress: memoryUsage / 100,
                color: colorForUsage(memoryUsage),
                subtitle: memoryDetail
            )

            MetricCard(
                title: "Disk",
                value: diskUsage.formattedPercentInt,
                icon: "internaldrive",
                progress: diskUsage / 100,
                color: colorForUsage(diskUsage),
                subtitle: diskDetail
            )

            // Battery card next to disk (or placeholder if no battery)
            if hasBatteryData, let battery = dodoService.status.metrics?.batteries.first {
                MetricCard(
                    title: "Battery",
                    value: "\(Int(battery.percent))%",
                    icon: batteryIcon,
                    progress: battery.percent / 100,
                    color: batteryColor,
                    subtitle: battery.status
                )
            } else if hasThermalData, let thermal = dodoService.status.metrics?.thermal {
                MetricCard(
                    title: "Thermal",
                    value: thermal.cpuTemp > 0 ? String(format: "%.0f°C", thermal.cpuTemp) : "—",
                    icon: "thermometer.medium",
                    progress: thermal.cpuTemp > 0 ? min(thermal.cpuTemp / 100, 1.0) : 0,
                    color: thermalColor(thermal.cpuTemp),
                    subtitle: thermalStatusMessage(thermal.cpuTemp)
                )
            } else {
                // Placeholder card for consistent grid
                MetricCard(
                    title: "System",
                    value: "OK",
                    icon: "checkmark.circle",
                    progress: 0,
                    color: .dodoSuccess,
                    subtitle: dodoService.status.metrics?.host ?? "Mac"
                )
            }
        }
    }

    // MARK: - Battery & Thermal Section

    /// Check if we have meaningful thermal data
    private var hasThermalData: Bool {
        guard let thermal = dodoService.status.metrics?.thermal else { return false }
        // Only show thermal card if we have actual temperature readings
        return thermal.cpuTemp > 0 || thermal.gpuTemp > 0 || thermal.systemPower > 0
    }

    /// Check if we have battery data
    private var hasBatteryData: Bool {
        dodoService.status.metrics?.batteries.first != nil
    }

    @ViewBuilder
    private var batteryThermalSection: some View {
        // Battery is now in the metrics grid, so only show detailed cards when both exist
        // or show detailed thermal card when battery exists (battery details are still useful)
        if hasBatteryData && hasThermalData {
            // Both available - show detailed battery and thermal side by side
            HStack(alignment: .top, spacing: DodoTidyDimensions.spacing) {
                batteryDetailCard
                    .frame(maxWidth: .infinity)
                thermalCard
                    .frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else if hasBatteryData {
            // Only battery - show detailed battery card
            batteryDetailCard
        } else if hasThermalData {
            // Only thermal - already shown in grid, but show detailed view
            thermalCard
        }
        // If neither, show nothing
    }

    private var batteryDetailCard: some View {
        Group {
            if let battery = dodoService.status.metrics?.batteries.first {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: batteryIcon)
                            .font(.system(size: 16))
                            .foregroundColor(batteryColor)

                        Text("Battery")
                            .font(.dodoSubheadline)
                            .foregroundColor(.dodoTextSecondary)

                        Spacer()

                        Text(battery.status)
                            .font(.dodoCaption)
                            .foregroundColor(battery.status == "Charging" ? .dodoSuccess : .dodoTextTertiary)
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        Text("\(Int(battery.percent))%")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.dodoTextPrimary)
                            .monospacedDigit()

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if !battery.timeLeft.isEmpty {
                                Text(battery.timeLeft)
                                    .font(.dodoCaption)
                                    .foregroundColor(.dodoTextSecondary)
                            }

                            Text("\(battery.cycleCount) cycles")
                                .font(.dodoCaption)
                                .foregroundColor(.dodoTextTertiary)
                        }
                    }

                    // Battery bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.dodoBackgroundTertiary)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(batteryColor)
                                .frame(width: geometry.size.width * CGFloat(battery.percent / 100), height: 8)
                                .animation(.easeInOut(duration: 0.3), value: battery.percent)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("Health: \(battery.health)")
                            .font(.dodoCaption)
                            .foregroundColor(battery.health == "Good" ? .dodoSuccess : .dodoWarning)

                        Spacer()

                        Text("Capacity: \(battery.capacity)%")
                            .font(.dodoCaption)
                            .foregroundColor(.dodoTextTertiary)
                    }
                }
                .cardStyle()
            }
        }
    }

    private var thermalCard: some View {
        Group {
            if let thermal = dodoService.status.metrics?.thermal, hasThermalData {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 16))
                            .foregroundColor(thermalColor(thermal.cpuTemp))

                        Text("Thermal")
                            .font(.dodoSubheadline)
                            .foregroundColor(.dodoTextSecondary)

                        Spacer()

                        if thermal.fanCount > 0 && thermal.fanSpeed > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "fan")
                                    .font(.system(size: 12))
                                Text("\(thermal.fanSpeed) RPM")
                                    .font(.dodoCaption)
                            }
                            .foregroundColor(.dodoTextTertiary)
                        }
                    }

                    HStack(spacing: DodoTidyDimensions.spacing) {
                        if thermal.cpuTemp > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CPU")
                                    .font(.dodoCaption)
                                    .foregroundColor(.dodoTextTertiary)

                                HStack(alignment: .bottom, spacing: 2) {
                                    Text(String(format: "%.0f", thermal.cpuTemp))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.dodoTextPrimary)
                                        .monospacedDigit()

                                    Text("°C")
                                        .font(.dodoCaption)
                                        .foregroundColor(.dodoTextSecondary)
                                        .padding(.bottom, 4)
                                }
                            }

                            Spacer()
                        }

                        if thermal.gpuTemp > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("GPU")
                                    .font(.dodoCaption)
                                    .foregroundColor(.dodoTextTertiary)

                                HStack(alignment: .bottom, spacing: 2) {
                                    Text(String(format: "%.0f", thermal.gpuTemp))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.dodoTextPrimary)
                                        .monospacedDigit()

                                    Text("°C")
                                        .font(.dodoCaption)
                                        .foregroundColor(.dodoTextSecondary)
                                        .padding(.bottom, 4)
                                }
                            }

                            Spacer()
                        }

                        if thermal.systemPower > 0 {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Power")
                                    .font(.dodoCaption)
                                    .foregroundColor(.dodoTextTertiary)

                                HStack(alignment: .bottom, spacing: 2) {
                                    Text(String(format: "%.1f", thermal.systemPower))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.dodoTextPrimary)
                                        .monospacedDigit()

                                    Text("W")
                                        .font(.dodoCaption)
                                        .foregroundColor(.dodoTextSecondary)
                                        .padding(.bottom, 4)
                                }
                            }
                        }
                    }

                    // Thermal bar (CPU temp as percentage of max safe temp ~100°C)
                    if thermal.cpuTemp > 0 {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.dodoBackgroundTertiary)
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(thermalColor(thermal.cpuTemp))
                                    .frame(width: geometry.size.width * CGFloat(min(thermal.cpuTemp / 100, 1.0)), height: 8)
                                    .animation(.easeInOut(duration: 0.3), value: thermal.cpuTemp)
                            }
                        }
                        .frame(height: 8)

                        Text(thermalStatusMessage(thermal.cpuTemp))
                            .font(.dodoCaption)
                            .foregroundColor(thermalColor(thermal.cpuTemp))
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick actions")
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            HStack(spacing: DodoTidyDimensions.spacing) {
                QuickActionCard(
                    icon: "trash",
                    title: "Smart clean",
                    subtitle: "Free up space",
                    color: .dodoPrimary
                ) {
                    NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.cleaner)
                }

                QuickActionCard(
                    icon: "bolt",
                    title: "Optimize",
                    subtitle: "Improve performance",
                    color: .dodoInfo
                ) {
                    NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.optimizer)
                }

                QuickActionCard(
                    icon: "chart.pie",
                    title: "Analyze disk",
                    subtitle: "View storage usage",
                    color: .dodoWarning
                ) {
                    NotificationCenter.default.post(name: .navigateTo, object: NavigationItem.analyzer)
                }
            }
        }
    }

    // MARK: - System Info Section

    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System information")
                .font(.dodoHeadline)
                .foregroundColor(.dodoTextPrimary)

            if let metrics = dodoService.status.metrics {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: DodoTidyDimensions.spacing) {
                    SystemInfoRow(label: "Model", value: metrics.hardware.model)
                    SystemInfoRow(label: "Processor", value: metrics.hardware.cpuModel)
                    SystemInfoRow(label: "Memory", value: metrics.hardware.totalRAM)
                    SystemInfoRow(label: "Storage", value: metrics.hardware.diskSize)
                    SystemInfoRow(label: "macOS", value: metrics.hardware.osVersion)
                    SystemInfoRow(label: "Hostname", value: metrics.host)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .cardStyle()
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

    private var coreCount: Int {
        dodoService.status.metrics?.cpu.coreCount ?? 0
    }

    private var memoryDetail: String {
        guard let memory = dodoService.status.metrics?.memory else { return "" }
        return "\(memory.used.formattedBytes) / \(memory.total.formattedBytes)"
    }

    private var diskDetail: String {
        guard let disk = dodoService.status.metrics?.disks.first else { return "" }
        return "\(disk.used.formattedBytes) / \(disk.total.formattedBytes)"
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

    // MARK: - Bluetooth Section

    private var hasBluetoothDevices: Bool {
        guard let devices = dodoService.status.metrics?.bluetooth else { return false }
        return !devices.isEmpty
    }

    @ViewBuilder
    private var bluetoothSection: some View {
        if hasBluetoothDevices, let devices = dodoService.status.metrics?.bluetooth {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(.dodoInfo)

                    Text("Bluetooth devices")
                        .font(.dodoSubheadline)
                        .foregroundColor(.dodoTextSecondary)

                    Spacer()

                    Text("\(devices.count) connected")
                        .font(.dodoCaption)
                        .foregroundColor(.dodoTextTertiary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(devices, id: \.name) { device in
                        HStack(spacing: 10) {
                            Image(systemName: bluetoothDeviceIcon(for: device.name))
                                .font(.system(size: 20))
                                .foregroundColor(.dodoInfo)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .font(.dodoSubheadline)
                                    .foregroundColor(.dodoTextPrimary)
                                    .lineLimit(1)

                                if device.battery != "N/A" {
                                    HStack(spacing: 4) {
                                        Image(systemName: batteryIconForLevel(device.battery))
                                            .font(.system(size: 11))
                                            .foregroundColor(batteryColorForLevel(device.battery))
                                        Text(device.battery)
                                            .font(.dodoCaptionSmall)
                                            .foregroundColor(.dodoTextTertiary)
                                    }
                                } else {
                                    Text("Connected")
                                        .font(.dodoCaptionSmall)
                                        .foregroundColor(.dodoSuccess)
                                }
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(Color.dodoBackgroundTertiary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadius))
                    }
                }
            }
            .cardStyle()
        }
    }

    private func bluetoothDeviceIcon(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("airpods") { return "airpodspro" }
        if lowercased.contains("headphone") || lowercased.contains("beats") { return "headphones" }
        if lowercased.contains("keyboard") { return "keyboard" }
        if lowercased.contains("mouse") || lowercased.contains("trackpad") { return "computermouse" }
        if lowercased.contains("watch") { return "applewatch" }
        if lowercased.contains("iphone") || lowercased.contains("phone") { return "iphone" }
        if lowercased.contains("ipad") { return "ipad" }
        if lowercased.contains("speaker") || lowercased.contains("homepod") { return "hifispeaker" }
        return "dot.radiowaves.left.and.right"
    }

    private func batteryIconForLevel(_ level: String) -> String {
        guard let percent = Int(level.replacingOccurrences(of: "%", with: "")) else {
            return "battery.100"
        }
        if percent >= 75 { return "battery.100" }
        if percent >= 50 { return "battery.75" }
        if percent >= 25 { return "battery.50" }
        return "battery.25"
    }

    private func batteryColorForLevel(_ level: String) -> Color {
        guard let percent = Int(level.replacingOccurrences(of: "%", with: "")) else {
            return .dodoTextTertiary
        }
        if percent >= 50 { return .dodoSuccess }
        if percent >= 20 { return .dodoWarning }
        return .dodoDanger
    }

    // Thermal helpers
    private func thermalColor(_ temp: Double) -> Color {
        if temp < 50 { return .dodoSuccess }
        if temp < 70 { return .dodoInfo }
        if temp < 85 { return .dodoWarning }
        return .dodoDanger
    }

    private func thermalStatusMessage(_ temp: Double) -> String {
        if temp < 50 { return "Running cool" }
        if temp < 70 { return "Normal operating temperature" }
        if temp < 85 { return "Running warm" }
        return "Running hot - consider reducing workload"
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let progress: Double
    let color: Color
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)

                Text(title)
                    .font(.dodoSubheadline)
                    .foregroundColor(.dodoTextSecondary)

                Spacer()
            }

            HStack(alignment: .bottom, spacing: 8) {
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.dodoTextPrimary)
                    .monospacedDigit()

                Spacer()

                // Mini progress ring
                ZStack {
                    Circle()
                        .stroke(Color.dodoBackgroundTertiary, lineWidth: 4)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: min(max(progress, 0), 1))
                        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }

            Text(subtitle)
                .font(.dodoCaption)
                .foregroundColor(.dodoTextTertiary)
                .lineLimit(1)
        }
        .cardStyle()
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.dodoSubheadline)
                        .foregroundColor(.dodoTextPrimary)

                    Text(subtitle)
                        .font(.dodoCaption)
                        .foregroundColor(.dodoTextTertiary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DodoTidyDimensions.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadiusMedium)
                    .fill(isHovering ? Color.dodoBackgroundTertiary : Color.dodoBackgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DodoTidyDimensions.borderRadiusMedium)
                    .stroke(Color.dodoBorder.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct SystemInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.dodoCaption)
                .foregroundColor(.dodoTextTertiary)

            Spacer()

            Text(value)
                .font(.dodoBody)
                .foregroundColor(.dodoTextPrimary)
        }
        .padding(.vertical, 4)
    }
}
