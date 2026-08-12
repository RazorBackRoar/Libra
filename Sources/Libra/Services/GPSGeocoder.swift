import Foundation
import CoreLocation

@MainActor
enum GPSGeocoder {
    static func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CLPlacemark], Error>) in
                CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: placemarks ?? [])
                    }
                }
            }
            guard let place = placemarks.first else { return nil }
            if let locality = place.locality?.trimmingCharacters(in: .whitespacesAndNewlines), !locality.isEmpty {
                if let area = place.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines), !area.isEmpty {
                    return "\(locality), \(area)"
                }
                return locality
            }
            let parts = [place.locality, place.administrativeArea, place.country]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return parts.first
        } catch {
            return nil
        }
    }

    static func folderName(for placeName: String?) -> String {
        let raw = placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleaned = FileOps.sanitizeFileName(raw)
        return cleaned == "file" ? "GPS" : cleaned
    }
}
