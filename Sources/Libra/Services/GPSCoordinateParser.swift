import Foundation
import ImageIO

enum GPSCoordinateParser {
    struct Coordinates: Equatable {
        let latitude: Double
        let longitude: Double
    }

    static func coordinates(fromImageIOGPS gps: [String: Any]) -> Coordinates? {
        guard let lat = doubleValue(gps[kCGImagePropertyGPSLatitude as String]),
              let lon = doubleValue(gps[kCGImagePropertyGPSLongitude as String]) else {
            return nil
        }
        let latRef = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N").uppercased()
        let lonRef = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E").uppercased()
        let signedLat = latRef == "S" ? -abs(lat) : abs(lat)
        let signedLon = lonRef == "W" ? -abs(lon) : abs(lon)
        return validated(latitude: signedLat, longitude: signedLon)
    }

    static func coordinates(fromExiftool fields: [String: Any]) -> Coordinates? {
        guard let lat = doubleValue(fields["GPSLatitude"]),
              let lon = doubleValue(fields["GPSLongitude"]) else {
            return nil
        }
        return validated(latitude: lat, longitude: lon)
    }

    static func coordinates(fromFfprobeTags tags: [String: Any]) -> Coordinates? {
        let keys = [
            "com.apple.quicktime.location.ISO6709",
            "location",
            "location-eng",
            "com.apple.quicktime.location.name"
        ]
        for key in keys {
            if let value = tags[key] as? String,
               let coords = parseISO6709(value) {
                return coords
            }
        }
        for (key, value) in tags {
            let lower = key.lowercased()
            guard lower.contains("location") || lower.contains("iso6709"),
                  let string = value as? String,
                  let coords = parseISO6709(string) else { continue }
            return coords
        }
        return nil
    }

    /// Parses QuickTime-style ISO 6709 strings such as `+37.3349-122.0090/` or `+37.33-122.00+12.0/`.
    static func parseISO6709(_ raw: String) -> Coordinates? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(
            pattern: #"([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)"#
        ) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              match.numberOfRanges >= 3,
              let latRange = Range(match.range(at: 1), in: trimmed),
              let lonRange = Range(match.range(at: 2), in: trimmed),
              let lat = Double(trimmed[latRange]),
              let lon = Double(trimmed[lonRange]) else {
            return nil
        }
        return validated(latitude: lat, longitude: lon)
    }

    private static func validated(latitude: Double, longitude: Double) -> Coordinates? {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        // Reject the all-zero placeholder some cameras emit.
        if abs(latitude) < 0.00001, abs(longitude) < 0.00001 { return nil }
        return Coordinates(latitude: latitude, longitude: longitude)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let n = value as? Double { return n }
        if let n = value as? Float { return Double(n) }
        if let n = value as? Int { return Double(n) }
        if let n = value as? Int64 { return Double(n) }
        if let s = value as? String { return Double(s) }
        return nil
    }
}
