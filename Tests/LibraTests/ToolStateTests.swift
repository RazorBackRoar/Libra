import XCTest
@testable import Libra

final class ToolStateTests: XCTestCase {

    @MainActor
    func testStartScanClearsUndoRecords() {
        let state = ToolState(tool: .vidres)
        state.undoRecords = [
            UndoRecord(kind: .moved, originalPath: "/Trip1/clip.mov", resultPath: "/Trip1/1080p/clip 001.mov"),
        ]

        state.startScan(
            paths: ["/tmp/empty-scan"],
            settings: .default
        )

        XCTAssertTrue(state.undoRecords.isEmpty)
    }

    @MainActor
    func testScheduleRerunSkipsWhenNotDryRun() async {
        let state = ToolState(tool: .vidres)
        state.dryRun = false
        state.files = [stubVideo()]

        state.scheduleRerunAfterOptionsChange()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(state.running)
    }

    private func stubVideo() -> VideoInfo {
        VideoInfo(
            path: "/tmp/sample.mov",
            name: "sample",
            dir: "/tmp",
            ext: "mov",
            sizeBytes: 1,
            width: 1920,
            height: 1080,
            resolutionClass: "1080p",
            orientation: "landscape",
            fps: 30,
            durationSec: 10,
            codec: "h264",
            container: "mov",
            make: "",
            model: "",
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            latitude: nil,
            longitude: nil,
            creationTime: nil,
            error: nil,
            warning: nil
        )
    }
}
