import XCTest

@testable import Libra

/// GPSMapModel is a pure view model — it must never reverse-geocode, and
/// filter changes reuse the one-time base cluster build.
@MainActor
final class GPSMapModelTests: XCTestCase {

    private func file(
        _ path: String,
        lat: Double? = nil,
        lon: Double? = nil,
        res: String = "1080p",
        apple: Bool = false,
        size: Int64 = 1,
        duration: Double = 10
    ) -> VideoInfo {
        VideoInfo(
            path: path,
            name: (path as NSString).deletingPathExtension
                .components(separatedBy: "/").last ?? "f",
            dir: (path as NSString).deletingLastPathComponent,
            ext: "mov",
            sizeBytes: size,
            width: 1920,
            height: 1080,
            resolutionClass: res,
            orientation: "landscape",
            fps: 30,
            durationSec: duration,
            codec: "h264",
            container: "mov",
            make: apple ? "Apple" : "",
            model: "",
            hasAppleMake: apple,
            hasiPhoneModel: false,
            hasGPS: lat != nil && lon != nil,
            latitude: lat,
            longitude: lon,
            creationTime: nil,
            error: nil,
            warning: nil
        )
    }

    private func awaitBuilds(_ model: GPSMapModel, timeout: Double = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while model.isClustering, Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertFalse(model.isClustering, "cluster build did not finish")
    }

    func testUpdateNeverReverseGeocodes() async {
        var calls = 0
        let real = GPSGeocoder.resolver
        GPSGeocoder.resolver = { _, _ in
            calls += 1
            return "Should Not Be Called"
        }
        defer { GPSGeocoder.resolver = real }

        let model = GPSMapModel()
        let files = [file("/a/1.mov", lat: 43.6, lon: -116.2)]
        model.update(files: files)
        await awaitBuilds(model)
        // Name + filter updates also stay silent.
        model.update(
            files: files,
            resolvedNames: ["/a/1.mov": "Boise, Idaho"],
            filter: .resolution("1080p"))
        await awaitBuilds(model)

        XCTAssertEqual(calls, 0)
        XCTAssertEqual(model.clusters.count, 1)
        XCTAssertEqual(model.clusters[0].placeName, "Boise, Idaho")
    }

    func testFilterDropsNonMatchingFilesAndEmptyClusters() async {
        let files = [
            file("/a/720.mov", lat: 10, lon: 10, res: "720p"),
            file("/a/hd.mov", lat: 10.001, lon: 10.001, res: "1080p"),
            file("/a/far.mov", lat: 50, lon: 50, res: "720p"),
        ]
        let model = GPSMapModel()
        model.update(files: files)
        await awaitBuilds(model)
        XCTAssertEqual(model.clusters.count, 2)

        // Same file set → synchronous refilter, no rebuild.
        model.update(files: files, filter: .resolution("720p"))
        XCTAssertFalse(model.isClustering)
        XCTAssertEqual(model.clusters.count, 2)
        XCTAssertTrue(
            model.clusters.allSatisfy { cluster in
                cluster.files.allSatisfy { $0.resolutionClass == "720p" }
            })

        // A filter that matches nothing empties the map, not the state.
        model.update(files: files, filter: .resolution("4K"))
        XCTAssertTrue(model.clusters.isEmpty)

        model.update(files: files, filter: .all)
        XCTAssertEqual(model.clusters.count, 2)
    }

    func testAppleDeviceAndDuplicatesFilters() async {
        let files = [
            file("/a/apple.mov", lat: 10, lon: 10, apple: true, size: 1),
            file("/a/other.mov", lat: 10, lon: 10, size: 2),
            file("/a/dup1.mov", lat: 30, lon: 30, size: 42, duration: 5),
            file("/a/dup2.mov", lat: 30, lon: 30, size: 42, duration: 5),
        ]
        let model = GPSMapModel()
        model.update(files: files)
        await awaitBuilds(model)

        model.update(files: files, filter: .appleDevice)
        XCTAssertEqual(model.clusters.count, 1)
        XCTAssertEqual(model.clusters[0].files.map(\.path), ["/a/apple.mov"])

        // Same size/duration/format → dup2 is the extra; dup1 is the keeper.
        model.update(files: files, filter: .duplicates)
        XCTAssertEqual(model.clusters.count, 1)
        XCTAssertEqual(model.clusters[0].files.map(\.path), ["/a/dup2.mov"])
    }

    func testResolvedNamesMergeSameCityPins() async {
        // ~13 km apart → two base clusters; same city name → one pin.
        let files = [
            file("/a/1.mov", lat: 43.6, lon: -116.2),
            file("/a/2.mov", lat: 43.7, lon: -116.3),
        ]
        let model = GPSMapModel()
        model.update(files: files)
        await awaitBuilds(model)
        XCTAssertEqual(model.clusters.count, 2)
        XCTAssertTrue(model.clusters.allSatisfy { $0.placeName == nil })

        model.update(
            files: files,
            resolvedNames: [
                "/a/1.mov": "Boise, Idaho",
                "/a/2.mov": "Boise, Idaho",
            ])
        XCTAssertEqual(model.clusters.count, 1)
        XCTAssertEqual(model.clusters[0].placeName, "Boise, Idaho")
        XCTAssertEqual(model.clusters[0].files.count, 2)
    }

    func testMixedOrMissingNamesStayUnmerged() async {
        let files = [
            file("/a/1.mov", lat: 43.6, lon: -116.2),
            file("/a/2.mov", lat: 43.7, lon: -116.3),
            file("/a/3.mov", lat: 43.8, lon: -116.4),
        ]
        let model = GPSMapModel()
        model.update(files: files)
        await awaitBuilds(model)

        // Different cities → three pins; one unresolved pin has no name.
        model.update(
            files: files,
            resolvedNames: [
                "/a/1.mov": "Boise, Idaho",
                "/a/2.mov": "Meridian, Idaho",
            ])
        XCTAssertEqual(model.clusters.count, 3)
        XCTAssertEqual(model.clusters.compactMap(\.placeName).count, 2)
    }

    func testSelectionClearsWhenClusterFilteredOut() async {
        let files = [
            file("/a/720.mov", lat: 10, lon: 10, res: "720p"),
            file("/a/hd.mov", lat: 50, lon: 50, res: "1080p"),
        ]
        let model = GPSMapModel()
        model.update(files: files)
        await awaitBuilds(model)

        let hdCluster = model.clusters.first { $0.files[0].resolutionClass == "1080p" }
        model.selectedClusterID = hdCluster?.id
        XCTAssertNotNil(model.selectedCluster)

        model.update(files: files, filter: .resolution("720p"))
        XCTAssertNil(model.selectedClusterID)
    }

    func testNoCoordinatesAndEmptyInputYieldNoClusters() async {
        let model = GPSMapModel()
        model.update(files: [file("/a/n.mov")])
        await awaitBuilds(model)
        XCTAssertTrue(model.clusters.isEmpty)

        model.update(files: [])
        await awaitBuilds(model)
        XCTAssertTrue(model.clusters.isEmpty)
        XCTAssertNil(model.selectedCluster)
    }
}
