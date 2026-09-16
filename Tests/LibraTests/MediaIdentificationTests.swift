import XCTest

@testable import Libra

final class MediaIdentificationTests: XCTestCase {
    func testLine_showsResolutionFpsIPhoneAndGPS_withoutContainer() {
        let file = video(
            ext: "mov",
            width: 1920,
            height: 1080,
            resolutionClass: "1080p",
            orientation: "landscape",
            fps: 29.97,
            durationSec: 72,
            sizeBytes: 42 * 1024 * 1024,
            make: "Apple",
            model: "iPhone 15 Pro",
            hasAppleMake: true,
            hasiPhoneModel: true,
            hasGPS: true,
            latitude: 37.33491,
            longitude: -122.00904
        )
        let line = MediaIdentification.line(for: file)
        XCTAssertTrue(line.contains("1080p 1920×1080"))
        XCTAssertTrue(line.contains("landscape"))
        XCTAssertTrue(line.contains("29.97 fps"))
        XCTAssertTrue(line.contains("iPhone 15 Pro"))
        XCTAssertTrue(line.contains("GPS 37.33491, -122.00904"))
        XCTAssertTrue(line.contains("1:12"))
        XCTAssertFalse(line.localizedCaseInsensitiveContains("mov"))
        XCTAssertFalse(line.localizedCaseInsensitiveContains("mp4"))
        XCTAssertEqual(file.identificationLine, line)
        let fpsIndex = line.range(of: "29.97 fps")!.lowerBound
        let deviceIndex = line.range(of: "iPhone 15 Pro")!.lowerBound
        let gpsIndex = line.range(of: "GPS")!.lowerBound
        XCTAssertTrue(line.range(of: "1080p")!.lowerBound < fpsIndex)
        XCTAssertTrue(fpsIndex < deviceIndex)
        XCTAssertTrue(deviceIndex < gpsIndex)
    }

    func testLine_photoSkipsFpsAndShowsPixels() {
        let file = video(
            ext: "heic",
            width: 4032,
            height: 3024,
            resolutionClass: "4K",
            orientation: "landscape",
            fps: 0,
            durationSec: 0,
            sizeBytes: 3 * 1024 * 1024,
            make: "Apple",
            model: "iPhone 14",
            hasAppleMake: true,
            hasiPhoneModel: true,
            hasGPS: false,
            latitude: nil,
            longitude: nil
        )
        let line = MediaIdentification.line(for: file)
        XCTAssertTrue(line.contains("4K 4032×3024"))
        XCTAssertTrue(line.contains("iPhone 14"))
        XCTAssertFalse(line.contains("fps"))
        XCTAssertFalse(line.contains("GPS"))
        XCTAssertFalse(line.localizedCaseInsensitiveContains("heic"))
    }

    func testDeviceLabel_otherAppleAndNotApple() {
        let ipad = video(
            make: "Apple",
            model: "iPad Pro",
            hasAppleMake: true,
            hasiPhoneModel: false
        )
        XCTAssertEqual(MediaIdentification.deviceLabel(for: ipad), "Apple iPad Pro")

        let sony = video(
            make: "Sony",
            model: "A7IV",
            hasAppleMake: false,
            hasiPhoneModel: false
        )
        XCTAssertEqual(MediaIdentification.deviceLabel(for: sony), "Sony A7IV")
    }

    func testGpsLabel_requiresCoordinates() {
        var file = video(hasGPS: true, latitude: 43.49165, longitude: -112.03396)
        XCTAssertEqual(MediaIdentification.gpsLabel(for: file), "GPS 43.49165, -112.03396")
        file.hasGPS = true
        file.latitude = nil
        file.longitude = nil
        XCTAssertEqual(MediaIdentification.gpsLabel(for: file), "GPS")
    }

    private func video(
        ext: String = "mp4",
        width: Int = 1920,
        height: Int = 1080,
        resolutionClass: String = "1080p",
        orientation: String = "landscape",
        fps: Double = 30,
        durationSec: Double = 10,
        sizeBytes: Int64 = 1_000_000,
        make: String = "",
        model: String = "",
        hasAppleMake: Bool = false,
        hasiPhoneModel: Bool = false,
        hasGPS: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> VideoInfo {
        VideoInfo(
            path: "/tmp/clip.\(ext)",
            name: "clip",
            dir: "/tmp",
            ext: ext,
            sizeBytes: sizeBytes,
            width: width,
            height: height,
            resolutionClass: resolutionClass,
            orientation: orientation,
            fps: fps,
            durationSec: durationSec,
            codec: "h264",
            container: ext,
            make: make,
            model: model,
            hasAppleMake: hasAppleMake,
            hasiPhoneModel: hasiPhoneModel,
            hasGPS: hasGPS,
            latitude: latitude,
            longitude: longitude,
            creationTime: nil,
            error: nil,
            warning: nil
        )
    }
}
