import Foundation

enum UndoApply {
    static func apply(
        _ records: [UndoRecord],
        shouldStop: () -> Bool = { false }
    ) -> (restored: Int, failed: Int) {
        var restored = 0
        var failed = 0
        for record in records.reversed() {
            if shouldStop() { break }
            switch record.kind {
            case .moved:
                let originalDir = (record.originalPath as NSString).deletingLastPathComponent
                let result = FileOps.moveFile(
                    from: record.resultPath,
                    to: record.originalPath,
                    dryRun: false,
                    withinRoot: originalDir
                )
                if result.status == .success { restored += 1 } else { failed += 1 }
            case .createdCopy:
                let result = FileOps.trashFile(record.resultPath, dryRun: false)
                if result.status == .success { restored += 1 } else { failed += 1 }
            case .trashedOriginal:
                // Original still lives at record.resultPath inside ~/.Trash —
                // move it back to its pre-run location.
                let originalDir = (record.originalPath as NSString).deletingLastPathComponent
                let result = FileOps.moveFile(
                    from: record.resultPath,
                    to: record.originalPath,
                    dryRun: false,
                    withinRoot: originalDir
                )
                if result.status == .success { restored += 1 } else { failed += 1 }
            }
        }
        return (restored, failed)
    }
}
