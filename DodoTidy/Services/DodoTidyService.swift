import Foundation
import Observation
import IOKit.ps
import UserNotifications

// MARK: - DodoTidy Service (Main Coordinator)

@Observable
final class DodoTidyService {
    static let shared = DodoTidyService()

    let status = StatusProvider()
    let analyzer = AnalyzerProvider()
    let cleaner = CleanerProvider()
    let optimizer = OptimizerProvider()

    private init() {}

    /// Start periodic status updates
    func startMonitoring() async {
        await status.startPolling()
    }

    /// Stop periodic status updates
    func stopMonitoring() {
        status.stopPolling()
    }
}

// MARK: - Status Provider

@Observable
final class StatusProvider {
    private(set) var metrics: MetricsSnapshot?
    private(set) var isLoading = false
    private(set) var error: Error?

    private var pollingTask: Task<Void, Never>?
    private var hasShownLowDiskAlert = false
    private var lastAlertDate: Date?

    // For CPU delta calculation
    private var previousCPUTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []

    /// Fetch metrics using native macOS APIs
    func fetchMetrics() async {
        isLoading = true
        error = nil

        // Use native macOS APIs
        metrics = await collectNativeMetrics()
        checkLowDiskSpace()
        isLoading = false
    }

    /// Check if disk space is low and show notification if needed
    private func checkLowDiskSpace() {
        guard AppSettings.shared.showNotifications,
              AppSettings.shared.notifyOnLowDiskSpace,
              let disk = metrics?.disks.first else {
            return
        }

        let freeBytes = disk.total - disk.used
        let freeGB = freeBytes / 1_000_000_000
        let threshold = UInt64(AppSettings.shared.lowDiskSpaceThreshold)

        // Only alert if below threshold
        guard freeGB < threshold else {
            // Reset alert flag when disk space is restored
            hasShownLowDiskAlert = false
            return
        }

        // Don't spam alerts - only show once per hour
        if let lastAlert = lastAlertDate, Date().timeIntervalSince(lastAlert) < 3600 {
            return
        }

        // Don't show if we've already alerted for this session
        if hasShownLowDiskAlert {
            return
        }

        hasShownLowDiskAlert = true
        lastAlertDate = Date()
        showLowDiskSpaceNotification(freeGB: freeGB)
    }

