import CoreLocation
import Foundation
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
        files.filter { MediaKinds.isImage(ext: $0.ext) }.count
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

/// Pure map view-model: owns pins, camera, and selection only. It never
/// reverse-geocodes — place names arrive from ToolState's explicit
/// "Resolve city names" action, so opening or filtering the map can never
/// contact Apple. Grouping is synchronous: files are bucketed by resolved
/// city name (or recorded spot when unnamed), with no distance math.
@MainActor
final class GPSMapModel: ObservableObject {
    @Published private(set) var clusters: [GPSLocationCluster] = []
    @Published var selectedClusterID: String?
    @Published var cameraPosition: MapCameraPosition = .automatic

    private var files: [VideoInfo] = []
    /// file.path → place name, from ToolState's explicit resolve.
    private var resolvedNames: [String: String] = [:]
    private var filter: MediaBrowserFilter = .all

    var selectedCluster: GPSLocationCluster? {
        guard let selectedClusterID else { return nil }
        return clusters.first { $0.id == selectedClusterID }
    }

    var filesWithCoordinates: Int {
        clusters.reduce(0) { $0 + $1.files.count }
    }

    /// Total coordinate-bearing files across every pin, ignoring the filter —
    /// used by the panel's summary line.
    var totalClusteredFiles: Int {
        files.filter(\.hasCoordinates).count
    }

    func update(
        files: [VideoInfo],
        resolvedNames: [String: String] = [:],
        filter: MediaBrowserFilter = .all
    ) {
        self.files = files
        self.resolvedNames = resolvedNames
        self.filter = filter
        applyVisibleClusters()
    }

    private func applyVisibleClusters() {
        let active = filter
        let visible = files.filter { $0.hasCoordinates && active.matches($0) }
        clusters = GPSMapClustering.groups(files: visible, resolvedNames: resolvedNames)
        cameraPosition = GPSMapClustering.fittingPosition(for: clusters)
        if let selectedClusterID, !clusters.contains(where: { $0.id == selectedClusterID }) {
            self.selectedClusterID = nil
        }
    }
}

enum GPSMediaCounts {
    static func label(photos: Int, videos: Int) -> String {
        let photoText = photos == 1 ? "1 photo" : "\(photos) photos"
        let videoText = videos == 1 ? "1 video" : "\(videos) videos"
        return "\(photoText), \(videoText)"
    }

    static func totals(in files: [VideoInfo]) -> (photos: Int, videos: Int) {
        var photos = 0
        var videos = 0
        for file in files {
            if MediaKinds.isImage(ext: file.ext) {
                photos += 1
            } else {
                videos += 1
            }
        }
        return (photos, videos)
    }
}

enum GPSMapClustering {
    /// Geocode granularity (~1.1 km): one Apple geocode call per distinct
    /// coordinate bucket. This is API thrift only — it never decides which
    /// files belong together; the resolved city name does.
    static func geocodeKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.2f,%.2f", latitude, longitude)
    }

    /// Stable key for a coordinate bucket (used by the geocode cache).
    static func clusterKey(latitude: Double, longitude: Double) -> String {
        geocodeKey(latitude: latitude, longitude: longitude)
    }

    /// Spot granularity (~11 m) for unresolved media: files recorded at the
    /// same spot share one pin. Different spots never merge — spots are not
    /// groups, just where the media says it was taken.
    private static func spotKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.4f,%.4f", latitude, longitude)
    }

    /// Groups coordinate-bearing files for display. Files sharing a resolved
    /// city name merge into one pin regardless of distance — the city is the
    /// grouping mechanism. Files without a resolved name keep one pin per
    /// recorded spot. Every group's files sort by creation date, then path.
    static func groups(
        files: [VideoInfo],
        resolvedNames: [String: String] = [:]
    ) -> [GPSLocationCluster] {
        let sorted =
            files
            .filter(\.hasCoordinates)
            .sorted {
                ($0.creationTime ?? .distantFuture, $0.path)
                    < ($1.creationTime ?? .distantFuture, $1.path)
            }

        var cities: [String: (latSum: Double, lonSum: Double, files: [VideoInfo])] = [:]
        var spots: [String: (latSum: Double, lonSum: Double, files: [VideoInfo])] = [:]

        for file in sorted {
            guard let lat = file.latitude, let lon = file.longitude else { continue }
            let place = resolvedNames[file.path]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let place, !place.isEmpty {
                cities[place, default: (0, 0, [])].latSum += lat
                cities[place]!.lonSum += lon
                cities[place]!.files.append(file)
            } else {
                let key = spotKey(latitude: lat, longitude: lon)
                spots[key, default: (0, 0, [])].latSum += lat
                spots[key]!.lonSum += lon
                spots[key]!.files.append(file)
            }
        }

        var clusters: [GPSLocationCluster] = []
        clusters.reserveCapacity(cities.count + spots.count)
        for (place, group) in cities {
            let count = Double(group.files.count)
            clusters.append(
                GPSLocationCluster(
                    id: "city:\(place)",
                    latitude: group.latSum / count,
                    longitude: group.lonSum / count,
                    files: group.files,
                    placeName: place
                ))
        }
        for (key, group) in spots {
            let count = Double(group.files.count)
            clusters.append(
                GPSLocationCluster(
                    id: "spot:\(key)",
                    latitude: group.latSum / count,
                    longitude: group.lonSum / count,
                    files: group.files,
                    placeName: nil
                ))
        }

        return clusters.sorted { lhs, rhs in
            if lhs.files.count != rhs.files.count { return lhs.files.count > rhs.files.count }
            return lhs.id < rhs.id
        }
    }

    static func fittingPosition(for clusters: [GPSLocationCluster]) -> MapCameraPosition {
        guard let first = clusters.first else { return .automatic }
        if clusters.count == 1 {
            return .region(
                MKCoordinateRegion(
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
