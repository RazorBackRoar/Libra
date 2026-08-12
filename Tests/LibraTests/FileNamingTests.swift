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
}
