import Foundation
import ImageIO
import UniformTypeIdentifiers

enum DeviceMetadata {
    static func hasAppleMake(in values: [String]) -> Bool {
        values.contains { value in
            let lower = value.lowercased()
            return lower == "apple" || lower.contains("apple")
        }
    }

    static func hasiPhoneModel(in values: [String]) -> Bool {
        values.contains { $0.lowercased().contains("iphone") }
    }

    static func collectStringValues(from dictionary: [String: Any], keys: [String]) -> [String] {
        var values: [String] = []
        for key in keys {
            if let value = dictionary[key] as? String, !value.isEmpty {
                values.append(value)
            }
        }
        for (_, value) in dictionary {
            if let nested = value as? [String: Any] {
                values.append(contentsOf: collectStringValues(from: nested, keys: keys))
            }
        }
        return values
    }

    static let makeKeys = [
        "make", "Make", "com.apple.quicktime.make", "com.apple.quicktime.Make",
        "device_make", "DeviceMake", "camera_make", "CameraMake", "Artist"
    ]

    static let modelKeys = [
        "model", "Model", "com.apple.quicktime.model", "com.apple.quicktime.Model",
        "device_model", "DeviceModel", "camera_model", "CameraModel",
        "com.apple.quicktime.camera.model"
    ]
}

@MainActor
enum MediaProbe {
    static func probe(filePath: String, ffprobePath: String) async -> VideoInfo {
        let url = URL(fileURLWithPath: filePath)
        let name = url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent().path
        let ext = url.pathExtension.lowercased()

        var size: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
           let s = attrs[.size] as? Int64 {
            size = s
        }

        let imageExts = Set(AppSettings.default.imageExtensions)
        if imageExts.contains(ext) {
            var info = probeImage(filePath: filePath, name: name, dir: dir, ext: ext, size: size)
            if let enriched = await enrichWithExiftool(path: filePath, existing: info) {
                info = enriched
            }
            return info
        }
        return await probeVideo(filePath: filePath, name: name, dir: dir, ext: ext, size: size, ffprobePath: ffprobePath)
    }

    private static func probeVideo(
        filePath: String,
        name: String,
        dir: String,
        ext: String,
        size: Int64,
        ffprobePath: String
    ) async -> VideoInfo {
        do {
            let json = try await runFfprobe(filePath: filePath, ffprobePath: ffprobePath)

            let format = json["format"] as? [String: Any] ?? [:]
            let streams = json["streams"] as? [[String: Any]] ?? []
            let videoStream = streams.first { ($0["codec_type"] as? String) == "video" } ?? [:]

            let props = extractVideoProperties(format: format, videoStream: videoStream)
            let meta = extractVideoMetadata(format: format, videoStream: videoStream)

            var info = VideoInfo(
                path: filePath,
                name: name,
                dir: dir,
                ext: ext,
                sizeBytes: size,
                width: props.width,
                height: props.height,
                resolutionClass: resolutionClass(width: props.width, height: props.height),
                orientation: orientation(width: props.width, height: props.height),
                fps: props.fps,
                durationSec: props.duration,
                codec: props.codec,
                container: props.container,
                make: meta.make,
                model: meta.model,
                hasAppleMake: meta.hasAppleMake,
                hasiPhoneModel: meta.hasiPhoneModel,
                hasGPS: meta.hasGPS,
                creationTime: meta.creationTime,
                error: nil
            )

            // Enrich with exiftool when available (videos often store Make/Model there)
            if let enriched = await enrichWithExiftool(path: filePath, existing: info) {
                info = enriched
            }
            return info
        } catch {
            return failedVideoInfo(
                filePath: filePath,
                name: name,
                dir: dir,
                ext: ext,
                size: size,
                error: error.localizedDescription
            )
        }
    }

