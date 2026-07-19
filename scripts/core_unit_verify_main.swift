import Foundation

// Standalone unit checks for Libra core logic (no XCTest / Xcode required).
// Compiled and run by scripts/run-core-unit-tests.sh on macOS CI.

@MainActor
enum CoreUnitVerify {
    private static var failures = 0

    private static func assertEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ label: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        testCount += 1
        if actual != expected {
            failures += 1
            fputs("FAIL \(label) at \(file):\(line)\n  expected: \(expected)\n  actual:   \(actual)\n", stderr)
        }
    }

    private static func assertTrue(
        _ condition: Bool,
        _ label: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        testCount += 1
        if !condition {
            failures += 1
            fputs("FAIL \(label) at \(file):\(line)\n", stderr)
        }
    }

    static func runAll() {
        testFileNaming()
        testFileOps()
        testDeviceMetadata()
        testIPhoneSortLogic()
        testAppSettingsDecoding()
        testToolContract()

        if failures == 0 {
            print("PASS core unit verify (\(testCount) assertions)")
        } else {
            fputs("FAIL core unit verify: \(failures) assertion(s) failed\n", stderr)
            exit(1)
        }
    }

    private static var testCount = 0

    // MARK: - FileNaming

    private static func testFileNaming() {
        assertEqual(FileNaming.paddingWidth(forCount: 0), 3, "paddingWidth zero")
        assertEqual(FileNaming.paddingWidth(forCount: 1), 3, "paddingWidth one")
        assertEqual(FileNaming.paddingWidth(forCount: 99), 3, "paddingWidth 99")
        assertEqual(FileNaming.paddingWidth(forCount: 100), 3, "paddingWidth 100")
        assertEqual(FileNaming.paddingWidth(forCount: 999), 3, "paddingWidth 999")
        assertEqual(FileNaming.paddingWidth(forCount: 1000), 4, "paddingWidth 1000")

        assertEqual(FileNaming.fpsBucket(0), 30, "fpsBucket zero")
        assertEqual(FileNaming.fpsBucket(-1), 30, "fpsBucket negative")
        assertEqual(FileNaming.fpsBucket(29.97), 30, "fpsBucket ~30")
        assertEqual(FileNaming.fpsBucket(46), 60, "fpsBucket nearer 60")
        assertEqual(FileNaming.fpsBucket(59.94), 60, "fpsBucket ~60 high")
        assertEqual(FileNaming.fpsBucket(105), 120, "fpsBucket nearer 120")
        assertEqual(FileNaming.fpsBucket(240), 120, "fpsBucket above 120")

        assertEqual(FileNaming.orientationCode("portrait"), "V", "orientation portrait")
        assertEqual(FileNaming.orientationCode("Portrait"), "V", "orientation Portrait")
        assertEqual(FileNaming.orientationCode("landscape"), "W", "orientation landscape")
        assertEqual(FileNaming.orientationCode("square"), "W", "orientation square")
        assertEqual(FileNaming.orientationCode("unknown"), "W", "orientation unknown")

        assertEqual(FileNaming.resolutionLabel("4K"), "4K", "resolution known 4K")
        assertEqual(FileNaming.resolutionLabel("1080p"), "1080p", "resolution known 1080p")
        assertEqual(FileNaming.resolutionLabel("Unknown"), "SD", "resolution unknown")
        assertEqual(FileNaming.resolutionLabel(""), "SD", "resolution empty")

        assertEqual(FileNaming.metadataMarkers(hasAppleMake: true, hasiPhoneModel: true, hasGPS: true), "🍎📱🌍", "markers all")
        assertEqual(FileNaming.metadataMarkers(hasAppleMake: true, hasiPhoneModel: false, hasGPS: false), "🍎", "markers apple only")
        assertEqual(FileNaming.metadataMarkers(hasAppleMake: false, hasiPhoneModel: true, hasGPS: false), "📱", "markers iphone only")
        assertEqual(FileNaming.metadataMarkers(hasAppleMake: false, hasiPhoneModel: false, hasGPS: true), "🌍", "markers gps only")
        assertEqual(FileNaming.metadataMarkers(hasAppleMake: false, hasiPhoneModel: false, hasGPS: false), "", "markers none")

        let name = FileNaming.standardFileName(
            originalName: "Vacation",
            prefix: "Trip",
            resolutionClass: "4K",
            orientation: "landscape",
            fps: 29.97,
            hasAppleMake: true,
            hasiPhoneModel: true,
            hasGPS: true,
            index: 1,
            padWidth: 3,
            ext: "MOV"
        )
        assertTrue(name.hasSuffix(".mov"), "standardFileName lowercases ext")
        assertTrue(name.contains("Vacation"), "standardFileName includes original")
        assertTrue(name.contains("4K"), "standardFileName includes resolution")
        assertTrue(name.contains("W30"), "standardFileName includes orientation+fps bucket")
        assertTrue(name.contains("🍎📱🌍"), "standardFileName includes markers")
        assertTrue(name.contains("001"), "standardFileName includes padded index")
        assertTrue(name.hasPrefix("Trip "), "standardFileName includes prefix")

        let sanitizedUnsafe = FileNaming.standardFileName(
            originalName: "bad/name",
            prefix: "",
            resolutionClass: "HD",
            orientation: "portrait",
            fps: 60,
            hasAppleMake: false,
            hasiPhoneModel: false,
            hasGPS: false,
            index: 2,
            padWidth: 3,
            ext: "mp4"
        )
        assertTrue(!sanitizedUnsafe.contains("/"), "standardFileName sanitizes slashes")
        assertTrue(sanitizedUnsafe.contains("V60"), "standardFileName portrait fps")
    }

    // MARK: - FileOps

    private static func testFileOps() {
        assertEqual(FileOps.sanitizeFileName("hello"), "hello", "sanitize plain")
        assertEqual(FileOps.sanitizeFileName("bad/name:test"), "bad_name_test", "sanitize invalid chars")
        assertEqual(FileOps.sanitizeFileName("  spaced  "), "spaced", "sanitize trim")
        assertEqual(FileOps.sanitizeFileName("a  b"), "a b", "sanitize collapse double space")
        assertEqual(FileOps.sanitizeFileName(""), "file", "sanitize empty")
        assertEqual(FileOps.sanitizeFileName("."), "file", "sanitize dot")
        assertEqual(FileOps.sanitizeFileName(".."), "file", "sanitize dotdot")

        let root = (NSTemporaryDirectory() as NSString).appendingPathComponent("libra-unit-\(UUID().uuidString)")
        let fm = FileManager.default
        try? fm.createDirectory(atPath: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: root) }

        let first = (root as NSString).appendingPathComponent("clip.mov")
        let second = (root as NSString).appendingPathComponent("clip (1).mov")
        fm.createFile(atPath: first, contents: Data("a".utf8))
        fm.createFile(atPath: second, contents: Data("b".utf8))

        let unique = FileOps.uniquePath(for: first)
        assertEqual(unique, (root as NSString).appendingPathComponent("clip (2).mov"), "uniquePath increments")

        let dryMove = FileOps.moveFile(from: first, to: (root as NSString).appendingPathComponent("moved.mov"), dryRun: true)
        assertEqual(dryMove.status, .success, "dryRun move status")
        assertTrue(fm.fileExists(atPath: first), "dryRun move leaves source")
    }

    // MARK: - DeviceMetadata

    private static func testDeviceMetadata() {
        assertTrue(DeviceMetadata.hasAppleMake(in: ["Apple"]), "apple make exact")
        assertTrue(DeviceMetadata.hasAppleMake(in: ["apple inc"]), "apple make substring")
        assertTrue(!DeviceMetadata.hasAppleMake(in: ["Samsung"]), "non-apple make")
        assertTrue(!DeviceMetadata.hasAppleMake(in: []), "empty make list")

        assertTrue(DeviceMetadata.hasiPhoneModel(in: ["iPhone 15 Pro"]), "iphone model")
        assertTrue(DeviceMetadata.hasiPhoneModel(in: ["IPHONE SE"]), "iphone model case")
        assertTrue(!DeviceMetadata.hasiPhoneModel(in: ["Galaxy S24"]), "non-iphone model")

        let nested: [String: Any] = [
            "Make": "Apple",
            "Device": ["Model": "iPhone 14", "Make": "ignored nested key miss"],
            "empty": ""
        ]
        let makeValues = DeviceMetadata.collectStringValues(from: nested, keys: DeviceMetadata.makeKeys)
        assertTrue(makeValues.contains("Apple"), "collectStringValues top-level make")
        let modelValues = DeviceMetadata.collectStringValues(from: nested, keys: DeviceMetadata.modelKeys)
        assertTrue(modelValues.contains("iPhone 14"), "collectStringValues nested model")
        assertTrue(!modelValues.contains(""), "collectStringValues skips empty")
    }

    // MARK: - IPhoneSortLogic

    private static func testIPhoneSortLogic() {
        let both = IPhoneSortLogic.classify(hasAppleMake: true, hasiPhoneModel: true, make: "Apple", model: "iPhone 16")
        assertTrue(both.isIPhoneFolder, "classify both markers → iPhone folder")
        assertEqual(both.markers, "🍎📱", "classify both markers string")

        let appleOnly = IPhoneSortLogic.classify(hasAppleMake: true, hasiPhoneModel: false, make: "Apple", model: "")
        assertTrue(appleOnly.isIPhoneFolder, "classify apple only → iPhone folder")
        assertEqual(appleOnly.markers, "🍎", "classify apple only markers")

        let modelOnly = IPhoneSortLogic.classify(hasAppleMake: false, hasiPhoneModel: true, make: "", model: "iPhone 15")
        assertTrue(modelOnly.isIPhoneFolder, "classify model only → iPhone folder")
        assertEqual(modelOnly.markers, "📱", "classify model only markers")

        let neither = IPhoneSortLogic.classify(hasAppleMake: false, hasiPhoneModel: false, make: "Samsung", model: "Galaxy")
        assertTrue(!neither.isIPhoneFolder, "classify samsung → not iPhone folder")
        assertEqual(neither.markers, "", "classify samsung markers empty")
        assertTrue(neither.note.contains("Samsung"), "classify samsung note")

        let missing = IPhoneSortLogic.classify(hasAppleMake: false, hasiPhoneModel: false, make: "", model: "")
        assertTrue(!missing.isIPhoneFolder, "classify missing metadata → not iPhone folder")
        assertEqual(missing.note, "Missing Make/Model metadata", "classify missing note")
    }

    // MARK: - AppSettings

    private static func testAppSettingsDecoding() {
        let minimal = "{}".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(AppSettings.self, from: minimal)
        assertTrue(decoded != nil, "AppSettings decodes empty JSON")
        assertEqual(decoded?.dryRunDefault, true, "AppSettings default dryRun")
        assertTrue(decoded?.videoExtensions.contains("mov") == true, "AppSettings default videoExtensions")
        assertTrue(decoded?.imageExtensions.contains("heic") == true, "AppSettings default imageExtensions")

        let partial = """
        {"dryRunDefault": false, "videoExtensions": ["mp4"]}
        """.data(using: .utf8)!
        let partialDecoded = try? JSONDecoder().decode(AppSettings.self, from: partial)
        assertEqual(partialDecoded?.dryRunDefault, false, "AppSettings partial dryRun")
        assertEqual(partialDecoded?.imageExtensions, AppSettings.default.imageExtensions, "AppSettings partial keeps image defaults")
        assertEqual(partialDecoded?.videoExtensions, ["mp4"], "AppSettings partial videoExtensions")
    }

    // MARK: - Tool contract

    private static func testToolContract() {
        let cases = Tool.allCases.map { String(describing: $0) }
        let expected = ["provid", "vidres", "keepName", "promax", "maxvid", "iphoneSorter", "slomo", "oneMin", "gps"]
        assertEqual(cases, expected, "Tool enum declaration order")

        assertTrue(Tool.iphoneSorter.acceptsImages, "iphoneSorter accepts images")
        assertTrue(!Tool.vidres.acceptsImages, "vidres rejects images")

        for tool in Tool.allCases {
            assertTrue(!tool.title.isEmpty, "tool title non-empty: \(tool)")
            assertTrue(!tool.description.isEmpty, "tool description non-empty: \(tool)")
            assertTrue(!tool.category.isEmpty, "tool category non-empty: \(tool)")
        }
    }
}

@main
struct CoreUnitVerifyMain {
    static func main() {
        CoreUnitVerify.runAll()
    }
}
