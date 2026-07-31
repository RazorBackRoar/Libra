import XCTest
@testable import Libra

final class UpdatesTests: XCTestCase {
    func testCompareVersions_EqualVersions() {
        XCTAssertEqual(Updates.compareVersions("1.0.0", "1.0.0"), 0)
        XCTAssertEqual(Updates.compareVersions("1.2.3", "1.2.3"), 0)
        XCTAssertEqual(Updates.compareVersions("v1.0.0", "1.0.0"), 0)
        XCTAssertEqual(Updates.compareVersions("1.0.0", "v1.0.0"), 0)
        XCTAssertEqual(Updates.compareVersions("v1.0.0", "v1.0.0"), 0)
    }

    func testCompareVersions_MajorDifferences() {
        XCTAssertEqual(Updates.compareVersions("2.0.0", "1.9.9"), 1)
        XCTAssertEqual(Updates.compareVersions("1.9.9", "2.0.0"), -1)
    }

    func testCompareVersions_MinorDifferences() {
        XCTAssertEqual(Updates.compareVersions("1.2.0", "1.1.9"), 1)
        XCTAssertEqual(Updates.compareVersions("1.1.9", "1.2.0"), -1)
    }

    func testCompareVersions_PatchDifferences() {
        XCTAssertEqual(Updates.compareVersions("1.0.2", "1.0.1"), 1)
        XCTAssertEqual(Updates.compareVersions("1.0.1", "1.0.2"), -1)
    }

    func testCompareVersions_DifferentLength() {
        XCTAssertEqual(Updates.compareVersions("1.0", "1.0.0"), 0)
        XCTAssertEqual(Updates.compareVersions("1.0.0", "1.0"), 0)
        XCTAssertEqual(Updates.compareVersions("1.1", "1.0.1"), 1)
        XCTAssertEqual(Updates.compareVersions("1.0.1", "1.1"), -1)
    }

    func testCompareVersions_MultiDigitSegments() {
        XCTAssertEqual(Updates.compareVersions("1.10.0", "1.2.0"), 1)
        XCTAssertEqual(Updates.compareVersions("1.2.0", "1.10.0"), -1)
        XCTAssertEqual(Updates.compareVersions("10.0.0", "2.0.0"), 1)
    }
}
