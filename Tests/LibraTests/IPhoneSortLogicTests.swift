import XCTest
@testable import Libra

final class IPhoneSortLogicTests: XCTestCase {

    @MainActor
    func testClassify_withFullMetadata() {
        let result = IPhoneSortLogic.classify(
            hasAppleMake: true,
            hasiPhoneModel: true,
            make: "Apple",
            model: "iPhone 13 Pro"
        )

        XCTAssertTrue(result.isIPhoneFolder)
        XCTAssertEqual(result.markers, "🍎📱")
        XCTAssertEqual(result.note, "Make=Apple · Model=iPhone 13 Pro")
    }

    @MainActor
    func testClassify_withAppleMakeOnly() {
        let result = IPhoneSortLogic.classify(
            hasAppleMake: true,
            hasiPhoneModel: false,
            make: "Apple",
            model: ""
        )

        XCTAssertTrue(result.isIPhoneFolder)
        XCTAssertEqual(result.markers, "🍎")
        XCTAssertEqual(result.note, "Make=Apple · Model=—")
    }

    @MainActor
    func testClassify_withIPhoneModelOnly() {
        let result = IPhoneSortLogic.classify(
            hasAppleMake: false,
            hasiPhoneModel: true,
            make: "",
            model: "iPhone 13 Pro"
        )

        XCTAssertTrue(result.isIPhoneFolder)
        XCTAssertEqual(result.markers, "📱")
        XCTAssertEqual(result.note, "Make=— · Model=iPhone 13 Pro")
    }

    @MainActor
    func testClassify_missingMakeAndModelStrings_butHasBooleans() {
        let result = IPhoneSortLogic.classify(
            hasAppleMake: true,
            hasiPhoneModel: true,
            make: "",
            model: ""
        )

        XCTAssertTrue(result.isIPhoneFolder)
        XCTAssertEqual(result.markers, "🍎📱")
        XCTAssertEqual(result.note, "Classified from available device metadata markers")
    }

    @MainActor
    func testClassify_noAppleOrIPhoneData() {
        let result = IPhoneSortLogic.classify(
            hasAppleMake: false,
            hasiPhoneModel: false,
            make: "Sony",
            model: "A7IV"
        )

        XCTAssertFalse(result.isIPhoneFolder)
        XCTAssertEqual(result.markers, "")
        XCTAssertEqual(result.note, "Make=Sony · Model=A7IV")
    }

    @MainActor
    func testClassify_completelyMissingMetadata() {
        let result = IPhoneSortLogic.classify(
            hasAppleMake: false,
            hasiPhoneModel: false,
            make: "",
            model: ""
        )

        XCTAssertFalse(result.isIPhoneFolder)
        XCTAssertEqual(result.markers, "")
        XCTAssertEqual(result.note, "Missing Make/Model metadata")
    }
}
