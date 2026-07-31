import XCTest
@testable import Libra

final class FileOpsTests: XCTestCase {

    @MainActor
    func testSanitizeFileName_validName() {
        let name = "My Video File 2024.mp4"
        XCTAssertEqual(FileOps.sanitizeFileName(name), "My Video File 2024.mp4")
    }

    @MainActor
    func testSanitizeFileName_invalidCharactersReplaced() {
        let name = "Video/Name:With\\Invalid?Chars%*|\"<>\0.mp4"
        XCTAssertEqual(FileOps.sanitizeFileName(name), "Video_Name_With_Invalid_Chars_______.mp4")
    }

    @MainActor
    func testSanitizeFileName_trimmingWhitespacesAndNewlines() {
        let name = "  My Video \n "
        XCTAssertEqual(FileOps.sanitizeFileName(name), "My Video")
    }

    @MainActor
    func testSanitizeFileName_multipleSpacesReducedToOne() {
        let name = "My   Video    File.mp4"
        XCTAssertEqual(FileOps.sanitizeFileName(name), "My Video File.mp4")
    }

    @MainActor
    func testSanitizeFileName_emptyStringBecomesFile() {
        XCTAssertEqual(FileOps.sanitizeFileName(""), "file")
        XCTAssertEqual(FileOps.sanitizeFileName("   "), "file") // Trims down to empty
    }

    @MainActor
    func testSanitizeFileName_dotAndDoubleDotBecomesFile() {
        XCTAssertEqual(FileOps.sanitizeFileName("."), "file")
        XCTAssertEqual(FileOps.sanitizeFileName(".."), "file")
    }

    @MainActor
    func testSanitizeFileName_mixOfRules() {
        let name = "   Video:  File / 2024  \n "
        XCTAssertEqual(FileOps.sanitizeFileName(name), "Video_ File _ 2024")
    }
}
