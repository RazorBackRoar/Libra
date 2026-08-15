import Foundation

enum RunRecap {
    static func summary(
        previewPass: Bool,
        cancelled: Bool,
        success: Int,
        failed: Int,
        skipped: Int,
        done: Int,
        total: Int
    ) -> String {
        if cancelled {
            if previewPass {
                return "Cancelled after \(done) of \(total)."
            }
            if success == 0 {
                return "Cancelled before any videos were written."
            }
            let noun = success == 1 ? "video" : "videos"
            return "Cancelled. \(success) \(noun) already written. Undo Last Run to put them back."
        }
        if previewPass {
            var summary = "Preview: \(success) would change"
            if failed > 0 { summary += ", \(failed) failed" }
            if skipped > 0 { summary += ", \(skipped) skipped" }
            return summary + "."
        }
        var summary = "Wrote \(success) of \(total)"
        if failed > 0 { summary += ", \(failed) failed" }
        if skipped > 0 { summary += ", \(skipped) skipped" }
        return summary + "."
    }
}
