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

    func testClusterKey_collapsesNearbyDuplicates() {
        let a = GPSMapClustering.clusterKey(latitude: 37.33491, longitude: -122.00904)
        let b = GPSMapClustering.clusterKey(latitude: 37.33494, longitude: -122.00901)
        XCTAssertEqual(a, b)
    }

    func testCluster_groupsSameLocationFiles() {
        let files = [
            stub(path: "/tmp/a.mov", lat: 37.3349, lon: -122.0090),
            stub(path: "/tmp/b.mov", lat: 37.33492, lon: -122.00901),
            stub(path: "/tmp/c.mov", lat: 40.0, lon: -74.0)
        ]
        let clusters = GPSMapClustering.cluster(files: files)
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.map(\.files.count).sorted(), [1, 2])
    }

    private func stub(path: String, lat: Double, lon: Double) -> VideoInfo {
        VideoInfo(
            path: path,
            name: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
            dir: "/tmp",
            ext: "mov",
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
