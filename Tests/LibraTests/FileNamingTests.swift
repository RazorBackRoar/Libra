import XCTest
@testable import Libra

@MainActor
final class FileNamingTests: XCTestCase {

    func testStandardFileName_Basic() {
        let result = FileNaming.standardFileName(
            originalName: "Vacation",
            prefix: "",
            resolutionClass: "4K",
            orientation: "Landscape",
            fps: 30.0,
            hasAppleMake: true,
            hasiPhoneModel: true,
            hasGPS: true,
            index: 1,
            padWidth: 3,
            ext: "mov"
        )

        XCTAssertEqual(result, "Vacation 4K W30 🍎📱🌍 001.mov")
    }

    func testStandardFileName_WithPrefix() {
        let result = FileNaming.standardFileName(
            originalName: "Trip",
            prefix: "Summer ",
            resolutionClass: "FHD",
            orientation: "Portrait",
            fps: 60.0,
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            index: 42,
            padWidth: 4,
            ext: "MP4"
        )

        XCTAssertEqual(result, "Summer Trip FHD V60 0042.mp4")
    }

    func testStandardFileName_IgnoredPrefixes() {
        let result = FileNaming.standardFileName(
            originalName: "Video",
            prefix: "file",
            resolutionClass: "1080p",
            orientation: "unknown",
            fps: 29.97,
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: true,
            index: 7,
            padWidth: 3,
            ext: "mov"
        )

        // "file" should be ignored as a prefix, fps 29.97 -> 30
        XCTAssertEqual(result, "Video 1080p W30 🌍 007.mov")
    }

    func testStandardFileName_EmptyOriginalName() {
        let result = FileNaming.standardFileName(
            originalName: "",
            prefix: "Camera",
            resolutionClass: "HD",
            orientation: "landscape",
            fps: 120.0,
            hasAppleMake: true,
            hasiPhoneModel: false,
            hasGPS: false,
            index: 12,
            padWidth: 3,
            ext: "mp4"
        )

        // FileOps.sanitizeFileName("") returns "file"
        XCTAssertEqual(result, "Camera file HD W120 🍎 012.mp4")
    }

    func testStandardFileName_UnknownResolution() {
        let result = FileNaming.standardFileName(
            originalName: "Test",
            prefix: "",
            resolutionClass: "UnknownRes",
            orientation: "Portrait",
            fps: 24.0,
            hasAppleMake: false,
            hasiPhoneModel: true,
            hasGPS: false,
            index: 99,
            padWidth: 3,
            ext: "mkv"
        )

        // resolutionLabel defaults to "SD" if unknown, fps 24.0 -> nearest to 30 bucket -> 30
        XCTAssertEqual(result, "Test SD V30 📱 099.mkv")
    }

    func testStandardFileName_Sanitization() {
        let result = FileNaming.standardFileName(
            originalName: "My/Bad:Name?",
            prefix: "Invalid\\Prefix*",
            resolutionClass: "720p",
            orientation: "W",
            fps: 0.0,
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            index: 1,
            padWidth: 2,
            ext: "MOV"
        )

        // fps <= 0 -> 30
        XCTAssertEqual(result, "Invalid_Prefix_ My_Bad_Name_ 720p W30 01.mov")
    }
}
