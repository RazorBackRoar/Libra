import Foundation

enum FileOps {
    /// True when `path` itself is a symlink or Finder alias (does not follow the target).
    static func isSymlinkOrAlias(_ path: String) -> Bool {
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil {
            return true
        }
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isAliasFileKey])
        return values?.isAliasFile == true
    }

    /// Symlink-resolved, standardized path. Missing last components still resolve existing parents.
    static func resolvedPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) || isSymlinkOrAlias(path) {
            return url.resolvingSymlinksInPath().standardizedFileURL.path
        }
        let parent = url.deletingLastPathComponent()
        let resolvedParent = URL(fileURLWithPath: parent.path).resolvingSymlinksInPath()
        return resolvedParent.appendingPathComponent(url.lastPathComponent).standardizedFileURL.path
    }

    /// True when `path` is `ancestor` or a file/folder inside it (logical, no symlink resolve).
    static func isPath(_ path: String, inside ancestor: String) -> Bool {
        let child = URL(fileURLWithPath: path).standardizedFileURL.path
        let root = URL(fileURLWithPath: ancestor).standardizedFileURL.path
        if child == root { return true }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return child.hasPrefix(prefix)
    }

    /// True when the physical location of `path` stays inside the physical `ancestor`.
    static func isPhysicallyInside(_ path: String, ancestor: String) -> Bool {
        isPath(resolvedPath(path), inside: resolvedPath(ancestor))
    }

    /// Reject dest files that are links, and dest parents that resolve outside `root`.
    static func destinationIsSafe(_ dest: String, within root: String) -> Bool {
        guard !dest.isEmpty, !root.isEmpty else { return false }
        if isSymlinkOrAlias(dest) { return false }
        let parent = (dest as NSString).deletingLastPathComponent
        if isSymlinkOrAlias(parent), !isPhysicallyInside(parent, ancestor: root) {
            return false
        }
        return isPhysicallyInside(dest, ancestor: root)
    }

    static func moveFile(
        from: String,
        to: String,
        dryRun: Bool,
        reserved: Set<String> = [],
        withinRoot: String? = nil
    ) -> OperationResult {
        if isSymlinkOrAlias(from) {
            return OperationResult(path: from, status: .skipped, reason: "Skipped symlink or alias")
        }
        let target = uniquePath(for: to, reserved: reserved)
        if let withinRoot, !destinationIsSafe(target, within: withinRoot) {
            return OperationResult(
                path: from,
                status: .skipped,
                reason: "Skipped destination outside selected folder (symlink)"
            )
        }
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

    static func copyFile(
        from: String,
        to: String,
        dryRun: Bool,
        reserved: Set<String> = [],
        withinRoot: String? = nil
    ) -> OperationResult {
        if isSymlinkOrAlias(from) {
            return OperationResult(path: from, status: .skipped, reason: "Skipped symlink or alias")
        }
        let target = uniquePath(for: to, reserved: reserved)
        if let withinRoot, !destinationIsSafe(target, within: withinRoot) {
            return OperationResult(
                path: from,
                status: .skipped,
                reason: "Skipped destination outside selected folder (symlink)"
            )
        }
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

    static func renameFile(from: String, to: String, dryRun: Bool, reserved: Set<String> = []) -> OperationResult {
        moveFile(from: from, to: to, dryRun: dryRun, reserved: reserved)
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

    /// Prefer incrementing a trailing padded index (`… 001` → `… 002`) instead of ` (1)`.
    static func uniquePath(for path: String, reserved: Set<String> = []) -> String {
        let fileManager = FileManager.default
        func taken(_ candidate: String) -> Bool {
            reserved.contains(candidate) || fileManager.fileExists(atPath: candidate)
        }
        if !taken(path) { return path }

        let pathStr = path as NSString
        let dir = pathStr.deletingLastPathComponent
        let ext = pathStr.pathExtension
        let baseName = (pathStr.lastPathComponent as NSString).deletingPathExtension

        if let parsed = trailingIndex(baseName) {
            var number = parsed.number
            var candidate = path
            while taken(candidate) {
                number += 1
                let stem = "\(parsed.prefix)\(pad(number, width: parsed.width))"
                candidate = join(dir: dir, stem: stem, ext: ext)
            }
            return candidate
        }

        var number = 2
        var candidate = path
        while taken(candidate) {
            let stem = "\(baseName) \(pad(number, width: 3))"
            candidate = join(dir: dir, stem: stem, ext: ext)
            number += 1
        }
        return candidate
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

    private static func trailingIndex(_ baseName: String) -> (prefix: String, number: Int, width: Int)? {
        guard let space = baseName.lastIndex(of: " ") else { return nil }
        let token = String(baseName[baseName.index(after: space)...])
        guard !token.isEmpty, token.allSatisfy(\.isNumber), let value = Int(token) else { return nil }
        let prefix = String(baseName[...space])
        return (prefix, value, max(token.count, 3))
    }

    private static func pad(_ number: Int, width: Int) -> String {
        String(format: "%0\(width)d", number)
    }

    private static func join(dir: String, stem: String, ext: String) -> String {
        if ext.isEmpty {
            return (dir as NSString).appendingPathComponent(stem)
        }
        return (dir as NSString).appendingPathComponent("\(stem).\(ext)")
    }
}
