import XCTest
@testable import Libra

final class FileNamingTests: XCTestCase {
    @MainActor
    func testMetadataMarkers() {
        // all false
        XCTAssertEqual(FileNaming.metadataMarkers(hasAppleMake: false, hasiPhoneModel: false, hasGPS: false), "")

        // apple make only
        XCTAssertEqual(FileNaming.metadataMarkers(hasAppleMake: true, hasiPhoneModel: false, hasGPS: false), "🍎")

        // iphone model only
        XCTAssertEqual(FileNaming.metadataMarkers(hasAppleMake: false, hasiPhoneModel: true, hasGPS: false), "📱")

        // gps only
        XCTAssertEqual(FileNaming.metadataMarkers(hasAppleMake: false, hasiPhoneModel: false, hasGPS: true), "🌍")

        // apple and iphone
        XCTAssertEqual(FileNaming.metadataMarkers(hasAppleMake: true, hasiPhoneModel: true, hasGPS: false), "🍎📱")

        // apple and gps
        XCTAssertEqual(FileNaming.metadataMarkers(hasAppleMake: true, hasiPhoneModel: false, hasGPS: true), "🍎🌍")

        // iphone and gps
        XCTAssertEqual(FileNaming.metadataMarkers(hasAppleMake: false, hasiPhoneModel: true, hasGPS: true), "📱🌍")

        // all true
        XCTAssertEqual(FileNaming.metadataMarkers(hasAppleMake: true, hasiPhoneModel: true, hasGPS: true), "🍎📱🌍")
    }
}
