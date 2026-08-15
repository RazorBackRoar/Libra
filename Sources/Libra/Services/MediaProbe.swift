import AVFoundation
import CoreMedia
import Foundation
import ImageIO

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

enum MediaProbe {
    static func probe(filePath: String) async throws -> VideoInfo {
        try Task.checkCancellation()
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
            return probeImage(filePath: filePath, name: name, dir: dir, ext: ext, size: size)
        }
        return try await probeVideoWithTimeout(
            filePath: filePath,
            url: url,
            name: name,
            dir: dir,
            ext: ext,
            size: size
        )
    }

    private static func probeVideoWithTimeout(
        filePath: String,
        url: URL,
        name: String,
        dir: String,
        ext: String,
        size: Int64
    ) async throws -> VideoInfo {
        try await withThrowingTaskGroup(of: VideoInfo.self) { group in
            group.addTask {
                try await probeVideo(
                    filePath: filePath,
                    url: url,
                    name: name,
                    dir: dir,
                    ext: ext,
                    size: size
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                throw ProbeFailure.timedOut
            }
            do {
                let result = try await group.next()!
                group.cancelAll()
                return result
            } catch is CancellationError {
                group.cancelAll()
                throw CancellationError()
            } catch ProbeFailure.timedOut {
                group.cancelAll()
                return failedVideoInfo(
                    filePath: filePath,
                    name: name,
                    dir: dir,
                    ext: ext,
                    size: size,
                    error: "Metadata probe timed out"
                )
            } catch {
                group.cancelAll()
                return failedVideoInfo(
                    filePath: filePath,
                    name: name,
                    dir: dir,
                    ext: ext,
                    size: size,
                    error: "Could not read video metadata"
                )
            }
        }
    }

    private static func probeVideo(
        filePath: String,
        url: URL,
        name: String,
        dir: String,
        ext: String,
        size: Int64
    ) async throws -> VideoInfo {
        do {
            try Task.checkCancellation()
            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                return failedVideoInfo(
                    filePath: filePath,
                    name: name,
                    dir: dir,
                    ext: ext,
                    size: size,
                    error: "Could not read video metadata"
                )
            }

            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let displayed = MediaClassification.displayedSize(
                naturalWidth: naturalSize.width,
                naturalHeight: naturalSize.height,
                transform: transform
            )
            let fps = Double(try await track.load(.nominalFrameRate))
            let duration = try await asset.load(.duration)
            let durationSec = duration.isNumeric ? CMTimeGetSeconds(duration) : 0
            let formatDescriptions = try await track.load(.formatDescriptions)
            let codec = codecName(from: formatDescriptions.first)

            var makeValues: [String] = []
            var modelValues: [String] = []
            var locationStrings: [String] = []
            var creation: Date?

            let metadataGroups = try await loadMetadata(from: asset)
            for item in metadataGroups {
                try Task.checkCancellation()
                let identifier = item.identifier?.rawValue.lowercased() ?? ""
                let common = item.commonKey?.rawValue.lowercased() ?? ""
                let string = await metadataString(item)
                let date = await metadataDate(item)

                if creation == nil, let date {
                    creation = date
                } else if creation == nil, identifier.contains("creation") || common.contains("creation") {
                    creation = parseDate(string)
                }

                if !string.isEmpty {
                    if identifier.contains("make") || common == "make" || identifier.hasSuffix(".make") {
                        makeValues.append(string)
                    }
                    if identifier.contains("model") || common == "model" {
                        modelValues.append(string)
                    }
                    if identifier.contains("location") || identifier.contains("iso6709") || common.contains("location") {
                        locationStrings.append(string)
                    }
                }
            }

            if let make = await metadataString(metadataGroups, identifier: .quickTimeMetadataMake) {
                makeValues.insert(make, at: 0)
            }
            if let model = await metadataString(metadataGroups, identifier: .quickTimeMetadataModel) {
                modelValues.insert(model, at: 0)
            }
            if let loc = await metadataString(metadataGroups, identifier: .quickTimeMetadataLocationISO6709) {
                locationStrings.insert(loc, at: 0)
            }
            if creation == nil {
                creation = await metadataDate(metadataGroups, identifier: .commonIdentifierCreationDate)
            }
            if creation == nil {
                creation = await metadataDate(metadataGroups, identifier: .quickTimeMetadataCreationDate)
            }

            var latitude: Double?
            var longitude: Double?
            for raw in locationStrings {
                if let coords = GPSCoordinateParser.parseISO6709(raw) {
                    latitude = coords.latitude
                    longitude = coords.longitude
                    break
                }
            }

            if creation == nil {
                creation = fileSystemCreationDate(filePath)
            }

            let make = preferredValue(makeValues)
            let model = preferredValue(modelValues)
            let hasAppleMake = DeviceMetadata.hasAppleMake(in: makeValues)
            let hasiPhoneModel = DeviceMetadata.hasiPhoneModel(in: modelValues + makeValues)

            return VideoInfo(
                path: filePath,
                name: name,
                dir: dir,
                ext: ext,
                sizeBytes: size,
                width: displayed.width,
                height: displayed.height,
                resolutionClass: MediaClassification.resolutionClass(width: displayed.width, height: displayed.height),
                orientation: MediaClassification.orientation(width: displayed.width, height: displayed.height),
                fps: fps,
                durationSec: durationSec.isFinite ? durationSec : 0,
                codec: codec,
                container: ext,
                make: make,
                model: model,
                hasAppleMake: hasAppleMake,
                hasiPhoneModel: hasiPhoneModel,
                hasGPS: latitude != nil,
                latitude: latitude,
                longitude: longitude,
                creationTime: creation,
                error: nil,
                warning: nil
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return failedVideoInfo(
                filePath: filePath,
                name: name,
                dir: dir,
                ext: ext,
                size: size,
                error: "Could not read video metadata"
            )
        }
    }

    private static func loadMetadata(from asset: AVURLAsset) async throws -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []
        items.append(contentsOf: (try? await asset.load(.metadata)) ?? [])
        items.append(contentsOf: (try? await asset.loadMetadata(for: .quickTimeMetadata)) ?? [])
        items.append(contentsOf: (try? await asset.loadMetadata(for: .iTunesMetadata)) ?? [])
        items.append(contentsOf: (try? await asset.loadMetadata(for: .isoUserData)) ?? [])
        return items
    }

    private static func metadataString(_ items: [AVMetadataItem], identifier: AVMetadataIdentifier) async -> String? {
        let matches = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier)
        for item in matches {
            let value = await metadataString(item)
            if !value.isEmpty { return value }
        }
        return nil
    }

    private static func metadataDate(_ items: [AVMetadataItem], identifier: AVMetadataIdentifier) async -> Date? {
        let matches = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier)
        for item in matches {
            if let date = await metadataDate(item) { return date }
        }
        return nil
    }

    private static func metadataString(_ item: AVMetadataItem) async -> String {
        (try? await item.load(.stringValue)) ?? ""
    }

    private static func metadataDate(_ item: AVMetadataItem) async -> Date? {
        if let loaded = try? await item.load(.dateValue) {
            return loaded
        }
        let string = await metadataString(item)
        if !string.isEmpty {
            return parseDate(string)
        }
        return nil
    }

    private static func codecName(from description: CMFormatDescription?) -> String {
        guard let description else { return "" }
        let fourCC = CMFormatDescriptionGetMediaSubType(description)
        let raw = fourCCString(fourCC).lowercased()
        switch raw {
        case "avc1", "avc3": return "h264"
        case "hvc1", "hev1": return "hevc"
        case "mp4v": return "mpeg4"
        case "vp09": return "vp9"
        case "av01": return "av1"
        default: return raw
        }
    }

    private static func fourCCString(_ value: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? ""
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
            error: error,
            warning: nil
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
                creationTime: fileSystemCreationDate(filePath),
                error: message,
                warning: nil
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
        var latitude: Double?
        var longitude: Double?

        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake as String] as? String { makeValues.append(make) }
            if let model = tiff[kCGImagePropertyTIFFModel as String] as? String { modelValues.append(model) }
        }
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            makeValues.append(contentsOf: DeviceMetadata.collectStringValues(from: exif, keys: DeviceMetadata.makeKeys))
            modelValues.append(contentsOf: DeviceMetadata.collectStringValues(from: exif, keys: DeviceMetadata.modelKeys))
        }
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any], !gps.isEmpty {
            if let coords = GPSCoordinateParser.coordinates(fromImageIOGPS: gps) {
                latitude = coords.latitude
                longitude = coords.longitude
            }
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
            resolutionClass: MediaClassification.resolutionClass(width: pixelWidth, height: pixelHeight),
            orientation: MediaClassification.orientation(width: pixelWidth, height: pixelHeight),
            fps: 0,
            durationSec: 0,
            codec: "",
            container: ext,
            make: make,
            model: model,
            hasAppleMake: hasAppleMake,
            hasiPhoneModel: hasiPhoneModel,
            hasGPS: latitude != nil,
            latitude: latitude,
            longitude: longitude,
            creationTime: imageCreationDate(properties: properties, filePath: filePath),
            error: nil,
            warning: nil
        )
    }

    private static func imageCreationDate(properties: [String: Any], filePath: String) -> Date? {
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let raw = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String,
           let date = parseExifDate(raw) {
            return date
        }
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let raw = tiff[kCGImagePropertyTIFFDateTime as String] as? String,
           let date = parseExifDate(raw) {
            return date
        }
        return fileSystemCreationDate(filePath)
    }

    private static func fileSystemCreationDate(_ path: String) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return attrs?[.creationDate] as? Date
    }

    private static func preferredValue(_ values: [String]) -> String {
        values.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }

    private static func parseInt(_ value: Any?) -> Int {
        if let n = value as? Int { return n }
        if let n = value as? Int64 { return Int(n) }
        if let s = value as? String, let n = Int(s) { return n }
        return 0
    }

    private static func parseDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }
        return parseExifDate(value)
    }

    private static func parseExifDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        if let date = formatter.date(from: raw) { return date }
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: raw)
    }

    private enum ProbeFailure: Error {
        case timedOut
    }
}
