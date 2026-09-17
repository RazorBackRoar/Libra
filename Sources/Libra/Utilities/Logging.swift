import Foundation
import os.log

/// Unified console + file logger.
@MainActor
final class Log {
    static let shared = Log()

    private static let timestampFormatter = ISO8601DateFormatter()
    /// Rotate `libra.log` to `libra.1.log` past this size (one generation kept).
    private static let maxLogBytes: UInt64 = 5 * 1024 * 1024

    private let fileURL: URL
    private let osLog = Logger(subsystem: Brand.appId, category: "app")
    /// Serial queue keeps per-line FileHandle I/O off the main actor.
    private let fileQueue = DispatchQueue(label: "com.razorbackroar.libra.log")
    private var hasSetup = false

    private init() {
        Paths.ensureLogsDirectory()
        fileURL = Paths.logsDirectory().appendingPathComponent("libra.log")
    }

    func setup() {
        hasSetup = true
        Paths.ensureLogsDirectory()
    }

    private func write(level: String, message: String, scope: String) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.uppercased())] [\(scope)] \(message)"
        osLog.log(level: level, "\(line)")

        guard hasSetup else { return }
        let fileURL = fileURL
        fileQueue.async {
            Self.appendLine(line, to: fileURL)
        }
    }

    private nonisolated static func appendLine(_ line: String, to fileURL: URL) {
        rotateIfNeeded(fileURL: fileURL)
        if let data = (line + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    private nonisolated static func rotateIfNeeded(fileURL: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
            let size = attrs[.size] as? UInt64, size > Self.maxLogBytes
        else { return }
        let rotated = fileURL.deletingLastPathComponent().appendingPathComponent("libra.1.log")
        try? FileManager.default.removeItem(at: rotated)
        try? FileManager.default.moveItem(at: fileURL, to: rotated)
    }

    func debug(_ message: String, scope: String = "app") {
        write(level: "debug", message: message, scope: scope)
    }
    func info(_ message: String, scope: String = "app") {
        write(level: "info", message: message, scope: scope)
    }
    func warn(_ message: String, scope: String = "app") {
        write(level: "warn", message: message, scope: scope)
    }
    func error(_ message: String, scope: String = "app") {
        write(level: "error", message: message, scope: scope)
    }
}

extension Logger {
    fileprivate func log(level: String, _ message: String) {
        switch level {
        case "debug": self.debug("\(message)")
        case "warn": self.warning("\(message)")
        case "error": self.error("\(message)")
        default: self.info("\(message)")
        }
    }
}
