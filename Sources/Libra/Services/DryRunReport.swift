import Foundation

enum DryRunReport {
    /// Writes a clean before/after listing to the Desktop as
    /// `L!bra ProVid Dry Run 1.txt` (tool title in the name), then `2`, `3`, …
    /// without overwriting existing files.
    @discardableResult
    static func write(tool: Tool, results: [OperationResult]) -> URL? {
        let entries = results.compactMap { result -> (before: String, after: String, note: String?)? in
            let before = (result.path as NSString).lastPathComponent
            if let output = result.outputPath {
                let after = (output as NSString).lastPathComponent
                return (before, after, result.status == .success ? nil : result.reason)
            }
            if let reason = result.reason {
                return (before, "(no change)", reason)
            }
            return (before, "(no change)", result.status.rawValue)
        }
        guard !entries.isEmpty else { return nil }

        let url = nextReportURL(tool: tool)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var lines: [String] = [
            "\(Brand.displayName) \(tool.title) Dry Run",
            "Tool: \(tool.title)",
            "Generated: \(formatter.string(from: Date()))",
            "Items: \(entries.count)",
            "",
            String(repeating: "-", count: 72)
        ]

        for (index, entry) in entries.enumerated() {
            lines.append("")
            lines.append("\(index + 1).")
            lines.append("Before: \(entry.before)")
            lines.append("After:  \(entry.after)")
            if let note = entry.note, !note.isEmpty {
                lines.append("Note:   \(note)")
            }
        }
        lines.append("")

        let text = lines.joined(separator: "\n")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func nextReportURL(tool: Tool) -> URL {
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
        let base = "\(Brand.displayName) \(tool.title) Dry Run"
        var number = 1
        while true {
            let name = "\(base) \(number).txt"
            let url = desktop.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            number += 1
        }
    }
}
