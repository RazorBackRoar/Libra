import XCTest
@testable import Libra

final class ScannerServiceTests: XCTestCase {
    private let fileCount = 75

    func testScanContinuesAfterOneMetadataFailureAndTracksProgress() async throws {
        let root = try makeFixtureFolder(fileCount: fileCount)
        defer { try? FileManager.default.removeItem(at: root) }

        final class ProgressBox: @unchecked Sendable {
            var updates: [(Int, Int)] = []
        }
        let progressBox = ProgressBox()
        let failureName = "clip_009"

        let outcome = await ScannerService.scan(
            paths: [root.path],
            extensions: ["mp4"],
            ffprobePath: "/usr/bin/true",
            probe: { filePath, _ in
                let name = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
                if name == failureName {
                    return Self.stubInfo(
                        path: filePath,
                        error: "Metadata probe timed out"
                    )
                }
                if name == "clip_010" {
                    return Self.stubInfo(
                        path: filePath,
                        warning: "Optional metadata enrichment unavailable"
                    )
                }
                return Self.stubInfo(path: filePath)
            },
            progress: { done, total in
                progressBox.updates.append((done, total))
            }
        )
        let progressUpdates = progressBox.updates

        XCTAssertEqual(outcome.terminal, .completed)
        XCTAssertEqual(outcome.discoveredTotal, fileCount)
        XCTAssertEqual(outcome.completedCount, fileCount)
        XCTAssertEqual(outcome.supported.count, fileCount)
        XCTAssertEqual(progressUpdates.first?.0, 0)
        XCTAssertEqual(progressUpdates.first?.1, fileCount)
        XCTAssertEqual(progressUpdates.last?.0, fileCount)
        XCTAssertEqual(progressUpdates.last?.1, fileCount)
        XCTAssertEqual(progressUpdates.count, fileCount + 1)

        let failed = outcome.supported.filter { $0.error != nil }
        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(failed.first?.error, "Metadata probe timed out")
        XCTAssertFalse((failed.first?.error ?? "").contains("/"))

        let warned = outcome.supported.filter { $0.warning != nil }
        XCTAssertEqual(warned.count, 1)
        XCTAssertEqual(warned.first?.warning, "Optional metadata enrichment unavailable")
        XCTAssertNil(warned.first?.error)

        let encoded = "\(outcome.supported.map(\.error)) \(outcome.supported.map(\.warning))"
        XCTAssertFalse(encoded.contains(root.path))
    }

    func testScanCancellationPreservesPartialResults() async throws {
        let root = try makeFixtureFolder(fileCount: fileCount)
        defer { try? FileManager.default.removeItem(at: root) }

        final class Gate: @unchecked Sendable {
            var task: Task<ScanOutcome, Never>?
        }
        let gate = Gate()

        gate.task = Task {
            await ScannerService.scan(
                paths: [root.path],
                extensions: ["mp4"],
                ffprobePath: "/usr/bin/true",
                probe: { filePath, _ in
                    try Task.checkCancellation()
                    return Self.stubInfo(path: filePath)
                },
                progress: { done, total in
                    if done == 10 {
                        gate.task?.cancel()
                    }
                }
            )
        }

        let outcome = await gate.task!.value

        XCTAssertEqual(outcome.terminal, .cancelled)
        XCTAssertEqual(outcome.discoveredTotal, fileCount)
        XCTAssertEqual(outcome.completedCount, outcome.supported.count)
        XCTAssertLessThan(outcome.completedCount, fileCount)
        XCTAssertGreaterThanOrEqual(outcome.completedCount, 10)

        for info in outcome.supported {
            XCTAssertNil(info.error)
            XCTAssertFalse(info.path.isEmpty)
        }
        XCTAssertFalse(outcome.supported.contains { $0.error?.contains(root.path) == true })
    }

    private func makeFixtureFolder(fileCount: Int) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("libra-scan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for index in 0..<fileCount {
            let name = String(format: "clip_%03d.mp4", index)
            let url = root.appendingPathComponent(name)
            try Data("fixture".utf8).write(to: url)
        }
        return root
    }

    private static func stubInfo(
        path: String,
        error: String? = nil,
        warning: String? = nil
    ) -> VideoInfo {
        let url = URL(fileURLWithPath: path)
        return VideoInfo(
            path: path,
            name: url.deletingPathExtension().lastPathComponent,
            dir: url.deletingLastPathComponent().path,
            ext: url.pathExtension.lowercased(),
            sizeBytes: 1,
            width: 1920,
            height: 1080,
            resolutionClass: "1080p",
            orientation: "landscape",
            fps: 30,
            durationSec: 1,
            codec: "h264",
            container: "mp4",
            make: "",
            model: "",
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            creationTime: nil,
            error: error,
            warning: warning
        )
    }
}
