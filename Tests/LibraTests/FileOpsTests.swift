import XCTest
@testable import Libra

final class FileOpsTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        let uuid = UUID().uuidString
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("FileOpsTests-\(uuid)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    @MainActor
    func testUniquePath_whenFileDoesNotExist_returnsSamePath() {
        // Arrange
        let path = tempDir.appendingPathComponent("test.txt").path

        // Act
        let unique = FileOps.uniquePath(for: path)

        // Assert
        XCTAssertEqual(unique, path)
    }

    @MainActor
    func testUniquePath_whenFileExists_appendsCounter() throws {
        // Arrange
        let path = tempDir.appendingPathComponent("test.txt").path
        try "content".write(toFile: path, atomically: true, encoding: .utf8)

        // Act
        let unique = FileOps.uniquePath(for: path)

        // Assert
        let expected = tempDir.appendingPathComponent("test (1).txt").path
        XCTAssertEqual(unique, expected)
    }

    @MainActor
    func testUniquePath_whenMultipleFilesExist_incrementsCounter() throws {
        // Arrange
        let path = tempDir.appendingPathComponent("test.txt").path
        let path1 = tempDir.appendingPathComponent("test (1).txt").path
        let path2 = tempDir.appendingPathComponent("test (2).txt").path

        try "content".write(toFile: path, atomically: true, encoding: .utf8)
        try "content".write(toFile: path1, atomically: true, encoding: .utf8)
        try "content".write(toFile: path2, atomically: true, encoding: .utf8)

        // Act
        let unique = FileOps.uniquePath(for: path)

        // Assert
        let expected = tempDir.appendingPathComponent("test (3).txt").path
        XCTAssertEqual(unique, expected)
    }

    @MainActor
    func testUniquePath_whenNoExtension_appendsCounterCorrectly() throws {
        // Arrange
        let path = tempDir.appendingPathComponent("test_file").path
        try "content".write(toFile: path, atomically: true, encoding: .utf8)

        // Act
        let unique = FileOps.uniquePath(for: path)

        // Assert
        let expected = tempDir.appendingPathComponent("test_file (1)").path
        XCTAssertEqual(unique, expected)
    }
}
