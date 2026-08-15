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

    @MainActor
    func testUniquePath_incrementsTrailingPaddedIndex() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-unique-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = dir.appendingPathComponent("Vacation 4K W30 001.mov").path
        FileManager.default.createFile(atPath: first, contents: Data())
        let next = FileOps.uniquePath(for: first)
        XCTAssertEqual((next as NSString).lastPathComponent, "Vacation 4K W30 002.mov")
    }

    @MainActor
    func testUniquePath_respectsReservedSet() {
        let planned = "/tmp/libra-reserved/Clip 001.mov"
        let next = FileOps.uniquePath(for: planned, reserved: [planned])
        XCTAssertEqual((next as NSString).lastPathComponent, "Clip 002.mov")
    }

    @MainActor
    func testUniquePath_appendsPaddedIndexWhenNoTrailingNumber() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-unique-plain-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = dir.appendingPathComponent("Holiday.mov").path
        FileManager.default.createFile(atPath: first, contents: Data())
        let next = FileOps.uniquePath(for: first)
        XCTAssertEqual((next as NSString).lastPathComponent, "Holiday 002.mov")
    }

    func testMoveFile_dryRunDoesNotWrite() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-dry-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("clip.mov").path
        FileManager.default.createFile(atPath: source, contents: Data("a".utf8))
        let dest = dir.appendingPathComponent("1080p").appendingPathComponent("clip 001.mov").path

        let result = FileOps.moveFile(from: source, to: dest, dryRun: true)
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.outputPath, dest)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest))
    }

    func testMoveFile_neverOverwritesExistingPath() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-over-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("incoming.mov").path
        let taken = dir.appendingPathComponent("clip 001.mov").path
        FileManager.default.createFile(atPath: source, contents: Data("src".utf8))
        FileManager.default.createFile(atPath: taken, contents: Data("keep".utf8))

        let result = FileOps.moveFile(from: source, to: taken, dryRun: false)
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual((result.outputPath as NSString?)?.lastPathComponent, "clip 002.mov")
        XCTAssertEqual(try? Data(contentsOf: URL(fileURLWithPath: taken)), Data("keep".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source))
    }

    func testMoveFile_reservedBatchKeeps001Then002() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-batch-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = dir.appendingPathComponent("a.mov").path
        let second = dir.appendingPathComponent("b.mov").path
        FileManager.default.createFile(atPath: first, contents: Data("a".utf8))
        FileManager.default.createFile(atPath: second, contents: Data("b".utf8))

        var reserved = Set<String>()
        let planned1 = dir.appendingPathComponent("Vacation 4K W30 001.mov").path
        let planned2 = dir.appendingPathComponent("Vacation 4K W30 002.mov").path
        let r1 = FileOps.moveFile(from: first, to: planned1, dryRun: true, reserved: reserved)
        if let output = r1.outputPath { reserved.insert(output) }
        let r2 = FileOps.moveFile(from: second, to: planned2, dryRun: true, reserved: reserved)
        if let output = r2.outputPath { reserved.insert(output) }

        XCTAssertEqual((r1.outputPath as NSString?)?.lastPathComponent, "Vacation 4K W30 001.mov")
        XCTAssertEqual((r2.outputPath as NSString?)?.lastPathComponent, "Vacation 4K W30 002.mov")
    }

    func testMoveFile_skipsSymlink() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-link-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let target = dir.appendingPathComponent("real.mov").path
        let link = dir.appendingPathComponent("alias.mov").path
        FileManager.default.createFile(atPath: target, contents: Data("keep".utf8))
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: target)
        XCTAssertTrue(FileOps.isSymlinkOrAlias(link))
        XCTAssertFalse(FileOps.isSymlinkOrAlias(target))

        let dest = dir.appendingPathComponent("out.mov").path
        let result = FileOps.moveFile(from: link, to: dest, dryRun: false)
        XCTAssertEqual(result.status, .skipped)
        XCTAssertTrue(FileManager.default.fileExists(atPath: target))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest))
    }

    func testIsPath_insideAncestor() {
        XCTAssertTrue(FileOps.isPath("/Trip/1080p/clip.mov", inside: "/Trip"))
        XCTAssertTrue(FileOps.isPath("/Trip", inside: "/Trip"))
        XCTAssertFalse(FileOps.isPath("/Photos", inside: "/Trip"))
    }
}
