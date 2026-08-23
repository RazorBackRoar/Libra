import Foundation

enum ScanSafety {
    static let testFolderMarker = "MetaBurn & Libra Test"
    static let legacyTestFolderMarker = "MetaBurn & L!bra Test"
    static let largeScanThreshold = 500

    private static func isTestFolder(_ path: String) -> Bool {
        path.contains(testFolderMarker) || path.contains(legacyTestFolderMarker)
    }

    /// Warning before walking a huge or accidental root. Nil means proceed.
    static func warning(for paths: [String]) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let desktop = home + "/Desktop"
        for path in paths {
            let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
            if isTestFolder(standardized) { continue }
            if standardized == "/" {
                return "This is the whole disk. Libra would scan every matching video."
            }
            if standardized == home {
                return "This is your home folder. Libra would scan everything in it."
            }
            if standardized == desktop {
                return "This is the Desktop. Libra would scan every matching video on it."
            }
            if isVolumeRoot(standardized) {
                return "This looks like a volume root. Libra would scan the whole volume."
            }
        }
        return nil
    }

    /// Warning after discover, before metadata probe. Nil means proceed.
    static func fileCountWarning(count: Int, paths: [String] = []) -> String? {
        guard count >= largeScanThreshold else { return nil }
        if paths.contains(where: { isTestFolder($0) }) { return nil }
        return "This folder has \(count) videos and photos. Libra will read metadata for each one."
    }

    static func isVolumeRoot(_ path: String) -> Bool {
        if path == "/" { return true }
        let parts = path.split(separator: "/")
        return parts.count == 2 && parts.first == "Volumes"
    }

    static func destinationIsInsideSource(dest: String, sourceRoot: String?) -> Bool {
        guard let sourceRoot, !sourceRoot.isEmpty else { return false }
        return FileOps.isPhysicallyInside(dest, ancestor: sourceRoot)
    }
}
