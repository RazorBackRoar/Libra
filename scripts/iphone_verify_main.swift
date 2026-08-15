import Foundation

@main
struct IPhoneVerifyMain {
    static func main() async throws {
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
            let info = try await MediaProbe.probe(filePath: path)
            infos.append(info)
            print("PROBED\t\(name)\tmake=\(info.make)\tmodel=\(info.model)\tapple=\(info.hasAppleMake)\tiphone=\(info.hasiPhoneModel)\tgps=\(info.hasGPS)\terror=\(info.error ?? "")")
        }

        // Apply sorter (non-dry-run)
        let ordered = infos.sorted { $0.path < $1.path }
        var groups: [IPhoneSortLogic.Folder: [VideoInfo]] = [:]

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
            groups[c.folder, default: []].append(file)
        }

        let allNamed = IPhoneSortLogic.Folder.allCases.flatMap { groups[$0] ?? [] }
        let pad = FileNaming.paddingWidth(forCount: allNamed.count)
        var reserved = Set<String>()
        var index = 0

        for folder in IPhoneSortLogic.Folder.allCases {
            for file in groups[folder] ?? [] {
                let c = IPhoneSortLogic.classify(
                    hasAppleMake: file.hasAppleMake,
                    hasiPhoneModel: file.hasiPhoneModel,
                    make: file.make,
                    model: file.model
                )
                index += 1
                let filename = FileNaming.standardFileName(for: file, index: index, padWidth: pad)
                let destDir = (file.dir as NSString).appendingPathComponent(folder.rawValue)
                let planned = (destDir as NSString).appendingPathComponent(filename)
                let result = FileOps.moveFile(from: file.path, to: planned, dryRun: false, reserved: reserved)
                if let output = result.outputPath { reserved.insert(output) }
                let markers = FileNaming.metadataMarkers(
                    hasAppleMake: file.hasAppleMake,
                    hasiPhoneModel: file.hasiPhoneModel,
                    hasGPS: file.hasGPS
                )
                results.append("\(result.status.rawValue)\t\(file.name).\(file.ext)\t\(result.outputPath ?? "")\t\(markers)\t\(c.note)")
            }
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
