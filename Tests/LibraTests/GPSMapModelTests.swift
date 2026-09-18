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
        // Name + filter updates also stay silent.
        model.update(
            files: files,
            resolvedNames: ["/a/1.mov": "Boise, Idaho"],
            filter: .resolution("1080p"))

        XCTAssertEqual(calls, 0)
        XCTAssertEqual(model.clusters.count, 1)
        XCTAssertEqual(model.clusters[0].placeName, "Boise, Idaho")
    }

    func testFilterDropsNonMatchingFilesAndEmptyClusters() async {
        // Three distinct recorded spots → three pins, no radius merging.
        let files = [
            file("/a/720.mov", lat: 10, lon: 10, res: "720p"),
            file("/a/hd.mov", lat: 10.001, lon: 10.001, res: "1080p"),
            file("/a/far.mov", lat: 50, lon: 50, res: "720p"),
        ]
        let model = GPSMapModel()
        model.update(files: files)
        XCTAssertEqual(model.clusters.count, 3)

        model.update(files: files, filter: .resolution("720p"))
        XCTAssertEqual(model.clusters.count, 2)
        XCTAssertTrue(
            model.clusters.allSatisfy { cluster in
                cluster.files.allSatisfy { $0.resolutionClass == "720p" }
            })

        // A filter that matches nothing empties the map, not the state.
        model.update(files: files, filter: .resolution("4K"))
        XCTAssertTrue(model.clusters.isEmpty)

        model.update(files: files, filter: .all)
        XCTAssertEqual(model.clusters.count, 3)
    }

    func testAppleDeviceFilter() async {
        let files = [
            file("/a/apple.mov", lat: 10, lon: 10, apple: true, size: 1),
            file("/a/other.mov", lat: 10, lon: 10, size: 2),
            file("/a/far.mov", lat: 30, lon: 30, size: 42, duration: 5),
        ]
        let model = GPSMapModel()
        model.update(files: files)

        model.update(files: files, filter: .appleDevice)
        XCTAssertEqual(model.clusters.count, 1)
        XCTAssertEqual(model.clusters[0].files.map(\.path), ["/a/apple.mov"])
    }

    func testResolvedNamesMergeSameCityPins() async {
        // ~13 km apart → two spot pins; same city name → one pin.
        let files = [
            file("/a/1.mov", lat: 43.6, lon: -116.2),
            file("/a/2.mov", lat: 43.7, lon: -116.3),
        ]
        let model = GPSMapModel()
        model.update(files: files)
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

        let hdCluster = model.clusters.first { $0.files[0].resolutionClass == "1080p" }
        model.selectedClusterID = hdCluster?.id
        XCTAssertNotNil(model.selectedCluster)

        model.update(files: files, filter: .resolution("720p"))
        XCTAssertNil(model.selectedClusterID)
    }

    func testNoCoordinatesAndEmptyInputYieldNoClusters() async {
        let model = GPSMapModel()
        model.update(files: [file("/a/n.mov")])
        XCTAssertTrue(model.clusters.isEmpty)

        model.update(files: [])
        XCTAssertTrue(model.clusters.isEmpty)
        XCTAssertNil(model.selectedCluster)
    }

    func testNoGpsAndUnknownFilters() async {
        let files = [
            file("/a/has.mov", lat: 10, lon: 10),
            file("/a/plain.mov"),
            file("/a/apple.mov", apple: true),
        ]
        let model = GPSMapModel()

        model.update(files: files, filter: .noGps)
        XCTAssertTrue(model.clusters.isEmpty)  // no coordinates → no pins

        XCTAssertTrue(MediaBrowserFilter.noGps.matches(files[1]))
        XCTAssertFalse(MediaBrowserFilter.noGps.matches(files[0]))
        XCTAssertTrue(MediaBrowserFilter.unknown.matches(files[1]))
        XCTAssertFalse(MediaBrowserFilter.unknown.matches(files[2]))
        XCTAssertTrue(MediaBrowserFilter.gps.matches(files[0]))
        XCTAssertFalse(MediaBrowserFilter.gps.matches(files[1]))
    }
}

/// State-strip grouping: "City, State" place names roll up under states,
/// cities sort by media count, files stay chronological.
final class GPSStateGroupingTests: XCTestCase {

    private func file(
        _ path: String,
        creationTime: Date? = nil
    ) -> VideoInfo {
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
            latitude: 40,
            longitude: -111,
            creationTime: creationTime,
            error: nil,
            warning: nil
        )
    }

    func testStatesRollUpCitiesSortedByCount() {
        let files = [
            file("/a/1.mov"), file("/a/2.mov"), file("/a/3.mov"), file("/a/4.mov"),
        ]
        let names = [
            "/a/1.mov": "Ogden, Utah",
            "/a/2.mov": "Salt Lake City, Utah",
            "/a/3.mov": "Ogden, Utah",
            "/a/4.mov": "Boise, Idaho",
        ]
        let states = GPSStateGrouping.summarize(files: files, resolvedNames: names)

        XCTAssertEqual(states.map(\.name), ["Utah", "Idaho"])
        XCTAssertEqual(states[0].fileCount, 3)
        XCTAssertEqual(states[0].cities.map(\.name), ["Ogden", "Salt Lake City"])
        XCTAssertEqual(states[0].cities[0].files.count, 2)
        XCTAssertEqual(states[1].cities.map(\.name), ["Boise"])
    }

    func testCityFilesStayChronological() {
        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 2000)
        let files = [
            file("/a/new.mov", creationTime: late),
            file("/a/old.mov", creationTime: early),
            file("/a/none.mov"),
        ]
        let names = [
            "/a/new.mov": "Ogden, Utah",
            "/a/old.mov": "Ogden, Utah",
            "/a/none.mov": "Ogden, Utah",
        ]
        let states = GPSStateGrouping.summarize(files: files, resolvedNames: names)

        XCTAssertEqual(
            states[0].cities[0].files.map(\.path),
            ["/a/old.mov", "/a/new.mov", "/a/none.mov"])
    }

    func testUnresolvedAndMalformedNamesAreSkipped() {
        let files = [file("/a/1.mov"), file("/a/2.mov"), file("/a/3.mov")]
        let names = [
            "/a/1.mov": "Nowhere",
            "/a/2.mov": "Ogden, Utah",
        ]
        let states = GPSStateGrouping.summarize(files: files, resolvedNames: names)

        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(states[0].cities.count, 1)
        XCTAssertEqual(states[0].cities[0].files.map(\.path), ["/a/2.mov"])
    }
}
