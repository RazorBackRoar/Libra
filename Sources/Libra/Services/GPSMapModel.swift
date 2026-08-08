import Foundation
import CoreLocation
import MapKit
import SwiftUI

struct GPSLocationCluster: Identifiable, Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
    var files: [VideoInfo]
    var placeName: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var pinTitle: String {
        let count = files.count
        let countText = count == 1 ? "1 file" : "\(count) files"
        if let placeName, !placeName.isEmpty {
            return "\(placeName) · \(countText)"
        }
        return countText
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GPSLocationCluster, rhs: GPSLocationCluster) -> Bool {
        lhs.id == rhs.id
            && lhs.placeName == rhs.placeName
            && lhs.files.map(\.path) == rhs.files.map(\.path)
    }
}

@MainActor
final class GPSMapModel: ObservableObject {
    @Published private(set) var clusters: [GPSLocationCluster] = []
    @Published var selectedClusterID: String?
    @Published var cameraPosition: MapCameraPosition = .automatic

    private var geocodeTask: Task<Void, Never>?
    private var placeNameCache: [String: String] = [:]

    var selectedCluster: GPSLocationCluster? {
        guard let selectedClusterID else { return nil }
        return clusters.first { $0.id == selectedClusterID }
    }

    var filesWithCoordinates: Int {
        clusters.reduce(0) { $0 + $1.files.count }
    }

    func update(files: [VideoInfo]) {
        let built = GPSMapClustering.cluster(files: files)
        clusters = built.map { cluster in
            var copy = cluster
            copy.placeName = placeNameCache[cluster.id]
            return copy
        }
        cameraPosition = GPSMapClustering.fittingPosition(for: clusters)
        if let selectedClusterID, !clusters.contains(where: { $0.id == selectedClusterID }) {
            self.selectedClusterID = nil
        }
        startGeocodingIfNeeded()
    }
}

enum GPSMapClustering {
    static func cluster(files: [VideoInfo]) -> [GPSLocationCluster] {
        var buckets: [String: GPSLocationCluster] = [:]
        for file in files where file.hasCoordinates {
            guard let lat = file.latitude, let lon = file.longitude else { continue }
            let key = clusterKey(latitude: lat, longitude: lon)
            if var existing = buckets[key] {
                existing.files.append(file)
                buckets[key] = existing
            } else {
                buckets[key] = GPSLocationCluster(
                    id: key,
                    latitude: (lat * 10_000).rounded() / 10_000,
                    longitude: (lon * 10_000).rounded() / 10_000,
                    files: [file],
                    placeName: nil
                )
            }
        }
        return buckets.values.sorted { lhs, rhs in
            if lhs.files.count != rhs.files.count { return lhs.files.count > rhs.files.count }
            return lhs.id < rhs.id
        }
    }

    /// ~11 m grid — collapses near-duplicate pins from the same shoot.
    static func clusterKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.4f,%.4f", latitude, longitude)
    }

    static func fittingPosition(for clusters: [GPSLocationCluster]) -> MapCameraPosition {
        guard let first = clusters.first else { return .automatic }
        if clusters.count == 1 {
            return .region(MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ))
        }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for cluster in clusters.dropFirst() {
            minLat = min(minLat, cluster.latitude)
            maxLat = max(maxLat, cluster.latitude)
            minLon = min(minLon, cluster.longitude)
            maxLon = max(maxLon, cluster.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.05),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.05)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}

extension GPSMapModel {
    private func startGeocodingIfNeeded() {
        geocodeTask?.cancel()
        let pending = clusters.filter { placeNameCache[$0.id] == nil }
        guard !pending.isEmpty else { return }

        geocodeTask = Task { [weak self] in
            for cluster in pending {
                if Task.isCancelled { return }
                let name = await Self.reverseGeocode(latitude: cluster.latitude, longitude: cluster.longitude)
                guard let self, !Task.isCancelled else { return }
                if let name {
                    self.placeNameCache[cluster.id] = name
                    if let index = self.clusters.firstIndex(where: { $0.id == cluster.id }) {
                        self.clusters[index].placeName = name
                    }
                }
                // Be gentle with Apple's geocoder.
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private static func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
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
            let parts = [place.locality, place.administrativeArea, place.country]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if let locality = place.locality, !locality.isEmpty {
                if let area = place.administrativeArea, !area.isEmpty {
                    return "\(locality), \(area)"
                }
                return locality
            }
            return parts.first
        } catch {
            return nil
        }
    }
}
