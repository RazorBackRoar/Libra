import CoreGraphics
import XCTest
@testable import Libra

final class MediaClassificationTests: XCTestCase {
    func testResolutionBucketBoundaries() {
        // Fixed standards, with tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 3840, height: 2160), "4K")
        XCTAssertEqual(MediaClassification.resolutionClass(width: 7680, height: 4320), "4K")  // 8K folds into 4K
        XCTAssertEqual(MediaClassification.resolutionClass(width: 2560, height: 1440), "QHD")
        XCTAssertEqual(MediaClassification.resolutionClass(width: 2558, height: 1440), "QHD") // tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 2562, height: 1440), "QHD") // tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1920, height: 1080), "1080p")
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1918, height: 1080), "1080p") // tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1922, height: 1080), "1080p") // tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1280, height: 720), "720p")
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1278, height: 720), "720p")   // tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1282, height: 720), "720p")   // tolerance

        // FHD: between 1080p tolerance and QHD tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1923, height: 1080), "FHD") // just outside 1080p tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 2557, height: 1440), "FHD") // just below QHD tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 2436, height: 1125), "FHD") // iPhone X screen recording

        // HD: between 720p tolerance and 1080p tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1283, height: 720), "HD") // just outside 720p tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1600, height: 900), "HD")
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1917, height: 1080), "HD") // just below 1080p tolerance

        // SD: below 720p tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1277, height: 720), "SD") // just below 720p tolerance
        XCTAssertEqual(MediaClassification.resolutionClass(width: 640, height: 480), "SD")
        XCTAssertEqual(MediaClassification.resolutionClass(width: 128, height: 224), "SD") // iMessage clip

        // Portrait: long edge is max(w, h)
        XCTAssertEqual(MediaClassification.resolutionClass(width: 1080, height: 1920), "1080p")
        XCTAssertEqual(MediaClassification.resolutionClass(width: 720, height: 1280), "720p")
        XCTAssertEqual(MediaClassification.resolutionClass(width: 2160, height: 3840), "4K")

        // Unknown / zero
        XCTAssertEqual(MediaClassification.resolutionClass(width: 0, height: 0), "Unknown")
    }

    func testOrientation_rawSize() {
        XCTAssertEqual(MediaClassification.orientation(width: 1920, height: 1080), "landscape")
        XCTAssertEqual(MediaClassification.orientation(width: 1080, height: 1920), "portrait")
        XCTAssertEqual(MediaClassification.orientation(width: 1080, height: 1080), "square")
    }

    func testDisplayedSize_appliesPreferredTransform() {
        let rotated = MediaClassification.displayedSize(
            naturalWidth: 1920,
            naturalHeight: 1080,
            transform: CGAffineTransform(rotationAngle: .pi / 2)
        )
        XCTAssertEqual(rotated.width, 1080)
        XCTAssertEqual(rotated.height, 1920)
        XCTAssertEqual(MediaClassification.orientation(width: rotated.width, height: rotated.height), "portrait")
    }

    func testOrganizeLayout_folderDepths() {
        XCTAssertEqual(
            OrganizeLayout.folderComponents(
                depth: .none,
                resolutionClass: "1080p",
                orientation: "landscape",
                fpsBucket: 30
            ),
            []
        )
        XCTAssertEqual(
            OrganizeLayout.folderComponents(
                depth: .resolution,
                resolutionClass: "4K",
                orientation: "portrait",
                fpsBucket: 60
            ),
            ["4K"]
        )
        XCTAssertEqual(
            OrganizeLayout.folderComponents(
                depth: .resolutionOrientation,
                resolutionClass: "1080p",
                orientation: "portrait",
                fpsBucket: 30
            ),
            ["1080p", "Portrait"]
        )
        XCTAssertEqual(
            OrganizeLayout.folderComponents(
                depth: .resolutionOrientationFps,
                resolutionClass: "FHD",
                orientation: "landscape",
                fpsBucket: 60
            ),
            ["FHD", "Landscape", "60fps"]
        )
    }

    func testOrganizeLayout_mapsLegacyTools() {
        XCTAssertEqual(OrganizeLayout.filenameStyle(for: .provid), .libraFormat)
        XCTAssertEqual(OrganizeLayout.folderDepth(for: .provid), .none)
        XCTAssertEqual(OrganizeLayout.filenameStyle(for: .keepName), .keepOriginal)
        XCTAssertEqual(OrganizeLayout.folderDepth(for: .keepName), .resolution)
        XCTAssertEqual(OrganizeLayout.folderDepth(for: .promax), .resolutionOrientation)
        XCTAssertEqual(OrganizeLayout.folderDepth(for: .maxvid), .resolutionOrientationFps)
        XCTAssertEqual(Tool.homeTools.count, 6)
        XCTAssertEqual(Tool.homeTools.last, .photoSweep)
        XCTAssertEqual(Tool.photoSweep.title, "Photos Only")
        XCTAssertEqual(Tool.provid.title, "Libra Sorter")
        XCTAssertEqual(Tool.iphoneSorter.title, "iPhone Model Sort")
        XCTAssertEqual(Tool.gps.title, "GPS")
        XCTAssertEqual(Tool.slomo.title, "Slo-Mo")
        XCTAssertEqual(Tool.oneMin.title, "1-Min-Adjuster")
    }
}
