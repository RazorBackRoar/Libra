import XCTest
@testable import Libra

final class GPSCoordinateParserTests: XCTestCase {
    func testParseISO6709_basicQuickTimeLocation() {
        let coords = GPSCoordinateParser.parseISO6709("+37.3349-122.0090/")
        XCTAssertEqual(coords?.latitude ?? 0, 37.3349, accuracy: 0.0001)
        XCTAssertEqual(coords?.longitude ?? 0, -122.0090, accuracy: 0.0001)
    }

    func testParseISO6709_withAltitude() {
        let coords = GPSCoordinateParser.parseISO6709("+40.7128-74.0060+10.5/")
        XCTAssertEqual(coords?.latitude ?? 0, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(coords?.longitude ?? 0, -74.0060, accuracy: 0.0001)
    }

    func testClusterKey_stableForTinyCentroidDrift() {
        let a = GPSMapClustering.clusterKey(latitude: 37.33491, longitude: -122.00904)
        let b = GPSMapClustering.clusterKey(latitude: 37.33494, longitude: -122.00901)
        XCTAssertEqual(a, b)
    }

    func testGroups_mergeOnlyByResolvedCity() {
        // ~1.1 miles apart around Cupertino — different recorded spots stay
        // separate until they resolve to the same city name.
        let files = [
            stub(path: "/tmp/a.mov", lat: 37.3349, lon: -122.0090),
            stub(path: "/tmp/b.mov", lat: 37.3500, lon: -122.0090),
            stub(path: "/tmp/c.mov", lat: 40.0, lon: -74.0)
        ]
        let unresolved = GPSMapClustering.groups(files: files)
        XCTAssertEqual(unresolved.count, 3)
        XCTAssertTrue(unresolved.allSatisfy { $0.placeName == nil })

        let resolved = GPSMapClustering.groups(
            files: files,
            resolvedNames: [
                "/tmp/a.mov": "Cupertino, CA",
                "/tmp/b.mov": "Cupertino, CA",
                "/tmp/c.mov": "New York, NY",
            ])
        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved.map(\.files.count).sorted(), [1, 2])
        let cupertino = resolved.first { $0.placeName == "Cupertino, CA" }
        XCTAssertEqual(cupertino?.files.map(\.path).sorted(), ["/tmp/a.mov", "/tmp/b.mov"])
    }

    func testGroups_sameSpotSharesOnePin() {
        // Identical recorded coordinates → one spot pin, no radius involved.
        let files = [
            stub(path: "/tmp/a.mov", lat: 37.3349, lon: -122.0090),
            stub(path: "/tmp/b.mov", lat: 37.3349, lon: -122.0090),
            stub(path: "/tmp/c.mov", lat: 37.4800, lon: -122.0090)
        ]
        let clusters = GPSMapClustering.groups(files: files)
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.map(\.files.count).sorted(), [1, 2])
    }

    func testGroups_filesSortByCreationDate() {
        let old = stub(path: "/tmp/old.mov", lat: 37.3349, lon: -122.0090)
        let new = stub(path: "/tmp/new.mov", lat: 37.3349, lon: -122.0090)
        var oldest = old
        oldest.creationTime = Date(timeIntervalSince1970: 1_000)
        var newest = new
        newest.creationTime = Date(timeIntervalSince1970: 2_000)
        // Input order deliberately backwards.
        let clusters = GPSMapClustering.groups(files: [newest, oldest])
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].files.map(\.path), ["/tmp/old.mov", "/tmp/new.mov"])
    }

    func testMediaCountLabel_alwaysPhotosAndVideos() {
        XCTAssertEqual(GPSMediaCounts.label(photos: 0, videos: 1), "0 photos, 1 video")
        XCTAssertEqual(GPSMediaCounts.label(photos: 2, videos: 133), "2 photos, 133 videos")
        let files = [
            stub(path: "/tmp/a.mov", lat: 1, lon: 2),
            stub(path: "/tmp/b.jpg", lat: 1, lon: 2, ext: "jpg")
        ]
        let totals = GPSMediaCounts.totals(in: files)
        XCTAssertEqual(totals.photos, 1)
        XCTAssertEqual(totals.videos, 1)
        XCTAssertEqual(GPSMediaCounts.label(photos: totals.photos, videos: totals.videos), "1 photo, 1 video")
    }

    @MainActor
    func testCityFolderName_sanitizesAndFallsBack() {
        XCTAssertEqual(GPSGeocoder.folderName(for: "Idaho Falls, ID"), "Idaho Falls, ID")
        XCTAssertEqual(GPSGeocoder.folderName(for: "A/B"), "A_B")
        XCTAssertEqual(GPSGeocoder.folderName(for: "   "), "GPS")
        XCTAssertEqual(GPSGeocoder.folderName(for: nil), "GPS")
    }

    private func stub(path: String, lat: Double, lon: Double, ext: String = "mov") -> VideoInfo {
        VideoInfo(
            path: path,
            name: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
            dir: "/tmp",
            ext: ext,
            sizeBytes: 1,
            width: 1920,
            height: 1080,
            resolutionClass: "1080p",
            orientation: "landscape",
            fps: 30,
            durationSec: 1,
            codec: "h264",
            container: "mov",
            make: "Apple",
            model: "iPhone",
            hasAppleMake: true,
            hasiPhoneModel: true,
            hasGPS: true,
            latitude: lat,
            longitude: lon,
            creationTime: nil,
            error: nil,
            warning: nil
        )
    }
}
