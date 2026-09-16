import XCTest

@testable import Libra

@MainActor
final class ToolStateTests: XCTestCase {

    private var tempDir: URL!
    private var savedSettings: AppSettings!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        // Redirect report + settings writes to the temp dir so the real
        // Desktop and ~/Library/Application Support/Libra are never touched.
        SettingsStore.fileURLOverride = tempDir.appendingPathComponent("settings.json")
        DryRunReport.reportDirectoryOverride = tempDir
        savedSettings = SettingsStore.shared.settings
    }

    override func tearDown() async throws {
        // Restore in-memory state; the real settings.json was never written.
        SettingsStore.shared.settings = savedSettings
        SettingsStore.fileURLOverride = nil
        DryRunReport.reportDirectoryOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testStartScanClearsUndoRecords() async {
        let state = ToolState(tool: .vidres)
        state.undoRecords = [
            UndoRecord(
                kind: .moved, originalPath: "/Trip1/clip.mov",
                resultPath: "/Trip1/1080p/clip 001.mov")
        ]

        state.startScan(
            paths: ["/tmp/empty-scan"],
            settings: .default
        )

        XCTAssertTrue(state.undoRecords.isEmpty)

        // Wait out the spawned scan Task so it cannot outlive the test.
        for _ in 0..<500 where state.running {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(state.running)
    }

    func testScheduleRerunPreviewsWhenLiveToggleOff() async {
        let state = ToolState(tool: .vidres)
        state.dryRun = false
        state.files = [stubVideo()]

        state.scheduleRerunAfterOptionsChange()
        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertTrue(state.undoRecords.isEmpty)
        XCTAssertFalse(state.canWrite && state.running)
    }

    func testStartWriteRefusesWhenPreviewOnly() {
        let state = ToolState(tool: .vidres)
        state.dryRun = true
        state.files = [stubVideo()]

        state.startWrite(settings: .default, ffmpegPath: nil)

        XCTAssertFalse(state.running)
        XCTAssertEqual(state.message, "Turn off Preview only, then Write.")
        XCTAssertTrue(state.undoRecords.isEmpty)
    }

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
