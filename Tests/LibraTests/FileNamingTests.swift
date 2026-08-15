import XCTest
@testable import Libra

final class FileNamingTests: XCTestCase {

    @MainActor
    func testPrefixReplacesOriginalNameWithASpace() {
        let name = FileNaming.standardFileName(
            originalName: "1E8B0D0F-0FEB-4DBE-B941-3888703E7D41 (1)",
            prefix: "katie",
            resolutionClass: "720p",
            orientation: "landscape",
            fps: 30,
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            index: 2,
            padWidth: 3,
            ext: "mp4"
        )
        XCTAssertEqual(name, "katie 720p W30 002.mp4")
    }

    @MainActor
    func testEmptyPrefixKeepsOriginalName() {
        let name = FileNaming.standardFileName(
            originalName: "Vacation",
            prefix: "",
            resolutionClass: "4K",
            orientation: "landscape",
            fps: 30,
            hasAppleMake: true,
            hasiPhoneModel: true,
            hasGPS: true,
            index: 1,
            padWidth: 3,
            ext: "mov"
        )
        XCTAssertEqual(name, "Vacation 4K W30 🍎📱🌍 001.mov")
    }

    @MainActor
    func testPrefixTrimsExtraSpaces() {
        let name = FileNaming.standardFileName(
            originalName: "IMG_4181",
            prefix: "  video  ",
            resolutionClass: "1080p",
            orientation: "portrait",
            fps: 60,
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            index: 1,
            padWidth: 3,
            ext: "mp4"
        )
        XCTAssertEqual(name, "video 1080p V60 001.mp4")
    }

    func testEightKAnd24FpsBuckets() {
        XCTAssertEqual(FileNaming.resolutionLabel("8K"), "8K")
        XCTAssertEqual(FileNaming.fpsBucket(24), 24)
        XCTAssertEqual(FileNaming.fpsBucket(30), 30)
        let name = FileNaming.standardFileName(
            originalName: "Cinema",
            prefix: "",
            resolutionClass: "8K",
            orientation: "landscape",
            fps: 24,
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            index: 1,
            padWidth: 3,
            ext: "mov"
        )
        XCTAssertEqual(name, "Cinema 8K W24 001.mov")
    }

    func testSquareAnd1440p() {
        XCTAssertEqual(FileNaming.orientationCode("square"), "S")
        XCTAssertEqual(FileNaming.orientationCode("portrait"), "V")
        XCTAssertEqual(FileNaming.orientationCode("landscape"), "W")
        XCTAssertEqual(FileNaming.resolutionLabel("1440p"), "1440p")
        let name = FileNaming.standardFileName(
            originalName: "Clip",
            prefix: "",
            resolutionClass: "1440p",
            orientation: "square",
            fps: 30,
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            index: 1,
            padWidth: 3,
            ext: "mov"
        )
        XCTAssertEqual(name, "Clip 1440p S30 001.mov")
    }
}
