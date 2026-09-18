import XCTest

@testable import Libra

/// 5,000-item grouping benchmark — the stated performance target. Grouping
/// is a dictionary bucket by spot/city name, so it must stay far under the
/// old radius-cluster budget.
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
    /// ~1 km — distinct recorded spots, no radius merging).
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

    func testGroupsHandles5000FilesQuickly() {
        let files = makeFiles()
        let start = CFAbsoluteTimeGetCurrent()
        let clusters = GPSMapClustering.groups(files: files)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertFalse(clusters.isEmpty)
        XCTAssertEqual(clusters.reduce(0) { $0 + $1.files.count }, 5000)
        XCTAssertLessThan(elapsed, 2.0, "grouping 5,000 files took \(elapsed)s")
    }

    /// Count-pill filters re-run grouping synchronously — it must stay cheap
    /// on every click even at 5,000 files.
    @MainActor
    func testMapFilterSwitchIsFast() async throws {
        let files = makeFiles()
        let model = GPSMapModel()
        model.update(files: files)
        XCTAssertEqual(model.clusters.reduce(0) { $0 + $1.files.count }, 5000)

        let start = CFAbsoluteTimeGetCurrent()
        model.update(files: files, filter: .resolution("1080p"))
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(model.clusters.reduce(0) { $0 + $1.files.count }, 5000)
        XCTAssertLessThan(elapsed, 0.1, "filtering 5,000 files took \(elapsed)s")
    }

    /// Resolved names collapse every spot into its city pin — 500 spots
    /// across two names must merge to two pins cheaply.
    func testCityGroupingHandles5000Files() {
        let files = makeFiles()
        var names: [String: String] = [:]
        names.reserveCapacity(files.count)
        for (index, file) in files.enumerated() {
            names[file.path] = index % 2 == 0 ? "Boise, Idaho" : "Meridian, Idaho"
        }

        let start = CFAbsoluteTimeGetCurrent()
        let clusters = GPSMapClustering.groups(files: files, resolvedNames: names)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.reduce(0) { $0 + $1.files.count }, 5000)
        XCTAssertTrue(clusters.allSatisfy { $0.placeName != nil })
        XCTAssertLessThan(elapsed, 1.0, "city grouping 5,000 files took \(elapsed)s")
    }
}
