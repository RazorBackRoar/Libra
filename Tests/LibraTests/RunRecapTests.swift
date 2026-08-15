import XCTest
@testable import Libra

final class RunRecapTests: XCTestCase {
    func testCancelledWriteMentionsUndo() {
        let text = RunRecap.summary(
            previewPass: false,
            cancelled: true,
            success: 3,
            failed: 0,
            skipped: 0,
            done: 3,
            total: 10
        )
        XCTAssertEqual(
            text,
            "Cancelled. 3 videos already written. Undo Last Run to put them back."
        )
    }

    func testCancelledWriteBeforeAnySuccess() {
        let text = RunRecap.summary(
            previewPass: false,
            cancelled: true,
            success: 0,
            failed: 0,
            skipped: 0,
            done: 0,
            total: 10
        )
        XCTAssertEqual(text, "Cancelled before any videos were written.")
    }

    func testCancelledPreviewKeepsCount() {
        let text = RunRecap.summary(
            previewPass: true,
            cancelled: true,
            success: 2,
            failed: 0,
            skipped: 0,
            done: 2,
            total: 8
        )
        XCTAssertEqual(text, "Cancelled after 2 of 8.")
    }
}
