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
        var candidate = path
        var counter = 1
        let ext = (path as NSString).pathExtension
        let base = (path as NSString).deletingPathExtension
        while FileManager.default.fileExists(atPath: candidate) {
            candidate = "\(base) (\(counter)).\(ext)"
            counter += 1
        }
        return candidate
    }
}
