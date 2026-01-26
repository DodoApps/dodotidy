import Foundation

// MARK: - Number Formatting Extensions

extension Int64 {
    /// Format bytes to human-readable string (e.g., "1.5 GB")
    var formattedBytes: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: self)
    }
}

extension UInt64 {
    /// Format bytes to human-readable string (e.g., "1.5 GB")
    var formattedBytes: String {
        Int64(self).formattedBytes
    }
}

extension Double {
    /// Format as percentage with integer (e.g., "45%")
    var formattedPercentInt: String {
        "\(Int(self))%"
    }

    /// Format as percentage with one decimal (e.g., "45.2%")
    var formattedPercent: String {
        String(format: "%.1f%%", self)
    }
}

extension Int {
    /// Format bytes to human-readable string
    var formattedBytes: String {
        Int64(self).formattedBytes
    }

    /// Format number with thousand separators (e.g., "1,234,567")
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Int64 {
    /// Format number with thousand separators (e.g., "1,234,567")
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Date Formatting Extensions

extension Date {
    /// Format as relative time (e.g., "2 hours ago")
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Format as short date (e.g., "Jan 15, 2024")
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// Format as date and time (e.g., "Jan 15, 2024 at 3:45 PM")
    var dateTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - String Extensions

extension String {
    /// Truncate string with ellipsis
    func truncated(to length: Int) -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length - 3)) + "..."
    }
}

// MARK: - Helper Functions

/// Format bytes to human-readable string
func formatBytes(_ bytes: Int64) -> String {
    bytes.formattedBytes
}

/// Format bytes to human-readable string
func formatBytes(_ bytes: UInt64) -> String {
    Int64(bytes).formattedBytes
}
