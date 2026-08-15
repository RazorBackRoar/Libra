import XCTest
@testable import Libra

final class ScanSafetyTests: XCTestCase {
    func testWarning_skipsOfficialTestFolder() {
        let path = "/Users/home/Desktop/MetaBurn & L!bra Test/videos"
        XCTAssertNil(ScanSafety.warning(for: [path]))
    }

    func testWarning_homeAndVolumeRoot() {
        XCTAssertNotNil(ScanSafety.warning(for: ["/"]))
        XCTAssertTrue(ScanSafety.isVolumeRoot("/Volumes/SSD"))
        XCTAssertFalse(ScanSafety.isVolumeRoot("/Volumes/SSD/Movies"))
    }

    func testDestinationInsideSource() {
        XCTAssertTrue(ScanSafety.destinationIsInsideSource(dest: "/Trip/Photos", sourceRoot: "/Trip"))
        XCTAssertFalse(ScanSafety.destinationIsInsideSource(dest: "/Photos", sourceRoot: "/Trip"))
        XCTAssertFalse(ScanSafety.destinationIsInsideSource(dest: "/Photos", sourceRoot: nil))
    }
}
