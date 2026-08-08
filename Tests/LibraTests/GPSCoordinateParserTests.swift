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

    func testCluster_groupsFilesWithinFiveMiles() {
        // ~1.1 miles apart around Cupertino — must share one pin.
        let files = [
            stub(path: "/tmp/a.mov", lat: 37.3349, lon: -122.0090),
            stub(path: "/tmp/b.mov", lat: 37.3500, lon: -122.0090),
            stub(path: "/tmp/c.mov", lat: 40.0, lon: -74.0)
        ]
        let clusters = GPSMapClustering.cluster(files: files)
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.map(\.files.count).sorted(), [1, 2])
    }

    func testCluster_keepsSeparateBeyondFiveMiles() {
        // ~10 miles apart on the same longitude — two pins.
        let files = [
            stub(path: "/tmp/a.mov", lat: 37.3349, lon: -122.0090),
            stub(path: "/tmp/b.mov", lat: 37.4800, lon: -122.0090)
        ]
        let clusters = GPSMapClustering.cluster(files: files)
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.map(\.files.count), [1, 1])
    }

    func testMergeByPlaceName_combinesSameCityPins() {
        let a = GPSLocationCluster(
            id: "a",
            latitude: 43.49,
            longitude: -112.03,
            files: [stub(path: "/tmp/a.mov", lat: 43.49, lon: -112.03)],
            placeName: "Idaho Falls, ID"
        )
        let b = GPSLocationCluster(
            id: "b",
            latitude: 43.50,
            longitude: -112.04,
            files: [
                stub(path: "/tmp/b.mov", lat: 43.50, lon: -112.04),
                stub(path: "/tmp/c.mov", lat: 43.50, lon: -112.04)
            ],
            placeName: "Idaho Falls, ID"
        )
        let c = GPSLocationCluster(
            id: "c",
            latitude: 41.32,
            longitude: -112.00,
            files: [stub(path: "/tmp/d.mov", lat: 41.32, lon: -112.00)],
            placeName: "Pleasant View, UT"
        )
        let merged = GPSMapClustering.mergeByPlaceName([a, b, c])
        XCTAssertEqual(merged.count, 2)
        let idaho = merged.first { $0.placeName == "Idaho Falls, ID" }
        XCTAssertEqual(idaho?.files.count, 3)
        XCTAssertEqual(merged.first { $0.placeName == "Pleasant View, UT" }?.files.count, 1)
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
