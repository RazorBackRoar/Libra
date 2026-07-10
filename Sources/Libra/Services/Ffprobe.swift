import Foundation

enum FfprobeError: Error {
    case ffprobeNotFound
}

@MainActor
final class FfprobeService {
    private init() {}

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

        let args = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            filePath
        ]

        do {
            let output = try await ProcessRunner.run(executablePath: ffprobePath, arguments: args, timeout: 30)
            let json = try JSONSerialization.jsonObject(with: output.stdout.data(using: .utf8) ?? Data()) as? [String: Any] ?? [:]

            let format = json["format"] as? [String: Any] ?? [:]
            let streams = json["streams"] as? [[String: Any]] ?? []
            let videoStream = streams.first { ($0["codec_type"] as? String) == "video" } ?? [:]

            let width = parseInt(videoStream["width"])
            let height = parseInt(videoStream["height"])
            let duration = parseDouble(format["duration"] as? String) ?? parseDouble(videoStream["duration"] as? String)
            let fps = parseFps(videoStream["r_frame_rate"] as? String)
            let codec = videoStream["codec_name"] as? String ?? ""
            let container = format["format_name"] as? String ?? ""

            let tags = videoStream["tags"] as? [String: Any] ?? [:]
            let formatTags = format["tags"] as? [String: Any] ?? [:]
            let make = (formatTags["encoder"] as? String ?? "")
            let model = (formatTags["com.apple.quicktime.model"] as? String ?? "")
            let isApple = make.lowercased().contains("apple") || model.lowercased().contains("iphone") || model.lowercased().contains("ipad")
            let creation = parseDate(tags["creation_time"] as? String) ?? parseDate(formatTags["creation_time"] as? String)

            let hasGPS = false

            return VideoInfo(
                path: filePath,
                name: name,
                dir: dir,
                ext: ext,
                sizeBytes: size,
                width: width,
                height: height,
                resolutionClass: resolutionClass(width: width, height: height),
                orientation: orientation(width: width, height: height),
                fps: fps,
                durationSec: duration ?? 0,
                codec: codec,
                container: container,
                make: make,
                model: model,
                isApple: isApple,
                hasGPS: hasGPS,
                creationTime: creation,
                error: nil
            )
        } catch {
            return VideoInfo(
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
                isApple: false,
                hasGPS: false,
                creationTime: nil,
                error: error.localizedDescription
            )
        }
    }

    private static func parseInt(_ value: Any?) -> Int {
        if let n = value as? Int { return n }
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

    private static func resolutionClass(width: Int, height: Int) -> String {
        let pixels = max(width, height)
        if pixels >= 3840 { return "4K" }
        if pixels >= 1920 { return "1080p" }
        if pixels >= 1280 { return "720p" }
        return "SD"
    }

    private static func orientation(width: Int, height: Int) -> String {
        if width > height { return "landscape" }
        if height > width { return "portrait" }
        return "square"
    }
}
