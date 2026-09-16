import XCTest

@testable import Libra

final class FfmpegOpsTests: XCTestCase {

    // Regression for the shipped muxer bug: ffmpeg chooses the output format
    // from the file extension, so the temp output must end in the real
    // container extension (`name.libra-tmp.mp4`, not `name.mp4.libra-tmp`).

    func testTemporaryOutputPathPreservesExtension() {
        XCTAssertEqual(
            FfmpegOps.temporaryOutputPath(for: "/vids/clip.mp4"),
            "/vids/clip.libra-tmp.mp4"
        )
        XCTAssertEqual(
            FfmpegOps.temporaryOutputPath(for: "/vids/clip.mov"),
            "/vids/clip.libra-tmp.mov"
        )
        XCTAssertEqual(
            FfmpegOps.temporaryOutputPath(for: "/vids/clip.webm"),
            "/vids/clip.libra-tmp.webm"
        )
    }

    func testTemporaryOutputPathEdgeCases() {
        XCTAssertEqual(
            FfmpegOps.temporaryOutputPath(for: "/vids/my.clip.v2.mp4"),
            "/vids/my.clip.v2.libra-tmp.mp4"
        )
        XCTAssertEqual(
            FfmpegOps.temporaryOutputPath(for: "/vids/clip"),
            "/vids/clip.libra-tmp"
        )
    }

    func testSloMoArgumentsEndAtExtensionPreservingTempPath() {
        for ext in ["mov", "mp4", "webm"] {
            let tmp = FfmpegOps.temporaryOutputPath(for: "/vids/out.\(ext)")
            let args = FfmpegOps.sloMoArguments(input: "/vids/in.mov", output: tmp, factor: 0.5)
            XCTAssertEqual(args.last, tmp)
            XCTAssertTrue(tmp.hasSuffix(".libra-tmp.\(ext)"))
        }
    }

    func testSloMoArgumentsPayload() {
        let args = FfmpegOps.sloMoArguments(
            input: "/vids/in.mov",
            output: "/vids/out.libra-tmp.mp4",
            factor: 0.25
        )
        XCTAssertEqual(args[args.firstIndex(of: "-i")! + 1], "/vids/in.mov")
        XCTAssertTrue(args.contains("PTS*4.0"))
        XCTAssertTrue(args.contains("-an"))
        XCTAssertEqual(args[args.firstIndex(of: "-c:v")! + 1], "libx264")
        XCTAssertTrue(args.contains("-y"))
    }

    func testAdjustTimestampArgumentsEndAtExtensionPreservingTempPath() {
        let date = Date(timeIntervalSince1970: 1_704_192_000)
        for ext in ["mov", "mp4", "webm"] {
            let tmp = FfmpegOps.temporaryOutputPath(for: "/vids/out.\(ext)")
            let args = FfmpegOps.adjustTimestampArguments(
                input: "/vids/in.mov",
                output: tmp,
                creationTime: date
            )
            XCTAssertEqual(args.last, tmp)
            XCTAssertTrue(tmp.hasSuffix(".libra-tmp.\(ext)"))
        }
    }

    func testAdjustTimestampArgumentsPayload() {
        // 1_704_192_000 = 2024-01-02 10:40:00 UTC; formatter is pinned to GMT.
        let date = Date(timeIntervalSince1970: 1_704_192_000)
        let args = FfmpegOps.adjustTimestampArguments(
            input: "/vids/in.mov",
            output: "/vids/out.libra-tmp.mp4",
            creationTime: date
        )
        XCTAssertEqual(args[args.firstIndex(of: "-i")! + 1], "/vids/in.mov")
        XCTAssertTrue(args.contains("creation_time=2024-01-02 10:40:00"))
        XCTAssertTrue(args.contains("-c"))
        XCTAssertTrue(args.contains("copy"))
        XCTAssertTrue(args.contains("-y"))
    }
}