    /// Show a system notification for low disk space
    private func showLowDiskSpaceNotification(freeGB: UInt64) {
        let content = UNMutableNotificationContent()
        content.title = "Low disk space"
        content.body = "Only \(freeGB) GB remaining on your main disk. Consider cleaning up to free space."
        content.sound = .default
        content.categoryIdentifier = "LOW_DISK_SPACE"

        let request = UNNotificationRequest(
            identifier: "low-disk-space-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show low disk space notification: \(error.localizedDescription)")
            }
        }
    }

    /// Collect metrics using native macOS APIs
    private func collectNativeMetrics() async -> MetricsSnapshot {
        // Get host info
        let hostName = Host.current().localizedName ?? "Mac"
        let processInfo = ProcessInfo.processInfo

        // Get uptime
        let uptime = processInfo.systemUptime
        let uptimeString = formatUptime(uptime)

        // Get CPU usage
        let cpuUsage = getCPUUsage()

        // Get memory info
        let memoryInfo = getMemoryInfo()

        // Get disk info
        let diskInfo = getDiskInfo()

        // Get battery info
        let batteryInfo = getBatteryInfo()

        // Get Bluetooth devices
        let bluetoothDevices = getBluetoothDevices()

        // Calculate health score
        let healthScore = calculateHealthScore(
            cpuUsage: cpuUsage,
            memoryPercent: memoryInfo.usedPercent,
            diskPercent: diskInfo.first?.usedPercent ?? 0
        )

        // Get OS version
        let osVersion = processInfo.operatingSystemVersionString

        return MetricsSnapshot(
            collectedAt: Date(),
            host: hostName,
            platform: "macOS",
            uptime: uptimeString,
            procs: UInt64(processInfo.activeProcessorCount),
            hardware: HardwareInfo(
                model: getMacModel(),
                cpuModel: getCPUModel(),
                totalRAM: formatBytes(Int64(processInfo.physicalMemory)),
                diskSize: formatBytes(Int64(diskInfo.first?.total ?? 0)),
                osVersion: osVersion,
                refreshRate: "60 Hz"
            ),
            healthScore: healthScore,
            healthScoreMsg: healthScoreMessage(healthScore),
            cpu: CPUStatus(
                usage: cpuUsage,
                perCore: [],
                perCoreEstimated: true,
                load1: 0,
                load5: 0,
                load15: 0,
                coreCount: processInfo.processorCount,
                logicalCPU: processInfo.activeProcessorCount,
                pCoreCount: processInfo.processorCount,
                eCoreCount: 0
            ),
            gpu: [],
            memory: memoryInfo,
            disks: diskInfo,
            diskIO: DiskIOStatus(readRate: 0, writeRate: 0),
            network: nil,
            networkHistory: NetworkHistory(rxHistory: nil, txHistory: nil),
            proxy: ProxyStatus(enabled: false, type: "", host: ""),
            batteries: batteryInfo,
            thermal: ThermalStatus(
                cpuTemp: 0,
                gpuTemp: 0,
                fanSpeed: 0,
                fanCount: 0,
                systemPower: 0,
                adapterPower: 0,
                batteryPower: 0
            ),
            sensors: nil,
            bluetooth: bluetoothDevices.isEmpty ? nil : bluetoothDevices,
            topProcesses: nil
        )
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0

        let err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &cpuInfo, &numCpuInfo)

        if err == KERN_SUCCESS, let cpuInfo = cpuInfo {
            let cpuLoadInfo = UnsafeMutablePointer<processor_cpu_load_info>(OpaquePointer(cpuInfo))

            // Collect current ticks
            var currentTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []
            for i in 0..<Int(numCpus) {
                let cpu = cpuLoadInfo[i]
                currentTicks.append((
                    user: UInt64(cpu.cpu_ticks.0),
                    system: UInt64(cpu.cpu_ticks.1),
                    idle: UInt64(cpu.cpu_ticks.2),
                    nice: UInt64(cpu.cpu_ticks.3)
                ))
            }

            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride))

            // If we have previous ticks, calculate delta-based usage
            if previousCPUTicks.count == currentTicks.count && !previousCPUTicks.isEmpty {
                var totalUsage: Double = 0

                for i in 0..<currentTicks.count {
                    let prev = previousCPUTicks[i]
                    let curr = currentTicks[i]

                    let userDelta = curr.user - prev.user
                    let systemDelta = curr.system - prev.system
                    let idleDelta = curr.idle - prev.idle
                    let niceDelta = curr.nice - prev.nice

                    let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
                    if totalDelta > 0 {
                        let usedDelta = userDelta + systemDelta + niceDelta
                        totalUsage += Double(usedDelta) / Double(totalDelta)
                    }
                }

                previousCPUTicks = currentTicks
                return (totalUsage / Double(currentTicks.count)) * 100
            }

            // First sample - store ticks and return 0
            previousCPUTicks = currentTicks
            return 0
        }

        return 0
    }

    private func getMemoryInfo() -> MemoryStatus {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let totalMemory = UInt64(ProcessInfo.processInfo.physicalMemory)

        if result == KERN_SUCCESS {
            let active = UInt64(stats.active_count) * pageSize
            let inactive = UInt64(stats.inactive_count) * pageSize
            let wired = UInt64(stats.wire_count) * pageSize
            let compressed = UInt64(stats.compressor_page_count) * pageSize

            let used = active + wired + compressed
            let usedPercent = Double(used) / Double(totalMemory) * 100

            return MemoryStatus(
                used: used,
                total: totalMemory,
                usedPercent: usedPercent,
                swapUsed: 0,
                swapTotal: 0,
                cached: inactive,
                pressure: usedPercent > 80 ? "High" : (usedPercent > 60 ? "Medium" : "Normal")
            )
        }

        return MemoryStatus(used: 0, total: totalMemory, usedPercent: 0, swapUsed: 0, swapTotal: 0, cached: 0, pressure: "Unknown")
    }

    private func getDiskInfo() -> [DiskStatus] {
        let fileManager = FileManager.default
        var disks: [DiskStatus] = []

        do {
            let homeURL = fileManager.homeDirectoryForCurrentUser
            let values = try homeURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])

            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                let used = UInt64(total - available)
                let totalBytes = UInt64(total)
                let usedPercent = Double(used) / Double(totalBytes) * 100

                disks.append(DiskStatus(
                    mount: "/",
                    device: "disk1s1",
                    used: used,
                    total: totalBytes,
                    usedPercent: usedPercent,
                    fstype: "apfs",
                    external: false
                ))
            }
        } catch {
            // Fallback with zero values
        }

        return disks
    }

    private func getBatteryInfo() -> [BatteryStatus] {
        // Use IOKit to get battery info
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        var batteries: [BatteryStatus] = []

        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                let percent = info[kIOPSCurrentCapacityKey] as? Double ?? 0
                let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
                let isPluggedIn = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue

                var status = "Discharging"
                if isCharging {
                    status = "Charging"
                } else if isPluggedIn {
                    status = "Plugged in"
                }

                batteries.append(BatteryStatus(
                    percent: percent,
                    status: status,
                    timeLeft: "",
                    health: "Good",
                    cycleCount: 0,
                    capacity: Int(percent)
                ))
            }
        }

        return batteries
    }

    private func getBluetoothDevices() -> [BluetoothDevice] {
        // Use system_profiler to get Bluetooth device information
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            // Parse the JSON output
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let btData = json["SPBluetoothDataType"] as? [[String: Any]],
               let firstEntry = btData.first,
               let connectedDevices = firstEntry["device_connected"] as? [[String: Any]] {

                return connectedDevices.compactMap { device -> BluetoothDevice? in
                    // Device info is nested under the device name key
                    guard let deviceName = device.keys.first,
                          let deviceInfo = device[deviceName] as? [String: Any] else {
                        return nil
                    }

                    let batteryLevel = deviceInfo["device_batteryLevelMain"] as? String ?? "N/A"

                    return BluetoothDevice(
                        name: deviceName,
                        connected: true,
                        battery: batteryLevel
                    )
                }
            }
        } catch {
            // Silently fail - Bluetooth info is optional
        }

        return []
    }

    private func getMacModel() -> String {
        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func getCPUModel() -> String {
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        return String(cString: brand)
    }

    private func calculateHealthScore(cpuUsage: Double, memoryPercent: Double, diskPercent: Double) -> Int {
        var score = 100

        // CPU penalty (high usage = bad)
        if cpuUsage > 80 { score -= 20 }
        else if cpuUsage > 60 { score -= 10 }
        else if cpuUsage > 40 { score -= 5 }

        // Memory penalty
        if memoryPercent > 90 { score -= 25 }
        else if memoryPercent > 80 { score -= 15 }
        else if memoryPercent > 70 { score -= 10 }

        // Disk penalty (most important)
        if diskPercent > 95 { score -= 30 }
        else if diskPercent > 90 { score -= 20 }
        else if diskPercent > 80 { score -= 10 }

        return max(0, min(100, score))
    }

    private func healthScoreMessage(_ score: Int) -> String {
        if score >= 90 { return "Excellent" }
        if score >= 80 { return "Good" }
        if score >= 70 { return "Fair" }
        if score >= 60 { return "Needs attention" }
        return "Critical"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Start polling for metrics using the configured refresh interval
    func startPolling() async {
        stopPolling()

        pollingTask = Task {
            while !Task.isCancelled {
                await fetchMetrics()
                let interval = AppSettings.shared.refreshInterval
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Stop polling
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}

// MARK: - Analyzer Provider

@Observable
final class AnalyzerProvider {
    private(set) var scanResult: ScanResult?
    private(set) var isScanning = false
    private(set) var error: Error?
    private(set) var currentPath: String = ""
    private(set) var scanProgress: Double = 0
    private(set) var currentScanItem: String = ""

    /// Scan a directory using native Swift implementation
    func scan(path: String) async {
        isScanning = true
        error = nil
        currentPath = path
        scanProgress = 0
        currentScanItem = ""

        let startTime = Date()

        // Use native Swift scanning
        let result = await performNativeScan(path: path)

        if let result = result {
            scanResult = result

            let duration = Date().timeIntervalSince(startTime)

            // Log success to history
            let operation = OperationRecord(
                type: .analysis,
                name: "Disk analysis",
                status: .success,
                details: "Scanned \(path)",
                itemsProcessed: Int(result.totalFiles),
                duration: duration
            )
            OperationHistoryManager.shared.addOperation(operation)
        } else {
            self.error = NSError(domain: "DodoTidyAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to scan directory"])

            // Log failure to history
            let operation = OperationRecord(
                type: .analysis,
                name: "Disk analysis",
                status: .failed,
                details: "Failed to scan \(path)",
                duration: Date().timeIntervalSince(startTime),
                errorMessage: "Could not access directory"
            )
            OperationHistoryManager.shared.addOperation(operation)
        }

        scanProgress = 1.0
        currentScanItem = ""
        isScanning = false
    }

    /// Perform native Swift directory scanning
    private func performNativeScan(path: String) async -> ScanResult? {
        let fileManager = FileManager.default
        var entries: [DirEntry] = []
        var largeFiles: [FileEntry] = []
        var totalSize: Int64 = 0
        var totalFiles: Int64 = 0

        // Get the minimum file size setting for large files (in MB, convert to bytes)
        let minLargeFileSize = Int64(AppSettings.shared.minFileSizeForLargeFiles) * 1_000_000
        let showHiddenFiles = AppSettings.shared.showHiddenFiles

        // Build directory size map for top-level entries
        var dirSizes: [String: Int64] = [:]

        // Get enumerator options based on settings
        var enumeratorOptions: FileManager.DirectoryEnumerationOptions = []
        if !showHiddenFiles {
            enumeratorOptions.insert(.skipsHiddenFiles)
        }

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isRegularFileKey, .contentAccessDateKey],
            options: enumeratorOptions
        ) else { return nil }

        var fileCount = 0
        let maxFiles = 100000 // Limit to prevent hanging on huge directories

        for case let fileURL as URL in enumerator {
            fileCount += 1

            // Update progress periodically
            if fileCount % 1000 == 0 {
                currentScanItem = fileURL.lastPathComponent
                // Estimate progress (assuming average directory has ~50k files)
                scanProgress = min(0.95, Double(fileCount) / 50000.0)
            }

            // Limit enumeration to prevent hanging
            if fileCount > maxFiles {
                break
            }

            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .isRegularFileKey, .contentAccessDateKey]) else {
                continue
            }

            let size = Int64(values.fileSize ?? 0)

            if values.isRegularFile == true {
                totalFiles += 1
                totalSize += size

                // Track large files
                if size > minLargeFileSize {
                    largeFiles.append(FileEntry(
                        name: fileURL.lastPathComponent,
                        path: fileURL.path,
                        size: size
                    ))
                }
            }

            // Accumulate size for parent directories
            var parent = fileURL.deletingLastPathComponent().path
            while parent.hasPrefix(path) && parent.count >= path.count {
                dirSizes[parent, default: 0] += size
                let newParent = (parent as NSString).deletingLastPathComponent
                if newParent == parent { break }
                parent = newParent
            }
        }

        // Get top-level entries
        if let contents = try? fileManager.contentsOfDirectory(atPath: path) {
            for item in contents {
                // Skip hidden files if setting is off
                if !showHiddenFiles && item.hasPrefix(".") {
                    continue
                }

                let itemPath = (path as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: itemPath, isDirectory: &isDir)

                let size = dirSizes[itemPath] ?? getFileSize(at: itemPath)
                let lastAccess = getLastAccessDate(at: itemPath)

                entries.append(DirEntry(
                    name: item,
                    path: itemPath,
                    size: size,
                    isDir: isDir.boolValue,
                    lastAccess: lastAccess
                ))
            }
        }

        // Sort by size descending
        entries.sort { $0.size > $1.size }
        largeFiles.sort { $0.size > $1.size }

        return ScanResult(
            path: path,
            totalSize: totalSize,
            totalFiles: totalFiles,
            entries: entries,
            largeFiles: Array(largeFiles.prefix(50)),
            scannedAt: Date()
        )
    }

    /// Get file size at path
    private func getFileSize(at path: String) -> Int64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
            return 0
        }
        return Int64(attrs[.size] as? UInt64 ?? 0)
    }

    /// Get last access date at path
    private func getLastAccessDate(at path: String) -> Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attrs[.modificationDate] as? Date
    }

    /// Scan home directory
    func scanHome() async {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        await scan(path: homePath)
    }

    /// Clear scan results
    func clearResults() {
        scanResult = nil
        error = nil
    }
}

