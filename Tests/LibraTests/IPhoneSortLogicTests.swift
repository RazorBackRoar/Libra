import XCTest
@testable import Libra

final class IPhoneSortLogicTests: XCTestCase {
    func testClassify_iPhoneModelGoesToIPhone() {
        let result = IPhoneSortLogic.classify(
            hasAppleMake: true,
            hasiPhoneModel: true,
            make: "Apple",
            model: "iPhone 15 Pro"
        )
        XCTAssertEqual(result.folder, .iPhone)
    }

    func testClassify_appleMakeWithoutIPhoneGoesToOtherApple() {
        let result = IPhoneSortLogic.classify(
            hasAppleMake: true,
            hasiPhoneModel: false,
            make: "Apple",
            model: "iPad Pro"
        )
        XCTAssertEqual(result.folder, .otherApple)
    }

    func testClassify_noAppleMetadataGoesToNotApple() {
        let result = IPhoneSortLogic.classify(
            hasAppleMake: false,
            hasiPhoneModel: false,
            make: "Sony",
            model: "A7IV"
        )
        XCTAssertEqual(result.folder, .notApple)
    }
}
