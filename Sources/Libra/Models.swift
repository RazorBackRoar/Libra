import Foundation

struct VideoInfo: Identifiable, Equatable {
    let id = UUID()
    var path: String
    var name: String
    var dir: String
    var ext: String
    var sizeBytes: Int64
    var width: Int
    var height: Int
    var resolutionClass: String
    var orientation: String
    var fps: Double
    var durationSec: Double
    var codec: String
    var container: String
    var make: String
    var model: String
    var isApple: Bool
    var hasGPS: Bool
    var creationTime: Date?
    var error: String?

    var isReencodeCandidate: Bool {
        let containerOk = container.lowercased().contains("mp4")
        let codecOk = codec.lowercased().contains("h264") || codec.lowercased().contains("h265") || codec.lowercased().contains("hevc")
        return !(containerOk && codecOk)
    }

    var resolutionFolder: String { resolutionClass }
    var orientationFolder: String { orientation.capitalized }

    static func == (lhs: VideoInfo, rhs: VideoInfo) -> Bool {
        lhs.path == rhs.path
    }
}

enum SortMode: String, CaseIterable, Identifiable {
    case provid = "ProVid"
    case vidres = "VidRes"
    case promax = "ProMax"
    case maxvid = "MaxVid"
    case keepName = "KeepName"

    var id: String { rawValue }
}

enum Tool: String, CaseIterable, Identifiable, Hashable {
    case organizer = "Organizer"
    case provid = "ProVid"
    case vidres = "VidRes"
    case promax = "ProMax"
    case maxvid = "MaxVid"
    case keepName = "KeepName"
    case reencode = "Re-encode"
    case oneMin = "1MinVid"
    case slomo = "Slo-Mo"
    case duplicates = "Duplicates"
    case gps = "GPS Sorter"
    case codec = "Codec"

    var id: String { rawValue }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .organizer: return "film.stack"
        case .provid: return "text.badge.checkmark"
        case .vidres: return "rectangle.split.3x3"
        case .promax: return "rectangle.portrait.rotate"
        case .maxvid: return "waveform"
        case .keepName: return "doc.text"
        case .reencode: return "arrow.triangle.2.circlepath"
        case .oneMin: return "clock.arrow.circlepath"
        case .slomo: return "slowmo"
        case .duplicates: return "doc.on.doc"
        case .gps: return "location.circle"
        case .codec: return "info.circle"
        }
    }

    var description: String {
        switch self {
        case .organizer: return "Filter, organize, review duplicates, and inspect rich video metadata."
        case .provid: return "Rename videos in place with an optional prefix."
        case .vidres: return "Sort videos into resolution folders."
        case .promax: return "Sort into resolution + orientation folders."
        case .maxvid: return "Sort into resolution + orientation + FPS folders."
        case .keepName: return "Sort into folders while keeping original filenames."
        case .reencode: return "Flag videos not in H.264/HEVC MP4."
        case .oneMin: return "Apply sequential 60-second timestamps."
        case .slomo: return "Create slow-motion copies with ffmpeg."
        case .duplicates: return "Find exact MD5 duplicate videos."
        case .gps: return "Sort into GPS / No-GPS folders."
        case .codec: return "Read-only ffprobe codec report."
        }
    }

    var category: String {
        switch self {
        case .organizer, .duplicates, .codec, .reencode, .gps:
            return "Analyze"
        case .provid, .vidres, .promax, .maxvid, .keepName:
            return "Sort / Rename"
        case .oneMin, .slomo:
            return "Transform"
        }
    }
}

struct OperationResult: Identifiable, Equatable {
    let id = UUID()
    var path: String
    var status: OperationStatus
    var reason: String?
    var outputPath: String?
}

enum OperationStatus: String, Equatable {
    case success = "Success"
    case failed = "Failed"
    case skipped = "Skipped"
    case pending = "Pending"
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    var hash: String
    var files: [VideoInfo]
}

struct AppSettings: Codable {
    var ffmpegPath: String?
    var ffprobePath: String?
    var videoExtensions: [String]
    var dryRunDefault: Bool
    var lastFolder: String?

    static let `default` = AppSettings(
        ffmpegPath: nil,
        ffprobePath: nil,
        videoExtensions: ["mp4", "mov", "m4v", "mkv", "avi", "mts", "m2ts", "3gp", "webm"],
        dryRunDefault: true,
        lastFolder: nil
    )
}
