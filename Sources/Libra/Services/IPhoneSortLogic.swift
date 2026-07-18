import Foundation

@MainActor
enum IPhoneSortLogic {
    struct Classification {
        let isIPhoneFolder: Bool
        let markers: String
        let note: String
    }

    static func classify(hasAppleMake: Bool, hasiPhoneModel: Bool, make: String, model: String) -> Classification {
        let isIPhoneFolder = hasAppleMake || hasiPhoneModel
        let markers = FileNaming.metadataMarkers(
            hasAppleMake: hasAppleMake,
            hasiPhoneModel: hasiPhoneModel,
            hasGPS: false
        )
        let note: String
        if make.isEmpty && model.isEmpty {
            note = isIPhoneFolder
                ? "Classified from available device metadata markers"
                : "Missing Make/Model metadata"
        } else {
            note = "Make=\(make.isEmpty ? "—" : make) · Model=\(model.isEmpty ? "—" : model)"
        }
        return Classification(isIPhoneFolder: isIPhoneFolder, markers: markers, note: note)
    }
}
