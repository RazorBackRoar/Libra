import Foundation

/// One identification row for a scanned video or photo.
/// Filename (and its container) stay on the title line, never here.
enum MediaIdentification {
    static func line(for file: VideoInfo) -> String {
        var parts: [String] = []
        if let resolution = resolutionLabel(for: file) {
            parts.append(resolution)
        }
        if file.fps > 0 {
            // Identification rows show the probed rate; the 30/60/120 bucket
            // is for filenames only.
            let fps = file.fps
            let text = fps == fps.rounded() ? String(Int(fps)) : String(format: "%.2f", fps)
            parts.append("\(text) fps")
        }
        if let device = deviceLabel(for: file) {
            parts.append(device)
        }
        if let gps = gpsLabel(for: file) {
            parts.append(gps)
        }
        if !file.orientation.isEmpty, file.orientation != "Unknown" {
            parts.append(file.orientation)
        }
        if file.durationSec > 0 {
            parts.append(durationLabel(file.durationSec))
        }
        if file.sizeBytes > 0 {
            parts.append(sizeLabel(file.sizeBytes))
        }
        return parts.joined(separator: " · ")
    }

    static func deviceLabel(for file: VideoInfo) -> String? {
        let model = file.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let make = file.make.trimmingCharacters(in: .whitespacesAndNewlines)
        if file.hasiPhoneModel {
            if model.isEmpty { return "iPhone" }
            if model.lowercased().contains("iphone") { return model }
            return "iPhone \(model)"
        }
        if file.hasAppleMake {
            let name = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
            return name.isEmpty ? "Apple" : name
        }
        let name = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? nil : name
    }

    static func gpsLabel(for file: VideoInfo) -> String? {
        if file.hasCoordinates, let latitude = file.latitude, let longitude = file.longitude {
            return "GPS \(formatCoordinate(latitude)), \(formatCoordinate(longitude))"
        }
        if file.hasGPS {
            return "GPS"
        }
        return nil
    }

    private static func resolutionLabel(for file: VideoInfo) -> String? {
        let bucket = file.resolutionClass
        let hasBucket = !bucket.isEmpty && bucket != "Unknown"
        if file.width > 0, file.height > 0 {
            let pixels = "\(file.width)×\(file.height)"
            return hasBucket ? "\(bucket) \(pixels)" : pixels
        }
        return hasBucket ? bucket : nil
    }

    private static func durationLabel(_ seconds: Double) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    private static func sizeLabel(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }

    private static func formatCoordinate(_ value: Double) -> String {
        String(format: "%.5f", value)
    }
}
