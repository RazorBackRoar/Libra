import XCTest
@testable import Libra

final class FileNamingTests: XCTestCase {

    @MainActor
    func testFpsBucket() throws {
        // Valid edge cases
        XCTAssertEqual(FileNaming.fpsBucket(0.1), 30)
        XCTAssertEqual(FileNaming.fpsBucket(24), 30)
        XCTAssertEqual(FileNaming.fpsBucket(29.97), 30)
        XCTAssertEqual(FileNaming.fpsBucket(30), 30)

        // Midpoints
        // Midpoint between 30 and 60 is 45
        XCTAssertEqual(FileNaming.fpsBucket(44.9), 30)
        XCTAssertEqual(FileNaming.fpsBucket(45.1), 60)

        XCTAssertEqual(FileNaming.fpsBucket(59.94), 60)
        XCTAssertEqual(FileNaming.fpsBucket(60), 60)

        // Midpoint between 60 and 120 is 90
        XCTAssertEqual(FileNaming.fpsBucket(89.9), 60)
        XCTAssertEqual(FileNaming.fpsBucket(90.1), 120)

        XCTAssertEqual(FileNaming.fpsBucket(119.88), 120)
        XCTAssertEqual(FileNaming.fpsBucket(120), 120)
        XCTAssertEqual(FileNaming.fpsBucket(240), 120)

        // Invalid or extreme cases
        XCTAssertEqual(FileNaming.fpsBucket(0), 30)
        XCTAssertEqual(FileNaming.fpsBucket(-10), 30)
    }
}