    private static func runFfprobe(filePath: String, ffprobePath: String) async throws -> [String: Any] {
        let args = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            filePath
        ]
        let output = try await ProcessRunner.run(executablePath: ffprobePath, arguments: args, timeout: 30)
        return try JSONSerialization.jsonObject(with: output.stdout.data(using: .utf8) ?? Data()) as? [String: Any] ?? [:]
    }

    private static func extractVideoProperties(format: [String: Any], videoStream: [String: Any]) -> (width: Int, height: Int, duration: Double, fps: Double, codec: String, container: String) {
        let width = parseInt(videoStream["width"])
        let height = parseInt(videoStream["height"])
        let duration = parseDouble(format["duration"] as? String) ?? parseDouble(videoStream["duration"] as? String) ?? 0
        let fps = parseFps(videoStream["r_frame_rate"] as? String)
        let codec = videoStream["codec_name"] as? String ?? ""
        let container = format["format_name"] as? String ?? ""
        return (width, height, duration, fps, codec, container)
    }

    private static func extractVideoMetadata(format: [String: Any], videoStream: [String: Any]) -> (make: String, model: String, hasAppleMake: Bool, hasiPhoneModel: Bool, hasGPS: Bool, creationTime: Date?) {
        let tags = videoStream["tags"] as? [String: Any] ?? [:]
        let formatTags = format["tags"] as? [String: Any] ?? [:]
        let mergedTags = tags.merging(formatTags) { current, _ in current }

        let makeValues = DeviceMetadata.collectStringValues(from: mergedTags, keys: DeviceMetadata.makeKeys)
        let modelValues = DeviceMetadata.collectStringValues(from: mergedTags, keys: DeviceMetadata.modelKeys)
        // Also check exiftool-style fields if present in tags
        let allMake = makeValues + stringValues(matching: mergedTags) { $0.lowercased().contains("make") }
        let allModel = modelValues + stringValues(matching: mergedTags) { key in
            let lower = key.lowercased()
            return lower.contains("model") && !lower.contains("make")
        }

        let make = preferredValue(allMake)
        let model = preferredValue(allModel)
        let hasAppleMake = DeviceMetadata.hasAppleMake(in: allMake)
        let hasiPhoneModel = DeviceMetadata.hasiPhoneModel(in: allModel + allMake)
        let creation = parseDate(tags["creation_time"] as? String) ?? parseDate(formatTags["creation_time"] as? String)
        let hasGPS = mergedTags.keys.contains { $0.lowercased().contains("location") || $0.lowercased().contains("gps") }

        return (make, model, hasAppleMake, hasiPhoneModel, hasGPS, creation)
    }

    private static func failedVideoInfo(
        filePath: String,
        name: String,
        dir: String,
        ext: String,
        size: Int64,
        error: String
    ) -> VideoInfo {
        VideoInfo(
            path: filePath,
            name: name,
            dir: dir,
            ext: ext,
            sizeBytes: size,
            width: 0,
            height: 0,
            resolutionClass: "Unknown",
            orientation: "Unknown",
            fps: 0,
            durationSec: 0,
            codec: "",
            container: "",
            make: "",
            model: "",
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            creationTime: nil,
            error: error
        )
    }

    private static func probeImage(filePath: String, name: String, dir: String, ext: String, size: Int64) -> VideoInfo {
        let url = URL(fileURLWithPath: filePath)

        func failed(_ message: String) -> VideoInfo {
            VideoInfo(
                path: filePath,
                name: name,
                dir: dir,
                ext: ext,
                sizeBytes: size,
                width: 0,
                height: 0,
                resolutionClass: "Unknown",
                orientation: "Unknown",
                fps: 0,
                durationSec: 0,
                codec: "",
                container: ext,
                make: "",
                model: "",
                hasAppleMake: false,
                hasiPhoneModel: false,
                hasGPS: false,
                creationTime: nil,
                error: message
            )
        }

        if size <= 0 {
            return failed("Could not read image metadata (empty or unreadable file)")
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return failed("Could not read image metadata")
        }
        guard CGImageSourceGetCount(source) > 0 else {
            return failed("Could not read image metadata (no image frames)")
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        let pixelWidth = parseInt(properties[kCGImagePropertyPixelWidth as String])
        let pixelHeight = parseInt(properties[kCGImagePropertyPixelHeight as String])

        var makeValues: [String] = []
        var modelValues: [String] = []
        var hasGPS = false

        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake as String] as? String { makeValues.append(make) }
            if let model = tiff[kCGImagePropertyTIFFModel as String] as? String { modelValues.append(model) }
        }
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            makeValues.append(contentsOf: DeviceMetadata.collectStringValues(from: exif, keys: DeviceMetadata.makeKeys))
            modelValues.append(contentsOf: DeviceMetadata.collectStringValues(from: exif, keys: DeviceMetadata.modelKeys))
        }
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any], !gps.isEmpty {
            hasGPS = true
        }

        makeValues.append(contentsOf: DeviceMetadata.collectStringValues(from: properties, keys: DeviceMetadata.makeKeys))
        modelValues.append(contentsOf: DeviceMetadata.collectStringValues(from: properties, keys: DeviceMetadata.modelKeys))

        let make = preferredValue(makeValues)
        let model = preferredValue(modelValues)
        let hasAppleMake = DeviceMetadata.hasAppleMake(in: makeValues)
        let hasiPhoneModel = DeviceMetadata.hasiPhoneModel(in: modelValues)

        return VideoInfo(
            path: filePath,
            name: name,
            dir: dir,
            ext: ext,
            sizeBytes: size,
            width: pixelWidth,
            height: pixelHeight,
            resolutionClass: resolutionClass(width: pixelWidth, height: pixelHeight),
            orientation: orientation(width: pixelWidth, height: pixelHeight),
            fps: 0,
            durationSec: 0,
            codec: "",
            container: ext,
            make: make,
            model: model,
            hasAppleMake: hasAppleMake,
            hasiPhoneModel: hasiPhoneModel,
            hasGPS: hasGPS,
            creationTime: nil,
            error: nil
        )
    }

    private static func enrichWithExiftool(path: String, existing: VideoInfo) async -> VideoInfo? {
        let candidates = ["/opt/homebrew/bin/exiftool", "/usr/local/bin/exiftool"]
        guard let exiftool = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }
        do {
            let output = try await ProcessRunner.run(
                executablePath: exiftool,
                arguments: ["-json", "-n", "-Make", "-Model", "-DeviceModelName", "-CameraModelName", "-GPSLatitude", path],
                timeout: 30
            )
            guard let data = output.stdout.data(using: .utf8),
                  let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = array.first else {
                return nil
            }
            var info = existing
            let make = (first["Make"] as? String) ?? info.make
            let model = (first["Model"] as? String)
                ?? (first["DeviceModelName"] as? String)
                ?? (first["CameraModelName"] as? String)
                ?? info.model
            let makeValues = [make, info.make].filter { !$0.isEmpty }
            let modelValues = [model, info.model].filter { !$0.isEmpty }
            info.make = preferredValue(makeValues)
            info.model = preferredValue(modelValues)
            info.hasAppleMake = DeviceMetadata.hasAppleMake(in: makeValues)
            info.hasiPhoneModel = DeviceMetadata.hasiPhoneModel(in: modelValues)
            if first["GPSLatitude"] != nil {
                info.hasGPS = true
            }
            return info
        } catch {
            return nil
        }
    }

    private static func preferredValue(_ values: [String]) -> String {
        values.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }

    private static func stringValues(matching tags: [String: Any], where predicate: (String) -> Bool) -> [String] {
        tags.compactMap { key, value in
            guard predicate(key), let string = value as? String, !string.isEmpty else { return nil }
            return string
        }
    }

    private static func parseInt(_ value: Any?) -> Int {
        if let n = value as? Int { return n }
        if let n = value as? Int64 { return Int(n) }
        if let s = value as? String, let n = Int(s) { return n }
        return 0
    }

    private static func parseDouble(_ value: String?) -> Double? {
        guard let value = value else { return nil }
        return Double(value)
    }

    private static func parseFps(_ value: String?) -> Double {
        guard let value = value, value.contains("/") else { return 0 }
        let parts = value.split(separator: "/")
        guard parts.count == 2,
              let n = Double(parts[0]),
              let d = Double(parts[1]), d != 0 else { return 0 }
        return n / d
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value = value else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }

    /// Six-tier buckets from the L!bra contract. First match wins on `long = max(w, h)`:
    /// 4K (≥3840) → 1080p (±2 of 1920) → 720p (±2 of 1280) → FHD (>1920) → HD (>720) → SD.
    private static func resolutionClass(width: Int, height: Int) -> String {
        guard width > 0, height > 0 else { return "Unknown" }
        let long = max(width, height)
        if long >= 3840 { return "4K" }
        if abs(long - 1920) <= 2 { return "1080p" }
        if abs(long - 1280) <= 2 { return "720p" }
        if long > 1920 { return "FHD" }
        if long > 720 { return "HD" }
        return "SD"
    }

    private static func orientation(width: Int, height: Int) -> String {
        if width > height { return "landscape" }
        if height > width { return "portrait" }
        return "square"
    }
}
