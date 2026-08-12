import Foundation

enum PhotoMover {
    @MainActor
    static func move(_ files: [VideoInfo], to destDir: String, dryRun: Bool) -> [OperationResult] {
        var reserved = Set<String>()
        var results: [OperationResult] = []
        for file in files {
            let filename = "\(FileOps.sanitizeFileName(file.name)).\(file.ext.lowercased())"
            let dest = FileOps.uniquePath(
                for: (destDir as NSString).appendingPathComponent(filename),
                reserved: reserved
            )
            reserved.insert(dest)
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: dryRun, reserved: reserved)
            if let output = result.outputPath { reserved.insert(output) }
            results.append(result)
        }
        return results
    }
}
