import Foundation

@MainActor
enum FileOps {
    static func moveFile(from: String, to: String, dryRun: Bool) -> OperationResult {
        let target = uniquePath(for: to)
        if dryRun {
            return OperationResult(path: from, status: .success, reason: "Dry-run move to \(target)", outputPath: target)
        }
        do {
            let dir = (target as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.moveItem(atPath: from, toPath: target)
            return OperationResult(path: from, status: .success, outputPath: target)
        } catch {
            return OperationResult(path: from, status: .failed, reason: error.localizedDescription)
        }
    }

    static func copyFile(from: String, to: String, dryRun: Bool) -> OperationResult {
        let target = uniquePath(for: to)
        if dryRun {
            return OperationResult(path: from, status: .success, reason: "Dry-run copy to \(target)", outputPath: target)
        }
        do {
            let dir = (target as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.copyItem(atPath: from, toPath: target)
            return OperationResult(path: from, status: .success, outputPath: target)
        } catch {
            return OperationResult(path: from, status: .failed, reason: error.localizedDescription)
        }
    }

    static func renameFile(from: String, to: String, dryRun: Bool) -> OperationResult {
        let target = uniquePath(for: to)
        if dryRun {
            return OperationResult(path: from, status: .success, reason: "Dry-run rename to \(target)", outputPath: target)
        }
        do {
            let dir = (target as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.moveItem(atPath: from, toPath: target)
            return OperationResult(path: from, status: .success, outputPath: target)
        } catch {
            return OperationResult(path: from, status: .failed, reason: error.localizedDescription)
        }
    }

    static func deleteFile(_ path: String, dryRun: Bool) -> OperationResult {
        if dryRun {
            return OperationResult(path: path, status: .success, reason: "Dry-run delete")
        }
        do {
            try FileManager.default.removeItem(atPath: path)
            return OperationResult(path: path, status: .success)
        } catch {
            return OperationResult(path: path, status: .failed, reason: error.localizedDescription)
        }
    }

    static func uniquePath(for path: String) -> String {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            return path
        }

        let pathStr = path as NSString
        let dir = pathStr.deletingLastPathComponent
        let ext = pathStr.pathExtension
        let baseName = (pathStr.lastPathComponent as NSString).deletingPathExtension

        guard let files = try? fileManager.contentsOfDirectory(atPath: dir) else {
            var candidate = path
            var counter = 1
            let base = pathStr.deletingPathExtension
            while fileManager.fileExists(atPath: candidate) {
                if ext.isEmpty {
                    candidate = "\(base) (\(counter))"
                } else {
                    candidate = "\(base) (\(counter)).\(ext)"
                }
                counter += 1
            }
            return candidate
        }

        let existingFiles = Set(files)
        var counter = 1
        var candidateName = pathStr.lastPathComponent

        while existingFiles.contains(candidateName) {
            if ext.isEmpty {
                candidateName = "\(baseName) (\(counter))"
            } else {
                candidateName = "\(baseName) (\(counter)).\(ext)"
            }
            counter += 1
        }

        return (dir as NSString).appendingPathComponent(candidateName)
    }

    /// Sanitize unsafe filename characters while preserving a readable base name.
    static func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>\0")
        let parts = name.unicodeScalars.map { invalid.contains($0) ? "_" : Character($0) }
        var cleaned = String(parts)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        if cleaned.isEmpty { return "file" }
        if cleaned == "." || cleaned == ".." { return "file" }
        return cleaned
    }
}
