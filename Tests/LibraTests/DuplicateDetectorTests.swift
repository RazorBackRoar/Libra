import XCTest
@testable import Libra

final class DuplicateDetectorTests: XCTestCase {
    func testExtraPaths_keepsFirstByPath() {
        let files = [
            stub(path: "/tmp/b.mov", name: "Clip", size: 100, duration: 12),
            stub(path: "/tmp/a.mov", name: "Clip", size: 100, duration: 12),
            stub(path: "/tmp/c.mov", name: "Other", size: 50, duration: 3)
        ]
        let extras = DuplicateDetector.extraPaths(in: files)
        XCTAssertEqual(extras, ["/tmp/b.mov"])
        XCTAssertEqual(DuplicateDetector.extraCount(in: files), 1)
    }

    func testExtraPaths_ignoresMetadataFailures() {
        var broken = stub(path: "/tmp/x.mov", name: "Clip", size: 100, duration: 12)
        broken.error = "nope"
        let files = [
            stub(path: "/tmp/a.mov", name: "Clip", size: 100, duration: 12),
            broken
        ]
        XCTAssertTrue(DuplicateDetector.extraPaths(in: files).isEmpty)
    }

    func testExtraPaths_ignoresDifferentResolution() {
        let files = [
            stub(path: "/tmp/a.mov", name: "Clip", size: 100, duration: 12, width: 1920, height: 1080),
            stub(path: "/tmp/b.mov", name: "Clip", size: 100, duration: 12, width: 2560, height: 1440)
        ]
        XCTAssertTrue(DuplicateDetector.extraPaths(in: files).isEmpty)
    }

    func testExtraPaths_matchesDifferentStemsWithSameFormat() {
        let files = [
            stub(path: "/tmp/IMG_001.mov", name: "IMG_001", size: 100, duration: 12),
            stub(path: "/tmp/IMG_001 (1).mov", name: "IMG_001 (1)", size: 100, duration: 12)
        ]
        XCTAssertEqual(DuplicateDetector.extraPaths(in: files), ["/tmp/IMG_001.mov"])
    }

    private func stub(
        path: String,
        name: String,
        size: Int64,
        duration: Double,
        width: Int = 1920,
        height: Int = 1080
    ) -> VideoInfo {
        VideoInfo(
            path: path,
            name: name,
            dir: "/tmp",
            ext: "mov",
            sizeBytes: size,
            width: width,
            height: height,
            resolutionClass: "1080p",
            orientation: "landscape",
            fps: 30,
            durationSec: duration,
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
