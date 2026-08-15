import CoreGraphics
import Foundation

/// Resolution buckets and display orientation. Independent of how metadata was probed.
enum MediaClassification {
    /// First match wins on `long = max(w, h)`:
    /// 8K (≥7680) → 4K (≥3840) → 1080p (±2 of 1920) → 720p (±2 of 1280) → FHD (>1920) → HD (>720) → SD.
    static func resolutionClass(width: Int, height: Int) -> String {
        guard width > 0, height > 0 else { return "Unknown" }
        let long = max(width, height)
        if long >= 7680 { return "8K" }
        if long >= 3840 { return "4K" }
        if abs(long - 1920) <= 2 { return "1080p" }
        if abs(long - 1280) <= 2 { return "720p" }
        if long > 1920 { return "FHD" }
        if long > 720 { return "HD" }
        return "SD"
    }

    static func orientation(width: Int, height: Int) -> String {
        if width > height { return "landscape" }
        if height > width { return "portrait" }
        if width == 0 && height == 0 { return "Unknown" }
        return "square"
    }

    /// Size after applying the video track’s preferred transform (portrait iPhone, etc.).
    static func displayedSize(
        naturalWidth: CGFloat,
        naturalHeight: CGFloat,
        transform: CGAffineTransform
    ) -> (width: Int, height: Int) {
        let rect = CGRect(x: 0, y: 0, width: naturalWidth, height: naturalHeight).applying(transform)
        return (Int(abs(rect.width).rounded()), Int(abs(rect.height).rounded()))
    }
}

enum FilenameStyle: String, CaseIterable, Identifiable {
    case keepOriginal
    case libraFormat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keepOriginal: return "Keep original names"
        case .libraFormat: return "Use L!bra format"
        }
    }
}

enum FolderDepth: String, CaseIterable, Identifiable {
    case none
    case resolution
    case resolutionOrientation
    case resolutionOrientationFps

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .resolution: return "Resolution"
        case .resolutionOrientation: return "Resolution + orientation"
        case .resolutionOrientationFps: return "Resolution + orientation + FPS"
        }
    }

    var detail: String {
        switch self {
        case .none: return "Rename only."
        case .resolution: return "Sort into resolution folders."
        case .resolutionOrientation: return "Sort into resolution and orientation folders."
        case .resolutionOrientationFps: return "Sort into resolution, orientation, and frame-rate folders."
        }
    }
}

enum OrganizeLayout {
    static func folderComponents(
        depth: FolderDepth,
        resolutionClass: String,
        orientation: String,
        fpsBucket: Int
    ) -> [String] {
        switch depth {
        case .none:
            return []
        case .resolution:
            return [resolutionClass]
        case .resolutionOrientation:
            return [resolutionClass, orientation.capitalized]
        case .resolutionOrientationFps:
            return [resolutionClass, orientation.capitalized, "\(fpsBucket)fps"]
        }
    }

    static func filenameStyle(for tool: Tool) -> FilenameStyle {
        tool == .keepName ? .keepOriginal : .libraFormat
    }

    static func folderDepth(for tool: Tool) -> FolderDepth {
        switch tool {
        case .provid: return .none
        case .vidres, .keepName: return .resolution
        case .promax: return .resolutionOrientation
        case .maxvid: return .resolutionOrientationFps
        default: return .none
        }
    }
}
