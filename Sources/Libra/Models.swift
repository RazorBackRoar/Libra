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
    var hasAppleMake: Bool
    var hasiPhoneModel: Bool
    var hasGPS: Bool
    var creationTime: Date?
    var error: String?
    var unsupported: Bool = false

    var isApple: Bool { hasAppleMake || hasiPhoneModel }

    var resolutionFolder: String { resolutionClass }
    var orientationFolder: String { orientation.capitalized }

    static func == (lhs: VideoInfo, rhs: VideoInfo) -> Bool {
        lhs.path == rhs.path
    }
}

enum Tool: String, CaseIterable, Identifiable, Hashable {
    case iphoneSorter = "iPhone Sorter"
    case provid = "ProVid"
    case vidres = "VidRes"
    case promax = "ProMax"
    case maxvid = "MaxVid"
    case keepName = "KeepName"
    case oneMin = "1MinVid"
    case slomo = "Slo-Mo"
    case gps = "GPS Sorter"

    var id: String { rawValue }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .iphoneSorter: return "iphone"
        case .provid: return "text.badge.checkmark"
        case .vidres: return "rectangle.split.3x3"
        case .promax: return "rectangle.portrait.rotate"
        case .maxvid: return "waveform"
        case .keepName: return "doc.text"
        case .oneMin: return "clock.arrow.circlepath"
        case .slomo: return "slowmo"
        case .gps: return "location.circle"
        }
    }

    var description: String {
        switch self {
        case .iphoneSorter: return "Sort into iPhone / Not iPhone folders with Apple and iPhone metadata markers."
        case .provid: return "Rename videos in place with an optional prefix."
        case .vidres: return "Sort videos into resolution folders."
        case .promax: return "Sort into resolution + orientation folders."
        case .maxvid: return "Sort into resolution + orientation + FPS folders."
        case .keepName: return "Sort into folders while keeping original filenames."
        case .oneMin: return "Apply sequential 60-second timestamps."
        case .slomo: return "Create slow-motion copies with ffmpeg."
        case .gps: return "Sort into GPS / No-GPS folders."
        }
    }

    var category: String {
        switch self {
        case .iphoneSorter, .gps:
            return "Analyze"
        case .provid, .vidres, .promax, .maxvid, .keepName:
            return "Sort / Rename"
        case .oneMin, .slomo:
            return "Transform"
        }
    }

    var acceptsImages: Bool {
        self == .iphoneSorter
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

struct AppSettings: Codable {
    var ffmpegPath: String?
    var ffprobePath: String?
    var videoExtensions: [String]
    var imageExtensions: [String]
    var dryRunDefault: Bool
    var lastFolder: String?

    static let `default` = AppSettings(
        ffmpegPath: nil,
        ffprobePath: nil,
        videoExtensions: ["mp4", "mov", "m4v", "mkv", "avi", "mts", "m2ts", "3gp", "webm"],
        imageExtensions: ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "webp"],
        dryRunDefault: true,
        lastFolder: nil
    )

    init(
        ffmpegPath: String?,
        ffprobePath: String?,
        videoExtensions: [String],
        imageExtensions: [String],
        dryRunDefault: Bool,
        lastFolder: String?
    ) {
        self.ffmpegPath = ffmpegPath
        self.ffprobePath = ffprobePath
        self.videoExtensions = videoExtensions
        self.imageExtensions = imageExtensions
        self.dryRunDefault = dryRunDefault
        self.lastFolder = lastFolder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ffmpegPath = try container.decodeIfPresent(String.self, forKey: .ffmpegPath)
        ffprobePath = try container.decodeIfPresent(String.self, forKey: .ffprobePath)
        videoExtensions = try container.decodeIfPresent([String].self, forKey: .videoExtensions) ?? Self.default.videoExtensions
        imageExtensions = try container.decodeIfPresent([String].self, forKey: .imageExtensions) ?? Self.default.imageExtensions
        dryRunDefault = try container.decodeIfPresent(Bool.self, forKey: .dryRunDefault) ?? true
        lastFolder = try container.decodeIfPresent(String.self, forKey: .lastFolder)
    }
}
