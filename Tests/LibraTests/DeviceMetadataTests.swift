import XCTest
@testable import Libra

final class DeviceMetadataTests: XCTestCase {
    func testHasAppleMake() {
        // Happy path - exact match
        XCTAssertTrue(DeviceMetadata.hasAppleMake(in: ["Apple"]))
        XCTAssertTrue(DeviceMetadata.hasAppleMake(in: ["apple"]))
        XCTAssertTrue(DeviceMetadata.hasAppleMake(in: ["APPLE"]))

        // Happy path - substring match
        XCTAssertTrue(DeviceMetadata.hasAppleMake(in: ["Apple Computer, Inc."]))
        XCTAssertTrue(DeviceMetadata.hasAppleMake(in: ["Apple Inc."]))
        XCTAssertTrue(DeviceMetadata.hasAppleMake(in: ["Something Apple"]))
        XCTAssertTrue(DeviceMetadata.hasAppleMake(in: ["apple_corp"]))

        // Multiple items in array, one is apple
        XCTAssertTrue(DeviceMetadata.hasAppleMake(in: ["Sony", "Apple", "Samsung"]))
        XCTAssertTrue(DeviceMetadata.hasAppleMake(in: ["Unknown", "apple inc", "Nikon"]))

        // Error conditions / Negative cases
        XCTAssertFalse(DeviceMetadata.hasAppleMake(in: ["Sony"]))
        XCTAssertFalse(DeviceMetadata.hasAppleMake(in: ["Samsung"]))
        XCTAssertFalse(DeviceMetadata.hasAppleMake(in: []))
        XCTAssertFalse(DeviceMetadata.hasAppleMake(in: ["App", "Aple", "Mac"]))

        // Substring edge cases
        // Note: The current implementation returns true for anything containing "apple",
        // including words like "Pineapple". Testing the current behavior.
        XCTAssertTrue(DeviceMetadata.hasAppleMake(in: ["Pineapple"]))
    }
}
