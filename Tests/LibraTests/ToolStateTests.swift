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
    func testScheduleRerunPreviewsWhenLiveToggleOff() async {
        let state = ToolState(tool: .vidres)
        state.dryRun = false
        state.files = [stubVideo()]

        state.scheduleRerunAfterOptionsChange()
        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertTrue(state.undoRecords.isEmpty)
        XCTAssertFalse(state.canWrite && state.running)
    }

    @MainActor
    func testStartWriteRefusesWhenPreviewOnly() {
        let state = ToolState(tool: .vidres)
        state.dryRun = true
        state.files = [stubVideo()]

        state.startWrite(settings: .default, ffmpegPath: nil)

        XCTAssertFalse(state.running)
        XCTAssertEqual(state.message, "Turn off Preview only, then Write.")
        XCTAssertTrue(state.undoRecords.isEmpty)
    }

    @MainActor
    func testMovePhotosOutRefusesDestinationInsideSource() {
        let state = ToolState(tool: .provid)
        state.photos = [stubVideo(path: "/Trip/stills/IMG_0001.heic", ext: "heic")]
        SettingsStore.shared.update { $0.lastFolder = "/Trip" }

        let refused = state.movePhotosOut(to: "/Trip/Photos")

        XCTAssertEqual(refused, "Choose a folder outside the scanned video folder.")
        XCTAssertTrue(state.photos.count == 1)
    }

    private func stubVideo(path: String = "/tmp/sample.mov", ext: String = "mov") -> VideoInfo {
        VideoInfo(
            path: path,
            name: "sample",
            dir: (path as NSString).deletingLastPathComponent,
            ext: ext,
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
