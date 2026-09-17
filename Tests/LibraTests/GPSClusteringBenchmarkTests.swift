import XCTest

@testable import Libra

/// 5,000-item clustering benchmark — the stated performance target.
final class GPSClusteringBenchmarkTests: XCTestCase {

    private func makeFile(path: String, lat: Double, lon: Double) -> VideoInfo {
        VideoInfo(
            path: path,
            name: (path as NSString).deletingPathExtension
                .components(separatedBy: "/").last ?? "f",
            dir: (path as NSString).deletingLastPathComponent,
            ext: "mov",
            sizeBytes: 1,
            width: 1920,
            height: 1080,
            resolutionClass: "1080p",
            orientation: "landscape",
            fps: 30,
            durationSec: 10,
            codec: "h264",
            container: "mov",
            make: "",
            model: "",
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: true,
            latitude: lat,
            longitude: lon,
            creationTime: nil,
            error: nil,
            warning: nil
        )
    }

    /// 5,000 files across ~500 locations (~10 files each, jittered within
    /// ~1 km so each location forms exactly one cluster).
    private func makeFiles() -> [VideoInfo] {
        var files: [VideoInfo] = []
        files.reserveCapacity(5000)
        for loc in 0..<500 {
            let baseLat = 30.0 + Double(loc % 50) * 0.5
            let baseLon = -120.0 + Double(loc / 50) * 1.0
            for i in 0..<10 {
                let jitterLat = baseLat + Double(i % 3) * 0.002
                let jitterLon = baseLon + Double(i % 4) * 0.002
                files.append(
                    makeFile(
                        path: "/lib/f\(loc)_\(i).mov", lat: jitterLat, lon: jitterLon))
            }
        }
        return files
    }

    func testClusterHandles5000FilesQuickly() {
        let files = makeFiles()
        let start = CFAbsoluteTimeGetCurrent()
        let clusters = GPSMapClustering.cluster(files: files)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(clusters.count, 500)
        XCTAssertEqual(clusters.reduce(0) { $0 + $1.files.count }, 5000)
        XCTAssertLessThan(elapsed, 2.0, "clustering 5,000 files took \(elapsed)s")
    }

    /// Count-pill filters must reuse the base build — no re-clustering on
    /// every click. Same file set → synchronous in-memory filter only.
    @MainActor
    func testMapFilterSwitchIsFast() async throws {
        let files = makeFiles()
        let model = GPSMapModel()
        model.update(files: files)
        let deadline = Date().addingTimeInterval(10)
        while model.isClustering, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(model.clusters.count, 500)

        let start = CFAbsoluteTimeGetCurrent()
        model.update(files: files, filter: .resolution("1080p"))
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertFalse(model.isClustering)  // filter change never re-clusters
        XCTAssertEqual(model.clusters.reduce(0) { $0 + $1.files.count }, 5000)
        XCTAssertLessThan(elapsed, 0.1, "filtering 5,000 files took \(elapsed)s")
    }

    func testMergeByPlaceNameHandles500Clusters() {
        let files = makeFiles()
        var clusters = GPSMapClustering.cluster(files: files)
        for i in clusters.indices {
            clusters[i].placeName = i % 2 == 0 ? "Boise, Idaho" : "Meridian, Idaho"
        }
        let start = CFAbsoluteTimeGetCurrent()
        let merged = GPSMapClustering.mergeByPlaceName(clusters)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.reduce(0) { $0 + $1.files.count }, 5000)
        XCTAssertLessThan(elapsed, 1.0)
    }
}