// MARK: - Cleaner Provider

@Observable
final class CleanerProvider {
    private(set) var categories: [CleaningCategory] = []
    private(set) var isScanning = false
    private(set) var isCleaning = false
    private(set) var error: Error?
    private(set) var lastCleanedSize: Int64 = 0
    private(set) var scanProgress: Double = 0
    private(set) var currentScanItem: String = ""

    // Dry run mode - when enabled, shows what would be deleted without actually deleting
    var isDryRunMode = false
    private(set) var dryRunResults: [DryRunResult] = []

    // File age filter - only clean files older than this many days (0 = no filter)
    var minimumFileAgeDays: Int = 0

    // Safe paths that can be auto-cleaned (caches only - always regeneratable)
    private let safeAutoCleanPaths: [(category: String, icon: String, items: [(name: String, path: String)])] = [
        ("User caches", "folder.badge.gearshape", [
            ("Safari cache", "~/Library/Caches/com.apple.Safari"),
            ("Chrome cache", "~/Library/Caches/Google/Chrome"),
            ("Firefox cache", "~/Library/Caches/Firefox"),
            ("Xcode DerivedData", "~/Library/Developer/Xcode/DerivedData"),
        ]),
        ("Application caches", "app.badge", [
            ("Spotify cache", "~/Library/Caches/com.spotify.client"),
            ("Slack cache", "~/Library/Caches/com.tinyspeck.slackmacgap"),
            ("Discord cache", "~/Library/Caches/com.hnc.Discord"),
            ("VS Code cache", "~/Library/Caches/com.microsoft.VSCode"),
            ("Zoom cache", "~/Library/Caches/us.zoom.xos"),
            ("Teams cache", "~/Library/Caches/com.microsoft.teams"),
        ]),
    ]

