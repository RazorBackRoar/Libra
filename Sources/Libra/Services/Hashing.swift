import Foundation
import CryptoKit

@MainActor
enum Hashing {
    static func md5(filePath: String) async -> String? {
        do {
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: filePath))
            var md5 = Insecure.MD5()
            while true {
                let data = handle.readData(ofLength: 65536)
                if data.isEmpty { break }
                md5.update(data: data)
            }
            try? handle.close()
            return md5.finalize().map { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }

    static func findDuplicates(files: [VideoInfo], progress: @MainActor @escaping (Int, Int) -> Void) async -> [DuplicateGroup] {
        var hashes: [String: [VideoInfo]] = [:]
        let total = files.count
        for (index, file) in files.enumerated() {
            if let hash = await md5(filePath: file.path) {
                hashes[hash, default: []].append(file)
            }
            progress(index + 1, total)
        }
        return hashes.filter { $0.value.count > 1 }.map { DuplicateGroup(hash: $0.key, files: $0.value) }
    }
}
