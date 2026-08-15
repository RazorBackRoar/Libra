import Foundation

/// Canonical output filename builder used by every L!bra processing mode.
///
/// Format: `OriginalName Resolution V|S|WFPS [🍎][📱][🌍] NNN.ext`
/// Example: `Vacation 4K W30 🍎📱🌍 001.mov`
///
/// A non-empty prefix replaces the original name (with a space after it):
/// `katie 720p W30 002.mp4` — not `katie 1E8B0D0F-… 720p W30 002.mp4`.
enum FileNaming {
    static let resolutionClasses = ["8K", "4K", "1440p", "FHD", "1080p", "HD", "720p", "SD"]
    static let fpsBuckets = [24, 30, 60, 120]

    /// Zero-pad width: at least 3 digits (`001`), growing for larger batches.
    static func paddingWidth(forCount count: Int) -> Int {
        max(3, String(max(count, 1)).count)
    }

    /// Map raw FPS into the nearest contract bucket: 30, 60, or 120.
    static func fpsBucket(_ fps: Double) -> Int {
        guard fps > 0 else { return 30 }
        return fpsBuckets.min(by: { abs(Double($0) - fps) < abs(Double($1) - fps) }) ?? 30
    }

    /// Portrait → `V`, square → `S`, landscape/unknown → `W`.
    static func orientationCode(_ orientation: String) -> String {
        switch orientation.lowercased() {
        case "portrait": return "V"
        case "square": return "S"
        default: return "W"
        }
    }

    /// Resolve a probed resolution class into a contract label.
    static func resolutionLabel(_ resolutionClass: String) -> String {
        if resolutionClasses.contains(resolutionClass) { return resolutionClass }
        return "SD"
    }

    /// Metadata icons in fixed order: Apple Make, iPhone Model, GPS.
    static func metadataMarkers(hasAppleMake: Bool, hasiPhoneModel: Bool, hasGPS: Bool) -> String {
        var markers = ""
        if hasAppleMake { markers += "🍎" }
        if hasiPhoneModel { markers += "📱" }
        if hasGPS { markers += "🌍" }
        return markers
    }

    /// Build a standard filename. Optional `prefix` is prepended when non-empty.
    static func standardFileName(
        originalName: String,
        prefix: String = "",
        resolutionClass: String,
        orientation: String,
        fps: Double,
        hasAppleMake: Bool,
        hasiPhoneModel: Bool,
        hasGPS: Bool,
        index: Int,
        padWidth: Int,
        ext: String
    ) -> String {
        var parts: [String] = []
        let cleanedPrefix = FileOps.sanitizeFileName(prefix.trimmingCharacters(in: .whitespacesAndNewlines))
        let hasPrefix = !cleanedPrefix.isEmpty && cleanedPrefix != "file"
        if hasPrefix {
            parts.append(cleanedPrefix)
        } else {
            parts.append(FileOps.sanitizeFileName(originalName))
        }
        parts.append(resolutionLabel(resolutionClass))
        parts.append("\(orientationCode(orientation))\(fpsBucket(fps))")
        let markers = metadataMarkers(
            hasAppleMake: hasAppleMake,
            hasiPhoneModel: hasiPhoneModel,
            hasGPS: hasGPS
        )
        if !markers.isEmpty {
            parts.append(markers)
        }
        parts.append(String(format: "%0\(padWidth)d", index))
        let stem = FileOps.sanitizeFileName(parts.joined(separator: " "))
        return "\(stem).\(ext.lowercased())"
    }

    static func standardFileName(for file: VideoInfo, prefix: String = "", index: Int, padWidth: Int) -> String {
        standardFileName(
            originalName: file.name,
            prefix: prefix,
            resolutionClass: file.resolutionClass,
            orientation: file.orientation,
            fps: file.fps,
            hasAppleMake: file.hasAppleMake,
            hasiPhoneModel: file.hasiPhoneModel,
            hasGPS: file.hasGPS,
            index: index,
            padWidth: padWidth,
            ext: file.ext
        )
    }
}