    // Paths that require explicit user action (manual cleaning only, not for scheduled tasks)
    private let manualOnlyPaths: [(category: String, icon: String, items: [(name: String, path: String)], warning: String)] = [
        ("Downloads", "arrow.down.circle", [
            ("Old downloads", "~/Downloads"),
        ], "⚠️ Downloads may contain important files you haven't processed yet"),
        ("Trash", "trash", [
            ("Trash", "~/.Trash"),
        ], "⚠️ Emptying Trash is IRREVERSIBLE - files cannot be recovered"),
        ("System logs", "doc.text", [
            ("User logs", "~/Library/Logs"),
            ("Crash reports", "~/Library/Logs/DiagnosticReports"),
        ], "⚠️ Logs may be needed for troubleshooting recent issues"),
        ("Developer tools", "hammer", [
            ("npm cache", "~/.npm/_cacache"),
            ("Yarn cache", "~/Library/Caches/Yarn"),
            ("Homebrew cache", "~/Library/Caches/Homebrew"),
            ("pip cache", "~/Library/Caches/pip"),
            ("CocoaPods cache", "~/Library/Caches/CocoaPods"),
            ("Gradle cache", "~/.gradle/caches"),
            ("Maven cache", "~/.m2/repository"),
            ("Xcode Archives", "~/Library/Developer/Xcode/Archives"),
            ("Xcode iOS DeviceSupport", "~/Library/Developer/Xcode/iOS DeviceSupport"),
        ], "⚠️ Developer caches may require lengthy re-downloads to rebuild"),
    ]

