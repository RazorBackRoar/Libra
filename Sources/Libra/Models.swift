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
    /// Nonfatal metadata issue that did not block the probe.
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
    static let resolutionClasses = ["8K", "4K", "FHD", "1080p", "HD", "720p", "SD"]

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

    var title: String {
        switch self {
        case .provid, .vidres, .keepName, .promax, .maxvid:
            return "Sort & rename"
        case .iphoneSorter: return "iPhone sort"
        case .gps: return "GPS sort"
        case .slomo: return "Slow motion"
        case .oneMin: return "1-minute stamps"
        }
    }

    /// Home Video tab destinations. The five sort modes share one card.
    static let videoHomeTools: [Tool] = [.provid, .iphoneSorter, .gps, .slomo, .oneMin]

    var isSortRenameFamily: Bool {
        switch self {
        case .provid, .vidres, .keepName, .promax, .maxvid: return true
        default: return false
        }
    }

    var systemImage: String {
        switch self {
        case .iphoneSorter: return "iphone"
        case .provid, .vidres, .keepName, .promax, .maxvid: return "text.badge.checkmark"
        case .oneMin: return "clock.arrow.circlepath"
        case .slomo: return "slowmo"
        case .gps: return "location.circle"
        }
    }

    var description: String {
        switch self {
        case .iphoneSorter: return "Split videos into iPhone, Other Apple, and Not Apple folders."
        case .provid, .vidres, .keepName, .promax, .maxvid:
            return "Rename files, or nest folders by resolution, orientation, and FPS."
        case .oneMin: return "Stamp sequential 60-second creation times. Needs ffmpeg."
        case .slomo: return "Write slowed copies into a SloMo folder. Needs ffmpeg."
        case .gps: return "Sort into city folders from location, or No-GPS when location is missing."
        }
    }

    var category: String {
        switch self {
        case .iphoneSorter, .gps, .provid, .vidres, .promax, .maxvid, .keepName:
            return "Organize"
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
    var sortDuplicatesIntoFolder: Bool

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
        sortByCamera: false,
        sortDuplicatesIntoFolder: false
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
        sortByCamera: Bool,
        sortDuplicatesIntoFolder: Bool
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
        self.sortDuplicatesIntoFolder = sortDuplicatesIntoFolder
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
        sortDuplicatesIntoFolder = try container.decodeIfPresent(Bool.self, forKey: .sortDuplicatesIntoFolder) ?? false
    }
}
