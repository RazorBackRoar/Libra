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
    /// Decimal degrees when available from media metadata.
    var latitude: Double? = nil
    var longitude: Double? = nil
    var creationTime: Date?
    var error: String?
    /// Nonfatal metadata enrichment issue (e.g. optional exiftool failure).
    var warning: String?
    var unsupported: Bool = false

    var isImage: Bool {
        AppSettings.default.imageExtensions.contains(ext.lowercased())
    }

    var isApple: Bool { hasAppleMake || hasiPhoneModel }

    var hasCoordinates: Bool {
        guard let latitude, let longitude else { return false }
        return (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    /// Canonical resolution bucket labels (contract order).
    static let resolutionClasses = ["4K", "FHD", "1080p", "HD", "720p", "SD"]

    var resolutionFolder: String { resolutionClass }
    var orientationFolder: String { orientation.capitalized }

    static func == (lhs: VideoInfo, rhs: VideoInfo) -> Bool {
        lhs.path == rhs.path
    }
}

enum Tool: String, CaseIterable, Identifiable, Hashable {
    case provid = "ProVid"
    case vidres = "VidRes"
    case keepName = "KeepName"
    case promax = "ProMax"
    case maxvid = "MaxVid"
    case iphoneSorter = "iPhone Sorter"
    case slomo = "Slo-Mo"
    case oneMin = "1MinVid"
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
        case .iphoneSorter: return "Split videos into iPhone / Not iPhone folders."
        case .provid: return "Rename videos in place with the standard filename format and optional prefix."
        case .vidres: return "Rename and sort into resolution folders (4K, 1080p, …)."
        case .promax: return "Rename and sort into resolution + orientation folders."
        case .maxvid: return "Rename and sort into resolution + orientation + FPS folders."
        case .keepName: return "Sort into resolution folders, keeping the original filename."
        case .oneMin: return "Stamp sequential 60-second creation times (copies or in place)."
        case .slomo: return "Write slow-motion copies into a SloMo folder."
        case .gps: return "Sort into city folders from GPS, or No-GPS when there are no coordinates."
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

    var acceptsImages: Bool { false }

    var needsFfmpeg: Bool {
        switch self {
        case .slomo, .oneMin:
            return true
        default:
            return false
        }
    }

    var supportsExtraFolders: Bool {
        switch self {
        case .vidres, .keepName, .promax, .maxvid, .gps:
            return true
        default:
            return false
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

struct UndoRecord: Equatable {
    enum Kind: Equatable {
        case moved
        case createdCopy
    }

    var kind: Kind
    var originalPath: String
    var resultPath: String
}

enum OperationStatus: String, Equatable {
    case success = "Success"
    case failed = "Failed"
    case skipped = "Skipped"
    case cancelled = "Cancelled"
    case pending = "Pending"
}

struct ScanOutcome {
    enum TerminalState: Equatable {
        case completed
        case cancelled
    }

    var supported: [VideoInfo]
    var unsupported: [OperationResult]
    var discoveredTotal: Int
    var completedCount: Int
    var terminal: TerminalState
}

struct AppSettings: Codable {
    var ffmpegPath: String?
    var ffprobePath: String?
    var videoExtensions: [String]
    var imageExtensions: [String]
    var dryRunDefault: Bool
    var lastFolder: String?
    var requireConfirmToWrite: Bool
    var defaultPrefix: String
    var sortByDate: Bool
    var sortByCamera: Bool

    static let `default` = AppSettings(
        ffmpegPath: nil,
        ffprobePath: nil,
        videoExtensions: ["mp4", "mov", "m4v", "mkv", "avi", "mts", "m2ts", "3gp", "webm"],
        imageExtensions: ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "webp"],
        dryRunDefault: true,
        lastFolder: nil,
        requireConfirmToWrite: true,
        defaultPrefix: "",
        sortByDate: false,
        sortByCamera: false
    )

    init(
        ffmpegPath: String?,
        ffprobePath: String?,
        videoExtensions: [String],
        imageExtensions: [String],
        dryRunDefault: Bool,
        lastFolder: String?,
        requireConfirmToWrite: Bool,
        defaultPrefix: String,
        sortByDate: Bool,
        sortByCamera: Bool
    ) {
        self.ffmpegPath = ffmpegPath
        self.ffprobePath = ffprobePath
        self.videoExtensions = videoExtensions
        self.imageExtensions = imageExtensions
        self.dryRunDefault = dryRunDefault
        self.lastFolder = lastFolder
        self.requireConfirmToWrite = requireConfirmToWrite
        self.defaultPrefix = defaultPrefix
        self.sortByDate = sortByDate
        self.sortByCamera = sortByCamera
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ffmpegPath = try container.decodeIfPresent(String.self, forKey: .ffmpegPath)
        ffprobePath = try container.decodeIfPresent(String.self, forKey: .ffprobePath)
        videoExtensions = try container.decodeIfPresent([String].self, forKey: .videoExtensions) ?? Self.default.videoExtensions
        imageExtensions = try container.decodeIfPresent([String].self, forKey: .imageExtensions) ?? Self.default.imageExtensions
        dryRunDefault = try container.decodeIfPresent(Bool.self, forKey: .dryRunDefault) ?? true
        lastFolder = try container.decodeIfPresent(String.self, forKey: .lastFolder)
        requireConfirmToWrite = try container.decodeIfPresent(Bool.self, forKey: .requireConfirmToWrite) ?? true
        defaultPrefix = try container.decodeIfPresent(String.self, forKey: .defaultPrefix) ?? ""
        sortByDate = try container.decodeIfPresent(Bool.self, forKey: .sortByDate) ?? false
        sortByCamera = try container.decodeIfPresent(Bool.self, forKey: .sortByCamera) ?? false
    }
}