    // Default protected paths that should never be cleaned
    static let defaultProtectedPaths: [String] = [
        "~/Documents",
        "~/Desktop",
        "~/Pictures",
        "~/Movies",
        "~/Music",
        "~/.ssh",
        "~/.gnupg",
        "~/.aws",
        "~/.kube",
        "~/Library/Keychains",
        "~/Library/Application Support/MobileSync", // iOS backups
    ]

    /// Scan for actual cleanable items on the system
    /// - Parameter forScheduledTask: If true, only scans safe auto-clean paths (no Downloads, Trash, etc.)
    func scanForCleanableItems(forScheduledTask: Bool = false) async {
        isScanning = true
        error = nil
        categories = []
        scanProgress = 0
        currentScanItem = ""

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let excludedPaths = AppSettings.shared.excludedPaths
        let protectedPaths = AppSettings.shared.protectedPaths

        // Combine all paths to scan based on context
        var pathsToScan: [(category: String, icon: String, items: [(name: String, path: String)], warning: String?)] = []

        // Always include safe auto-clean paths
        for (category, icon, items) in safeAutoCleanPaths {
            pathsToScan.append((category, icon, items, nil))
        }

        // Only include manual-only paths if not a scheduled task
        if !forScheduledTask {
            for (category, icon, items, warning) in manualOnlyPaths {
                pathsToScan.append((category, icon, items, warning))
            }
        }

        // Calculate total items for progress
        let totalItems = pathsToScan.reduce(0) { $0 + $1.items.count }
        var scannedItems = 0

        for (categoryName, icon, items, warning) in pathsToScan {
            var cleaningItems: [CleaningItem] = []

            for (name, path) in items {
                let expandedPath = path.replacingOccurrences(of: "~", with: homeDir)

                // Update progress
                currentScanItem = name
                scannedItems += 1
                scanProgress = Double(scannedItems) / Double(totalItems)

                // Skip if path is in excluded list
                if excludedPaths.contains(where: { expandedPath.hasPrefix($0) || $0.hasPrefix(expandedPath) }) {
                    continue
                }

                // Skip if path is in protected list
                let expandedProtectedPaths = protectedPaths.map { $0.replacingOccurrences(of: "~", with: homeDir) }
                if expandedProtectedPaths.contains(where: { expandedPath.hasPrefix($0) || $0.hasPrefix(expandedPath) }) {
                    continue
                }

                // Check if path exists
                guard FileManager.default.fileExists(atPath: expandedPath) else {
                    continue
                }

                // Get size and file count with age filter
                let (size, fileCount, eligibleSize, eligibleCount) = await getDirectoryInfoWithAgeFilter(
                    at: expandedPath,
                    minAgeDays: minimumFileAgeDays
                )

                // Only add if there's something to clean (> 1MB)
                let effectiveSize = minimumFileAgeDays > 0 ? eligibleSize : size
                let effectiveCount = minimumFileAgeDays > 0 ? eligibleCount : fileCount

                if effectiveSize > 1_000_000 {
                    var item = CleaningItem(
                        name: name,
                        path: expandedPath,
                        size: effectiveSize,
                        fileCount: effectiveCount
                    )
                    item.totalSize = size
                    item.totalFileCount = fileCount
                    cleaningItems.append(item)
                }
            }

            // Only add category if it has items
            if !cleaningItems.isEmpty {
                // Sort items by size descending
                cleaningItems.sort { $0.size > $1.size }
                var category = CleaningCategory(
                    name: categoryName,
                    icon: icon,
                    items: cleaningItems
                )
                category.warning = warning
                categories.append(category)
            }
        }

        // Sort categories by total size descending
        categories.sort { $0.totalSize > $1.totalSize }

        scanProgress = 1.0
        currentScanItem = ""
        isScanning = false
    }

