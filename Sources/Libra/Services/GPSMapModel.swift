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

    var photoCount: Int {
        let images = Set(AppSettings.default.imageExtensions)
        return files.filter { images.contains($0.ext.lowercased()) }.count
    }

    var videoCount: Int {
        files.count - photoCount
    }

    var mediaCountLabel: String {
        GPSMediaCounts.label(photos: photoCount, videos: videoCount)
    }

    var pinTitle: String {
        if let placeName, !placeName.isEmpty {
            return "\(placeName) · \(mediaCountLabel)"
        }
        return mediaCountLabel
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
        // Re-apply any city merges already known from prior geocodes.
        clusters = GPSMapClustering.mergeByPlaceName(clusters)
        cameraPosition = GPSMapClustering.fittingPosition(for: clusters)
        if let selectedClusterID, !clusters.contains(where: { $0.id == selectedClusterID }) {
            self.selectedClusterID = nil
        }
        startGeocodingIfNeeded()
    }
}

enum GPSMediaCounts {
    static func label(photos: Int, videos: Int) -> String {
        let photoText = photos == 1 ? "1 photo" : "\(photos) photos"
        let videoText = videos == 1 ? "1 video" : "\(videos) videos"
        return "\(photoText), \(videoText)"
    }

    static func totals(in files: [VideoInfo]) -> (photos: Int, videos: Int) {
        let images = Set(AppSettings.default.imageExtensions)
        var photos = 0
        var videos = 0
        for file in files {
            if images.contains(file.ext.lowercased()) {
                photos += 1
            } else {
                videos += 1
            }
        }
        return (photos, videos)
    }
}

enum GPSMapClustering {
    /// Pins within this radius share one map marker and one media count.
    static let proximityMeters: CLLocationDistance = 5 * 1609.344

