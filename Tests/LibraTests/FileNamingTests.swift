import XCTest
@testable import Libra

final class FileNamingTests: XCTestCase {

    @MainActor
    func testFpsBucketMapsToNearestContractValue() {
        XCTAssertEqual(FileNaming.fpsBucket(29.97), 30)
        XCTAssertEqual(FileNaming.fpsBucket(59.94), 60)
        XCTAssertEqual(FileNaming.fpsBucket(119.0), 120)
        XCTAssertEqual(FileNaming.fpsBucket(0), 30)
    }

    @MainActor
    func testOrientationCodeUsesPortraitAndLandscapeMarkers() {
        XCTAssertEqual(FileNaming.orientationCode("portrait"), "V")
        XCTAssertEqual(FileNaming.orientationCode("landscape"), "W")
        XCTAssertEqual(FileNaming.orientationCode("square"), "W")
    }

    @MainActor
    func testPaddingWidthGrowsForLargeBatches() {
        XCTAssertEqual(FileNaming.paddingWidth(forCount: 1), 3)
        XCTAssertEqual(FileNaming.paddingWidth(forCount: 99), 3)
        XCTAssertEqual(FileNaming.paddingWidth(forCount: 100), 3)
        XCTAssertEqual(FileNaming.paddingWidth(forCount: 1000), 4)
    }

    @MainActor
    func testMetadataMarkersFollowFixedOrder() {
        XCTAssertEqual(
            FileNaming.metadataMarkers(hasAppleMake: true, hasiPhoneModel: true, hasGPS: true),
            "🍎📱🌍"
        )
        XCTAssertEqual(
            FileNaming.metadataMarkers(hasAppleMake: false, hasiPhoneModel: true, hasGPS: false),
            "📱"
        )
    }
}