    /// Scan only safe paths for scheduled/automated tasks
    func scanForScheduledClean() async {
        await scanForCleanableItems(forScheduledTask: true)
    }

    /// Get directory size and file count with optional age filtering
    /// Returns: (totalSize, totalFileCount, eligibleSize, eligibleFileCount)
    private func getDirectoryInfoWithAgeFilter(at path: String, minAgeDays: Int) async -> (size: Int64, fileCount: Int, eligibleSize: Int64, eligibleCount: Int) {
        var totalSize: Int64 = 0
        var fileCount = 0
        var eligibleSize: Int64 = 0
        var eligibleCount = 0

        let fileManager = FileManager.default
        let cutoffDate = minAgeDays > 0 ? Calendar.current.date(byAdding: .day, value: -minAgeDays, to: Date()) : nil

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0, 0, 0)
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey])
                if resourceValues.isRegularFile == true {
                    let size = Int64(resourceValues.fileSize ?? 0)
                    totalSize += size
                    fileCount += 1

                    // Check if file is old enough
                    if let cutoff = cutoffDate, let modDate = resourceValues.contentModificationDate {
                        if modDate < cutoff {
                            eligibleSize += size
                            eligibleCount += 1
                        }
                    } else {
                        // No age filter or no mod date - include all
                        eligibleSize += size
                        eligibleCount += 1
                    }
                }
            } catch {
                continue
            }

            // Limit enumeration to avoid hanging on huge directories
            if fileCount > 50000 {
                break
            }
        }

        return (totalSize, fileCount, eligibleSize, eligibleCount)
    }

    /// Perform a dry run to show what would be deleted without actually deleting
    func performDryRun() async {
        dryRunResults = []
        let cutoffDate = minimumFileAgeDays > 0 ? Calendar.current.date(byAdding: .day, value: -minimumFileAgeDays, to: Date()) : nil

        for category in categories {
            for item in category.items where item.isSelected {
                let url = URL(fileURLWithPath: item.path)

                guard let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                var filesInItem: [(path: String, size: Int64, modDate: Date?)] = []

                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey])
                        if resourceValues.isRegularFile == true {
                            let size = Int64(resourceValues.fileSize ?? 0)
                            let modDate = resourceValues.contentModificationDate

                            // Apply age filter
                            if let cutoff = cutoffDate, let mod = modDate {
                                if mod >= cutoff { continue } // Skip recent files
                            }

                            filesInItem.append((fileURL.path, size, modDate))
                        }
                    } catch {
                        continue
                    }

                    // Limit to first 100 files per item for dry run display
                    if filesInItem.count >= 100 { break }
                }

                if !filesInItem.isEmpty {
                    dryRunResults.append(DryRunResult(
                        categoryName: category.name,
                        itemName: item.name,
                        files: filesInItem.map { DryRunFile(path: $0.path, size: $0.size, modificationDate: $0.modDate) },
                        totalSize: item.size,
                        totalFiles: item.fileCount
                    ))
                }
            }
        }
    }

    /// Clear dry run results
    func clearDryRunResults() {
        dryRunResults = []
    }

    /// Clean selected items by moving to Trash
    func cleanSelectedItems() async {
        // If dry run mode is enabled, just perform dry run
        if isDryRunMode {
            await performDryRun()
            return
        }

        isCleaning = true
        lastCleanedSize = 0

        let startTime = Date()
        var cleanedSize: Int64 = 0
        var itemsProcessed = 0
        var failedItems = 0
        var cleanedNames: [String] = []

        let cutoffDate = minimumFileAgeDays > 0 ? Calendar.current.date(byAdding: .day, value: -minimumFileAgeDays, to: Date()) : nil

        for category in categories {
            for item in category.items where item.isSelected {
                do {
                    // Move to trash instead of permanent delete
                    let url = URL(fileURLWithPath: item.path)

                    // For directories, we'll delete contents but keep the directory
                    if let enumerator = FileManager.default.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.contentModificationDateKey],
                        options: [.skipsHiddenFiles]
                    ) {
                        var filesToDelete: [URL] = []
                        for case let fileURL as URL in enumerator {
                            // Apply age filter if set
                            if let cutoff = cutoffDate {
                                if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                                    if modDate >= cutoff { continue } // Skip recent files
                                }
                            }
                            filesToDelete.append(fileURL)
                        }

                        // Delete in reverse order (deepest first)
                        for fileURL in filesToDelete.reversed() {
                            try? FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
                        }
                    }

                    cleanedSize += item.size
                    itemsProcessed += 1
                    cleanedNames.append(item.name)
                } catch {
                    failedItems += 1
                    continue
                }
            }
        }

        lastCleanedSize = cleanedSize
        let duration = Date().timeIntervalSince(startTime)

        // Log to history
        let status: OperationStatus = failedItems == 0 ? .success : (itemsProcessed > 0 ? .partial : .failed)
        let operation = OperationRecord(
            type: .cleaning,
            name: "System cleaning",
            status: status,
            details: "Cleaned: \(cleanedNames.joined(separator: ", "))",
            itemsProcessed: itemsProcessed,
            spaceFreed: cleanedSize,
            duration: duration,
            errorMessage: failedItems > 0 ? "\(failedItems) items failed to clean" : nil
        )
        OperationHistoryManager.shared.addOperation(operation)

        // Rescan to update sizes
        await scanForCleanableItems()

        isCleaning = false
    }

    /// Toggle selection for an item
    func toggleSelection(categoryId: UUID, itemId: UUID) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryId }),
              let itemIndex = categories[categoryIndex].items.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        categories[categoryIndex].items[itemIndex].isSelected.toggle()
    }

    /// Select all items in a category
    func selectAll(categoryId: UUID) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryId }) else {
            return
        }
        for i in categories[categoryIndex].items.indices {
            categories[categoryIndex].items[i].isSelected = true
        }
    }

    /// Deselect all items in a category
    func deselectAll(categoryId: UUID) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryId }) else {
            return
        }
        for i in categories[categoryIndex].items.indices {
            categories[categoryIndex].items[i].isSelected = false
        }
    }

    /// Select all items across all categories
    func selectAllItems() {
        for categoryIndex in categories.indices {
            for itemIndex in categories[categoryIndex].items.indices {
                categories[categoryIndex].items[itemIndex].isSelected = true
            }
        }
    }

    /// Deselect all items across all categories
    func deselectAllItems() {
        for categoryIndex in categories.indices {
            for itemIndex in categories[categoryIndex].items.indices {
                categories[categoryIndex].items[itemIndex].isSelected = false
            }
        }
    }

    /// Select items in categories whose name contains the given string
    func selectItemsInCategories(containing text: String) {
        for categoryIndex in categories.indices {
            if categories[categoryIndex].name.lowercased().contains(text.lowercased()) {
                for itemIndex in categories[categoryIndex].items.indices {
                    categories[categoryIndex].items[itemIndex].isSelected = true
                }
            }
        }
    }

    var totalSelectedSize: Int64 {
        categories.reduce(0) { $0 + $1.selectedSize }
    }

    var totalSelectedCount: Int {
        categories.reduce(0) { $0 + $1.selectedCount }
    }
}