    static func cluster(files: [VideoInfo]) -> [GPSLocationCluster] {
        struct Point {
            let file: VideoInfo
            let location: CLLocation
        }

        let points: [Point] = files.compactMap { file in
            guard file.hasCoordinates, let lat = file.latitude, let lon = file.longitude else { return nil }
            return Point(file: file, location: CLLocation(latitude: lat, longitude: lon))
        }
        .sorted { $0.file.path < $1.file.path }

        // Greedy assign each file to the nearest open cluster within 5 miles.
        var working: [(latSum: Double, lonSum: Double, files: [VideoInfo])] = []
        for point in points {
            var bestIndex: Int?
            var bestDistance = proximityMeters
            for (index, cluster) in working.enumerated() {
                let count = Double(cluster.files.count)
                let centroid = CLLocation(
                    latitude: cluster.latSum / count,
                    longitude: cluster.lonSum / count
                )
                let distance = point.location.distance(from: centroid)
                if distance <= proximityMeters, distance <= bestDistance {
                    bestDistance = distance
                    bestIndex = index
                }
            }
            if let bestIndex {
                working[bestIndex].latSum += point.location.coordinate.latitude
                working[bestIndex].lonSum += point.location.coordinate.longitude
                working[bestIndex].files.append(point.file)
            } else {
                working.append((
                    latSum: point.location.coordinate.latitude,
                    lonSum: point.location.coordinate.longitude,
                    files: [point.file]
                ))
            }
        }

        // Merge any clusters whose centroids ended up within 5 miles of each other.
        working = mergeNearbyClusters(working)

        return working.map { cluster in
            let count = Double(cluster.files.count)
            let latitude = cluster.latSum / count
            let longitude = cluster.lonSum / count
            return GPSLocationCluster(
                id: clusterID(latitude: latitude, longitude: longitude),
                latitude: latitude,
                longitude: longitude,
                files: cluster.files.sorted { $0.path < $1.path },
                placeName: nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.files.count != rhs.files.count { return lhs.files.count > rhs.files.count }
            return lhs.id < rhs.id
        }
    }

    /// Stable key for a cluster centroid (used by tests + geocode cache).
    static func clusterKey(latitude: Double, longitude: Double) -> String {
        clusterID(latitude: latitude, longitude: longitude)
    }

    private static func clusterID(latitude: Double, longitude: Double) -> String {
        // ~100 m precision — plenty for a 5-mile blob, stable across tiny centroid drift.
        String(format: "%.3f,%.3f", latitude, longitude)
    }

    private static func mergeNearbyClusters(
        _ input: [(latSum: Double, lonSum: Double, files: [VideoInfo])]
    ) -> [(latSum: Double, lonSum: Double, files: [VideoInfo])] {
        var clusters = input
        var merged = true
        while merged {
            merged = false
            outer: for i in 0..<clusters.count {
                for j in (i + 1)..<clusters.count {
                    let leftCount = Double(clusters[i].files.count)
                    let rightCount = Double(clusters[j].files.count)
                    let left = CLLocation(
                        latitude: clusters[i].latSum / leftCount,
                        longitude: clusters[i].lonSum / leftCount
                    )
                    let right = CLLocation(
                        latitude: clusters[j].latSum / rightCount,
                        longitude: clusters[j].lonSum / rightCount
                    )
                    if left.distance(from: right) <= proximityMeters {
                        clusters[i].latSum += clusters[j].latSum
                        clusters[i].lonSum += clusters[j].lonSum
                        clusters[i].files.append(contentsOf: clusters[j].files)
                        clusters.remove(at: j)
                        merged = true
                        break outer
                    }
                }
            }
        }
        return clusters
    }

    /// Collapse pins that reverse-geocode to the same city (e.g. two 5-mi blobs in Boise).
    static func mergeByPlaceName(_ input: [GPSLocationCluster]) -> [GPSLocationCluster] {
        var unnamed: [GPSLocationCluster] = []
        var byPlace: [String: [GPSLocationCluster]] = [:]
        for cluster in input {
            guard let place = cluster.placeName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !place.isEmpty else {
                unnamed.append(cluster)
                continue
            }
            byPlace[place, default: []].append(cluster)
        }

        var merged: [GPSLocationCluster] = unnamed
        for (place, group) in byPlace {
            if group.count == 1 {
                merged.append(group[0])
                continue
            }
            let files = group.flatMap(\.files).sorted { $0.path < $1.path }
            let weight = Double(max(files.count, 1))
            let latitude = group.reduce(0.0) { $0 + $1.latitude * Double($1.files.count) } / weight
            let longitude = group.reduce(0.0) { $0 + $1.longitude * Double($1.files.count) } / weight
            merged.append(
                GPSLocationCluster(
                    id: "city:\(place)",
                    latitude: latitude,
                    longitude: longitude,
                    files: files,
                    placeName: place
                )
            )
        }

        return merged.sorted { lhs, rhs in
            if lhs.files.count != rhs.files.count { return lhs.files.count > rhs.files.count }
            return lhs.id < rhs.id
        }
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
                let name = await GPSGeocoder.reverseGeocode(latitude: cluster.latitude, longitude: cluster.longitude)
                guard let self, !Task.isCancelled else { return }
                if let name {
                    self.placeNameCache[cluster.id] = name
                    if let index = self.clusters.firstIndex(where: { $0.id == cluster.id }) {
                        self.clusters[index].placeName = name
                    }
                    // Same city name → one pin with a combined count.
                    self.clusters = GPSMapClustering.mergeByPlaceName(self.clusters)
                    for merged in self.clusters where merged.placeName != nil {
                        self.placeNameCache[merged.id] = merged.placeName
                    }
                    if let selectedClusterID = self.selectedClusterID,
                       !self.clusters.contains(where: { $0.id == selectedClusterID }) {
                        self.selectedClusterID = nil
                    }
                    self.cameraPosition = GPSMapClustering.fittingPosition(for: self.clusters)
                }
                // Be gentle with Apple's geocoder.
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }
}
