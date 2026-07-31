import XCTest
@testable import Libra

@MainActor
final class FileNamingTests: XCTestCase {

    func testResolutionLabelKnownClasses() {
        // Test all known resolution classes which should be returned as-is
        XCTAssertEqual(FileNaming.resolutionLabel("4K"), "4K")
        XCTAssertEqual(FileNaming.resolutionLabel("FHD"), "FHD")
        XCTAssertEqual(FileNaming.resolutionLabel("1080p"), "1080p")
        XCTAssertEqual(FileNaming.resolutionLabel("HD"), "HD")
        XCTAssertEqual(FileNaming.resolutionLabel("720p"), "720p")
        XCTAssertEqual(FileNaming.resolutionLabel("SD"), "SD")
    }

    func testResolutionLabelUnknownClasses() {
        // Test unknown resolution classes which should default to "SD"
        XCTAssertEqual(FileNaming.resolutionLabel("8K"), "SD")
        XCTAssertEqual(FileNaming.resolutionLabel("2K"), "SD")
        XCTAssertEqual(FileNaming.resolutionLabel("Unknown"), "SD")
        XCTAssertEqual(FileNaming.resolutionLabel(""), "SD")
        XCTAssertEqual(FileNaming.resolutionLabel("4k"), "SD") // Case sensitive check since 4k is not in resolutionClasses array
    }
}