// MARK: - Optimizer Provider

@Observable
final class OptimizerProvider {
    private(set) var tasks: [OptimizationTask] = []
    private(set) var isAnalyzing = false
    private(set) var error: Error?

    // Define available optimization tasks with their commands
    // Note: Only safe, user-level commands that don't require sudo
    private let availableOptimizations: [(name: String, description: String, icon: String, benefit: String, command: String, args: [String], checkCommand: String?)] = [
        (
            "Clear DNS cache",
            "Flush the DNS cache to resolve network issues and speed up lookups",
            "network",
            "Improved network performance",
            "/usr/bin/dscacheutil",
            ["-flushcache"],
            nil
        ),
        (
            "Clear Quick Look cache",
            "Remove Quick Look thumbnail cache to fix preview issues",
            "eye",
            "Better file previews",
            "/usr/bin/qlmanage",
            ["-r", "cache"],
            nil
        ),
        (
            "Reset launch services",
            "Rebuild the Launch Services database to fix app associations",
            "app.badge.checkmark",
            "Correct file associations",
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
            ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"],
            nil
        ),
        (
            "Rebuild font cache",
            "Clear corrupted font cache to fix display issues",
            "textformat",
            "Fixed font rendering",
            "/usr/bin/atsutil",
            ["databases", "-remove"],
            nil
        ),
        (
            "Refresh Dock",
            "Clear Dock cache and restart to fix display issues",
            "dock.rectangle",
            "Fixed Dock appearance",
            "/usr/bin/killall",
            ["Dock"],
            nil
        ),
        (
            "Refresh Finder",
            "Restart Finder to fix file browser issues",
            "folder",
            "Fixed file browsing",
            "/usr/bin/killall",
            ["Finder"],
            nil
        ),
        (
            "Clear memory cache",
            "Purge inactive memory to reduce memory pressure",
            "memorychip",
            "Reduced memory pressure",
            "/usr/sbin/purge",
            [],
            nil
        ),
        (
            "Flush ARP cache",
            "Clear ARP cache to fix network discovery issues",
            "wifi",
            "Better network discovery",
            "/usr/sbin/arp",
            ["-a", "-d"],
            nil
        ),
    ]

