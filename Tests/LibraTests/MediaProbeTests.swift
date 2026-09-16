import XCTest

@testable import Libra

final class MediaProbeTests: XCTestCase {
    func testCollectStringValues_withFlatDictionary() {
        let dictionary: [String: Any] = [
            "make": "Apple",
            "model": "iPhone 15 Pro",
            "year": 2023,
            "empty": "",
        ]

        let result = DeviceMetadata.collectStringValues(
            from: dictionary, keys: ["make", "model", "empty", "year", "missing"])

        // Output order is deterministic based on `keys` array for the top level,
        // but dictionary iteration (nested) is unordered in Swift.
        // For the top-level keys loop, it appends in the order of `keys`.
        // "make" -> "Apple", "model" -> "iPhone 15 Pro", "empty" -> ignored, "year" -> ignored, "missing" -> ignored.
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], "Apple")
        XCTAssertEqual(result[1], "iPhone 15 Pro")
    }

    func testCollectStringValues_withNestedDictionary() {
        let dictionary: [String: Any] = [
            "make": "Sony",
            "metadata": [
                "model": "A7IV",
                "nested": [
                    "make": "Sony (nested)"
                ] as [String: Any],
            ] as [String: Any],
            "other": "value",
        ]

        let result = DeviceMetadata.collectStringValues(from: dictionary, keys: ["make", "model"])

        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.contains("Sony"))
        XCTAssertTrue(result.contains("A7IV"))
        XCTAssertTrue(result.contains("Sony (nested)"))
    }

    func testCollectStringValues_withEmptyDictionary() {
        let dictionary: [String: Any] = [:]
        let result = DeviceMetadata.collectStringValues(from: dictionary, keys: ["make", "model"])
        XCTAssertTrue(result.isEmpty)
    }

    func testCollectStringValues_withNoKeys() {
        let dictionary: [String: Any] = ["make": "Apple", "model": "iPhone 15 Pro"]
        let result = DeviceMetadata.collectStringValues(from: dictionary, keys: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testCollectStringValues_withArraysAreIgnored() {
        let dictionary: [String: Any] = [
            "make": ["Apple", "Sony"],
            "model": "iPhone",
        ]
        let result = DeviceMetadata.collectStringValues(from: dictionary, keys: ["make", "model"])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, "iPhone")
    }

    // MARK: - §23.20 real-file verification
    // Fixture: ffmpeg-generated 3840×2160 @ 59.94fps .mov, h264 + aac, with
    // mvhd creation_time 2024-06-15T10:30:00Z, ISO6709 location +37.3349-122.0090,
    // make "Apple", model "iPhone 16 Pro".

    private func fixturePath() throws -> String {
        guard let url = Bundle.module.url(forResource: "probe-fixture", withExtension: "mov")
        else {
            throw XCTSkip("probe-fixture.mov not bundled")
        }
        return url.path
    }

    func testProbeFixtureExtractsRealMetadata() async throws {
        let info = try await MediaProbe.probe(filePath: try fixturePath())

        XCTAssertNil(info.error)
        XCTAssertEqual(info.width, 3840)
        XCTAssertEqual(info.height, 2160)
        XCTAssertEqual(info.resolutionClass, "4K")
        XCTAssertEqual(info.orientation, "landscape")
        // §23.8 — raw 59.94 preserved, not rounded to 60.
        XCTAssertEqual(info.fps, 59.94, accuracy: 0.01)
        XCTAssertEqual(info.codec, "h264")
        XCTAssertEqual(info.durationSec, 0.5, accuracy: 0.05)
        XCTAssertEqual(info.container, "mov")
        XCTAssertEqual(info.typeIdentifier, "com.apple.quicktime-movie")

        XCTAssertEqual(info.make, "Apple")
        XCTAssertEqual(info.model, "iPhone 16 Pro")
        XCTAssertTrue(info.hasAppleMake)
        XCTAssertTrue(info.hasiPhoneModel)

        XCTAssertTrue(info.hasGPS)
        XCTAssertEqual(info.latitude ?? 0, 37.3349, accuracy: 0.001)
        XCTAssertEqual(info.longitude ?? 0, -122.009, accuracy: 0.001)

        // §23.4 — embedded mvhd date kept separate from filesystem dates.
        XCTAssertTrue(info.creationTimeEmbedded)
        XCTAssertEqual(info.creationTime, ISO8601DateFormatter().date(from: "2024-06-15T10:30:00Z"))
        XCTAssertNotNil(info.fileCreationTime)
        XCTAssertNotNil(info.fileModificationTime)
        XCTAssertNotEqual(info.creationTime, info.fileCreationTime)

        // §23.12 — audio track inspected.
        XCTAssertEqual(info.audioCodec, "aac")

        // §23.10 — SDR fixture must not produce a fabricated HDR flag.
        XCTAssertNotEqual(info.isHDR, true)
    }

    func testFailedProbeStillReportsFilesystemDates() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-probe-\(UUID().uuidString).mov")
        try Data("not a movie".utf8).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let info = try await MediaProbe.probe(filePath: tmp.path)
        XCTAssertNotNil(info.error)
        XCTAssertFalse(info.creationTimeEmbedded)
        XCTAssertNotNil(info.fileCreationTime)
        XCTAssertNotNil(info.fileModificationTime)
        XCTAssertEqual(info.typeIdentifier, "com.apple.quicktime-movie")
    }
}
