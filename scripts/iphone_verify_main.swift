import Foundation

@main
struct IPhoneVerifyMain {
    static func main() async {
        let root = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1]
            : FileManager.default.temporaryDirectory.appendingPathComponent("libra-iphone-verify").path

        print("VERIFY_ROOT=\(root)")
        let fm = FileManager.default
        let input = (root as NSString).appendingPathComponent("input")
        guard fm.fileExists(atPath: input) else {
            fputs("Missing input directory at \(input)\n", stderr)
            exit(1)
        }

        let ffprobe = ["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe"]
            .first { fm.isExecutableFile(atPath: $0) } ?? "ffprobe"

        let files = (try? fm.contentsOfDirectory(atPath: input)) ?? []
        var infos: [VideoInfo] = []
        var results: [String] = []
        for name in files.sorted() {
            let path = (input as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else { continue }
            let ext = (name as NSString).pathExtension.lowercased()
            let allowed = Set(AppSettings.default.videoExtensions + AppSettings.default.imageExtensions)
            if !allowed.contains(ext) {
                print("SKIPPED_UNSUPPORTED\t\(name)")
                results.append("Skipped\t\(name)\tUnsupported file type (.\(ext.isEmpty ? "?" : ext))\t")
                continue
            }
            let info = await MediaProbe.probe(filePath: path, ffprobePath: ffprobe)
            infos.append(info)
            print("PROBED\t\(name)\tmake=\(info.make)\tmodel=\(info.model)\tapple=\(info.hasAppleMake)\tiphone=\(info.hasiPhoneModel)\terror=\(info.error ?? "")")
        }

        // Apply sorter (non-dry-run)
        let ordered = infos.sorted { $0.path < $1.path }
        var iphoneFiles: [VideoInfo] = []
        var otherFiles: [VideoInfo] = []

        for file in ordered {
            if let error = file.error {
                results.append("FAIL\t\(file.name).\(file.ext)\tMetadata read failed: \(error)")
                continue
            }
            let c = IPhoneSortLogic.classify(
                hasAppleMake: file.hasAppleMake,
                hasiPhoneModel: file.hasiPhoneModel,
                make: file.make,
                model: file.model
            )
            if c.isIPhoneFolder { iphoneFiles.append(file) } else { otherFiles.append(file) }
        }

        let pad = IPhoneSortLogic.paddingWidth(forCount: iphoneFiles.count)
        var reserved = Set<String>()

        func uniqueReserved(_ path: String) -> String {
            var candidate = path
            var counter = 1
            let ext = (path as NSString).pathExtension
            let base = (path as NSString).deletingPathExtension
            while reserved.contains(candidate) || fm.fileExists(atPath: candidate) {
                candidate = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
                counter += 1
            }
            reserved.insert(candidate)
            return candidate
        }

        for (index, file) in iphoneFiles.enumerated() {
            let c = IPhoneSortLogic.classify(
                hasAppleMake: file.hasAppleMake,
                hasiPhoneModel: file.hasiPhoneModel,
                make: file.make,
                model: file.model
            )
            let filename = IPhoneSortLogic.iPhoneFileName(
                baseName: file.name,
                markers: c.markers,
                index: index + 1,
                padWidth: pad,
                ext: file.ext
            )
            let folder = (file.dir as NSString).appendingPathComponent("iPhone")
            let dest = uniqueReserved((folder as NSString).appendingPathComponent(filename))
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: false)
            results.append("\(result.status.rawValue)\t\(file.name).\(file.ext)\t\(result.outputPath ?? "")\t\(c.markers)")
        }

        for file in otherFiles {
            let filename = IPhoneSortLogic.notIPhoneFileName(baseName: file.name, ext: file.ext)
            let folder = (file.dir as NSString).appendingPathComponent("Not iPhone")
            let dest = uniqueReserved((folder as NSString).appendingPathComponent(filename))
            let result = FileOps.moveFile(from: file.path, to: dest, dryRun: false)
            results.append("\(result.status.rawValue)\t\(file.name).\(file.ext)\t\(result.outputPath ?? "")\t")
        }

        print("RESULTS")
        for line in results { print(line) }

        // Tree
        print("TREE")
        let enumerator = fm.enumerator(atPath: input)
        while let item = enumerator?.nextObject() as? String {
            print(item)
        }
    }
}
