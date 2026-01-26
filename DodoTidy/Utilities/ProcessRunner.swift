import Foundation

// MARK: - Process Runner

actor ProcessRunner {
    static let shared = ProcessRunner()

    private init() {}

    /// Run a CLI command and return the output
    func run(_ executable: String, arguments: [String] = [], timeout: TimeInterval = 60) async throws -> Data {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        // Set up timeout
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(timeout))
            if process.isRunning {
                process.terminate()
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ProcessRunnerError.executionFailed(code: process.terminationStatus, message: errorMessage)
        }

        return data
    }

    /// Find a system binary by name
    func systemBinaryPath(for name: String) -> String? {
        let possiblePaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)",
            "/usr/sbin/\(name)",
            "/sbin/\(name)",
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
}

enum ProcessRunnerError: LocalizedError {
    case binaryNotFound(String)
    case executionFailed(code: Int32, message: String)
    case decodingFailed(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return "Binary not found: \(name)"
        case .executionFailed(let code, let message):
            return "Execution failed (code \(code)): \(message)"
        case .decodingFailed(let error):
            return "Failed to decode output: \(error.localizedDescription)"
        case .timeout:
            return "Operation timed out"
        }
    }
}
