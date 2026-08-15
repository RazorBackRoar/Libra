import XCTest
@testable import Libra

final class UndoApplyTests: XCTestCase {
    func testUndoMoveRestoresOriginalPath() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-undo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("clip.mov").path
        let destDir = dir.appendingPathComponent("1080p", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let dest = destDir.appendingPathComponent("clip 001.mov").path
        FileManager.default.createFile(atPath: source, contents: Data("src".utf8))

        let moved = FileOps.moveFile(from: source, to: dest, dryRun: false)
        XCTAssertEqual(moved.status, .success)
        XCTAssertEqual(moved.outputPath, dest)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest))

        let outcome = UndoApply.apply([
            UndoRecord(kind: .moved, originalPath: source, resultPath: dest)
        ])
        XCTAssertEqual(outcome.restored, 1)
        XCTAssertEqual(outcome.failed, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: source)), Data("src".utf8))
    }

    func testCancelLeavesEarlierMoveAndUndoRestoresIt() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-cancel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = dir.appendingPathComponent("a.mov").path
        let second = dir.appendingPathComponent("b.mov").path
        FileManager.default.createFile(atPath: first, contents: Data("a".utf8))
        FileManager.default.createFile(atPath: second, contents: Data("b".utf8))

        let dest1 = dir.appendingPathComponent("1080p").appendingPathComponent("a 001.mov").path
        let moved = FileOps.moveFile(from: first, to: dest1, dryRun: false)
        XCTAssertEqual(moved.status, .success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second))

        let recap = RunRecap.summary(
            previewPass: false,
            cancelled: true,
            success: 1,
            failed: 0,
            skipped: 0,
            done: 1,
            total: 2
        )
        XCTAssertTrue(recap.contains("Undo Last Run"))

        let outcome = UndoApply.apply([
            UndoRecord(kind: .moved, originalPath: first, resultPath: dest1)
        ])
        XCTAssertEqual(outcome.restored, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest1))
    }

    func testUndoCreatedCopyDeletesOutput() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-copy-undo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("clip.mov").path
        let copy = dir.appendingPathComponent("SloMo").appendingPathComponent("clip 001.mov").path
        FileManager.default.createFile(atPath: source, contents: Data("src".utf8))
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: copy).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: copy, contents: Data("copy".utf8))

        let outcome = UndoApply.apply([
            UndoRecord(kind: .createdCopy, originalPath: source, resultPath: copy)
        ])
        XCTAssertEqual(outcome.restored, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source))
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy))
    }
}
