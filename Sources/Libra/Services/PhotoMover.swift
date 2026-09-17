import Foundation

enum PhotoMover {
    static func move(
        _ files: [VideoInfo],
        to destDir: String,
        dryRun: Bool,
        shouldStop: () -> Bool = { false }
    ) -> [OperationResult] {
        var reserved = Set<String>()
        var results: [OperationResult] = []
        for file in files {
            if shouldStop() {
                results.append(
                    OperationResult(path: file.path, status: .cancelled, reason: "Cancelled"))
                continue
            }
            let filename = "\(FileOps.sanitizeFileName(file.name)).\(file.ext.lowercased())"
            let planned = (destDir as NSString).appendingPathComponent(filename)
            let result = FileOps.moveFile(
                from: file.path,
                to: planned,
                dryRun: dryRun,
                reserved: reserved,
                withinRoot: destDir
            )
            if let output = result.outputPath { reserved.insert(output) }
            results.append(result)
        }
        return results
    }
}
