import Foundation

enum IPhoneSortLogic {
    struct Classification {
        let isIPhoneFolder: Bool
        let markers: String
        let note: String
    }

    static func classify(hasAppleMake: Bool, hasiPhoneModel: Bool, make: String, model: String) -> Classification {
        let isIPhoneFolder = hasAppleMake || hasiPhoneModel
        let markers: String
        switch (hasAppleMake, hasiPhoneModel) {
        case (true, true): markers = "🍎📱"
        case (true, false): markers = "🍎"
        case (false, true): markers = "📱"
        case (false, false): markers = ""
        }
        let note: String
        if make.isEmpty && model.isEmpty {
            note = isIPhoneFolder
                ? "Classified from available device metadata markers"
                : "Missing Make/Model metadata · kept original name"
        } else {
            note = "Make=\(make.isEmpty ? "—" : make) · Model=\(model.isEmpty ? "—" : model)"
        }
        return Classification(isIPhoneFolder: isIPhoneFolder, markers: markers, note: note)
    }

    static func paddingWidth(forCount count: Int) -> Int {
        max(3, String(max(count, 1)).count)
    }

    static func iPhoneFileName(baseName: String, markers: String, index: Int, padWidth: Int, ext: String) -> String {
        let base = FileOps.sanitizeFileName(baseName)
        let number = String(format: "%0\(padWidth)d", index)
        let normalizedExt = ext.lowercased()
        if markers.isEmpty {
            return "\(base) \(number).\(normalizedExt)"
        }
        return "\(base) \(markers) \(number).\(normalizedExt)"
    }

    static func notIPhoneFileName(baseName: String, ext: String) -> String {
        FileOps.sanitizeFileName(baseName) + "." + ext.lowercased()
    }
}
