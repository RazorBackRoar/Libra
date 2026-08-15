import Foundation

enum UndoApply {
    static func apply(_ records: [UndoRecord]) -> (restored: Int, failed: Int) {
        var restored = 0
        var failed = 0
        for record in records.reversed() {
            switch record.kind {
            case .moved:
                let result = FileOps.moveFile(from: record.resultPath, to: record.originalPath, dryRun: false)
                if result.status == .success { restored += 1 } else { failed += 1 }
            case .createdCopy:
                let result = FileOps.deleteFile(record.resultPath, dryRun: false)
                if result.status == .success { restored += 1 } else { failed += 1 }
            }
        }
        return (restored, failed)
    }
}
