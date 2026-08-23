import XCTest
@testable import Libra

final class ScanSafetyTests: XCTestCase {
    func testWarning_skipsOfficialTestFolder() {
        let path = "/Users/home/Desktop/MetaBurn & Libra Test/videos"
        XCTAssertNil(ScanSafety.warning(for: [path]))
        let legacyPath = "/Users/home/Desktop/MetaBurn & L!bra Test/videos"
        XCTAssertNil(ScanSafety.warning(for: [legacyPath]))
    }

    func testWarning_homeAndVolumeRoot() {
        XCTAssertNotNil(ScanSafety.warning(for: ["/"]))
        XCTAssertTrue(ScanSafety.isVolumeRoot("/Volumes/SSD"))
        XCTAssertFalse(ScanSafety.isVolumeRoot("/Volumes/SSD/Movies"))
    }

    func testFileCountWarning_thresholdAndTestFolder() {
        XCTAssertNil(ScanSafety.fileCountWarning(count: 499))
        XCTAssertNotNil(ScanSafety.fileCountWarning(count: 500))
        XCTAssertNil(ScanSafety.fileCountWarning(
            count: 800,
            paths: ["/Users/home/Desktop/MetaBurn & Libra Test/videos"]
        ))
    }

    func testDestinationInsideSource() {
        XCTAssertTrue(ScanSafety.destinationIsInsideSource(dest: "/Trip/Photos", sourceRoot: "/Trip"))
        XCTAssertFalse(ScanSafety.destinationIsInsideSource(dest: "/Photos", sourceRoot: "/Trip"))
        XCTAssertFalse(ScanSafety.destinationIsInsideSource(dest: "/Photos", sourceRoot: nil))
    }
}
