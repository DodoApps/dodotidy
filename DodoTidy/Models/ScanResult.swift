import Foundation

// MARK: - Scan Result (matches dodo-analyze --json output)

struct ScanResult: Codable {
    let path: String
    let totalSize: Int64
    let totalFiles: Int64
    let entries: [DirEntry]
    let largeFiles: [FileEntry]
    let scannedAt: Date

    enum CodingKeys: String, CodingKey {
        case path
        case totalSize = "total_size"
        case totalFiles = "total_files"
        case entries
        case largeFiles = "large_files"
        case scannedAt = "scanned_at"
    }
}

struct DirEntry: Codable, Identifiable, Hashable {
    let name: String
    let path: String
    let size: Int64
    let isDir: Bool
    let lastAccess: Date?

    var id: String { path }

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case size
        case isDir = "is_dir"
        case lastAccess = "last_access"
    }

    /// Direct initializer for native Swift scanning
    init(name: String, path: String, size: Int64, isDir: Bool, lastAccess: Date? = nil) {
        self.name = name
        self.path = path
        self.size = size
        self.isDir = isDir
        self.lastAccess = lastAccess
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        size = try container.decode(Int64.self, forKey: .size)
        isDir = try container.decode(Bool.self, forKey: .isDir)

        // Handle the date parsing - it can be a zero date from Go
        if let dateString = try? container.decode(String.self, forKey: .lastAccess) {
            if dateString.contains("0001-01-01") {
                lastAccess = nil
            } else {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                lastAccess = formatter.date(from: dateString)
            }
        } else {
            lastAccess = try? container.decode(Date.self, forKey: .lastAccess)
        }
    }
}

struct FileEntry: Codable, Identifiable, Hashable {
    let name: String
    let path: String
    let size: Int64

    var id: String { path }
}

// MARK: - Cleaning Models

struct CleaningCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    var items: [CleaningItem]
    var isExpanded: Bool = true
    var warning: String? = nil  // Safety warning for risky categories

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }

    var hasWarning: Bool {
        warning != nil
    }
}

struct CleaningItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    var size: Int64           // Size of files eligible for cleaning (after age filter)
    var fileCount: Int        // Count of files eligible for cleaning
    var isSelected: Bool = true
    var totalSize: Int64 = 0      // Total size including files not eligible
    var totalFileCount: Int = 0   // Total count including files not eligible
}

// MARK: - Dry Run Models

struct DryRunResult: Identifiable {
    let id = UUID()
    let categoryName: String
    let itemName: String
    let files: [DryRunFile]
    let totalSize: Int64
    let totalFiles: Int

    var displayedFilesNote: String? {
        if totalFiles > files.count {
            return "Showing \(files.count) of \(totalFiles) files"
        }
        return nil
    }
}

struct DryRunFile: Identifiable {
    let id = UUID()
    let path: String
    let size: Int64
    let modificationDate: Date?

    var fileName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var relativePath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return path.replacingOccurrences(of: homeDir, with: "~")
    }
}

// MARK: - Optimization Models

struct OptimizationTask: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let benefit: String
    var status: OptimizationStatus = .pending
    var command: String?
    var arguments: [String]?
}

enum OptimizationStatus: Equatable {
    case pending
    case running
    case completed
    case failed(String)
}