    /// Analyze system for optimization opportunities
    func analyzeSystem() async {
        isAnalyzing = true
        error = nil
        tasks = []

        // Check which optimizations are applicable
        var applicableTasks: [OptimizationTask] = []

        for opt in availableOptimizations {
            // Check if the command exists
            if FileManager.default.fileExists(atPath: opt.command) {
                applicableTasks.append(OptimizationTask(
                    name: opt.name,
                    description: opt.description,
                    icon: opt.icon,
                    benefit: opt.benefit,
                    command: opt.command,
                    arguments: opt.args
                ))
            }
        }

        // Add some analysis delay for UX
        try? await Task.sleep(for: .milliseconds(500))

        tasks = applicableTasks
        isAnalyzing = false
    }

    /// Run a specific optimization task
    func runTask(_ taskId: UUID) async {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }

        tasks[index].status = .running
        let startTime = Date()
        let taskName = tasks[index].name

        do {
            let task = tasks[index]

            // Create and run the process
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: task.command ?? "/usr/bin/true")
            process.arguments = task.arguments ?? []
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            let duration = Date().timeIntervalSince(startTime)

            if process.terminationStatus == 0 {
                tasks[index].status = .completed

                // Log success to history
                let operation = OperationRecord(
                    type: .optimization,
                    name: taskName,
                    status: .success,
                    details: task.description,
                    itemsProcessed: 1,
                    duration: duration
                )
                OperationHistoryManager.shared.addOperation(operation)
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                tasks[index].status = .failed(errorMessage)

                // Log failure to history
                let operation = OperationRecord(
                    type: .optimization,
                    name: taskName,
                    status: .failed,
                    details: task.description,
                    duration: duration,
                    errorMessage: errorMessage
                )
                OperationHistoryManager.shared.addOperation(operation)
            }
        } catch {
            tasks[index].status = .failed(error.localizedDescription)

            // Log failure to history
            let operation = OperationRecord(
                type: .optimization,
                name: taskName,
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                errorMessage: error.localizedDescription
            )
            OperationHistoryManager.shared.addOperation(operation)
        }
    }

    /// Run all pending tasks
    func runAllTasks() async {
        for task in tasks where task.status == .pending {
            await runTask(task.id)
        }
    }

    /// Retry all failed tasks
    func retryAllFailedTasks() async {
        for task in tasks {
            if case .failed = task.status {
                await runTask(task.id)
            }
        }
    }

    var pendingTaskCount: Int {
        tasks.filter { if case .pending = $0.status { return true } else { return false } }.count
    }

    var failedTaskCount: Int {
        tasks.filter { if case .failed = $0.status { return true } else { return false } }.count
    }

    var completedTaskCount: Int {
        tasks.filter { if case .completed = $0.status { return true } else { return false } }.count
    }
}
