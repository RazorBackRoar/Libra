import XCTest
@testable import Libra

final class MediaProbeTests: XCTestCase {
    func testCollectStringValues_withFlatDictionary() {
        let dictionary: [String: Any] = [
            "make": "Apple",
            "model": "iPhone 15 Pro",
            "year": 2023,
            "empty": ""
        ]

        let result = DeviceMetadata.collectStringValues(from: dictionary, keys: ["make", "model", "empty", "year", "missing"])

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
                ] as [String : Any]
            ] as [String : Any],
            "other": "value"
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
            "model": "iPhone"
        ]
        let result = DeviceMetadata.collectStringValues(from: dictionary, keys: ["make", "model"])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, "iPhone")
    }
}
