import AppKit

enum MediaOpen {
    static func open(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    static func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// Selects every file in Finder — one window per containing folder.
    static func reveal(_ paths: [String]) {
        NSWorkspace.shared.activateFileViewerSelecting(
            paths.map { URL(fileURLWithPath: $0) })
    }
}
