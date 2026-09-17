import XCTest

@testable import Libra

@MainActor
final class MediaKindsTests: XCTestCase {

    private var tempDir: URL!
    private var savedSettings: AppSettings!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        SettingsStore.fileURLOverride = tempDir.appendingPathComponent("settings.json")
        savedSettings = SettingsStore.shared.settings
    }

    override func tearDown() async throws {
        // Restoring also resyncs MediaKinds via the settings didSet hook.
        SettingsStore.shared.settings = savedSettings
        SettingsStore.fileURLOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testIsImageTracksLiveSettings() {
        var settings = SettingsStore.shared.settings
        settings.imageExtensions = ["avif"]
        SettingsStore.shared.settings = settings

        XCTAssertTrue(MediaKinds.isImage(ext: "avif"))
        XCTAssertTrue(MediaKinds.isImage(ext: "AVIF"))
        // "jpg" is in AppSettings.default — false here proves we read live
        // settings, not the baked-in defaults.
        XCTAssertFalse(MediaKinds.isImage(ext: "jpg"))
    }

    func testIsImageMatchesDefaultExtensionsBeforeAnyEdit() {
        XCTAssertTrue(MediaKinds.isImage(ext: "heic"))
        XCTAssertFalse(MediaKinds.isImage(ext: "mp4"))
    }

    func testDefaultVideoExtensionsAreAllAVFoundationReadable() {
        // Empirically verified on macOS (arm64): AVURLAsset.loadTracks succeeds
        // for these containers. mkv/avi/webm fail with "Cannot Open" — they
        // must never ship as defaults since probing is AVFoundation-only.
        let defaults = Set(AppSettings.default.videoExtensions)
        let avFoundationReadable: Set<String> = ["mp4", "mov", "m4v", "mts", "m2ts", "3gp"]
        XCTAssertEqual(defaults, avFoundationReadable)
        XCTAssertFalse(defaults.contains("mkv"))
        XCTAssertFalse(defaults.contains("avi"))
        XCTAssertFalse(defaults.contains("webm"))
    }

    /// Representative fixture per default extension must survive the real
    /// probe path — the list isn't just a hard-coded set. Fixtures are
    /// ffmpeg-generated h264+aac files committed under Tests/Fixtures.
    func testDefaultExtensionsProbeBundledFixtures() async throws {
        for ext in AppSettings.default.videoExtensions {
            guard let url = Bundle.module.url(forResource: "fmt-probe", withExtension: ext)
            else {
                XCTFail("missing bundled fixture fmt-probe.\(ext)")
                continue
            }
            let info = try await MediaProbe.probe(filePath: url.path)
            XCTAssertNil(info.error, "\(ext) failed to probe: \(info.error ?? "?")")
            XCTAssertEqual(info.container, ext)
        }
    }

    func testVideoInfoIsImageUsesLiveSettings() {
        var settings = SettingsStore.shared.settings
        settings.imageExtensions = ["avif"]
        SettingsStore.shared.settings = settings

        let info = VideoInfo(
            path: "/tmp/clip.avif",
            name: "clip",
            dir: "/tmp",
            ext: "avif",
            sizeBytes: 1,
            width: 0,
            height: 0,
            resolutionClass: "",
            orientation: "",
            fps: 0,
            durationSec: 0,
            codec: "",
            container: "",
            make: "",
            model: "",
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            creationTime: nil,
            error: nil,
            warning: nil
        )
        XCTAssertTrue(info.isImage)
    }
}
