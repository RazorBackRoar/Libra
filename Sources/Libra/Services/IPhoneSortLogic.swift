import Foundation

enum IPhoneSortLogic {
    enum Folder: String, CaseIterable {
        case iPhone = "iPhone"
        case otherApple = "Other Apple"
        case notApple = "Not Apple"
    }

    struct Classification {
        let folder: Folder
        let markers: String
        let note: String

        var isIPhoneFolder: Bool { folder == .iPhone }
    }

    static func classify(hasAppleMake: Bool, hasiPhoneModel: Bool, make: String, model: String) -> Classification {
        let folder: Folder
        if hasiPhoneModel {
            folder = .iPhone
        } else if hasAppleMake {
            folder = .otherApple
        } else {
            folder = .notApple
        }
        let markers = FileNaming.metadataMarkers(
            hasAppleMake: hasAppleMake,
            hasiPhoneModel: hasiPhoneModel,
            hasGPS: false
        )
        let note: String
        if make.isEmpty && model.isEmpty {
            switch folder {
            case .iPhone:
                note = "Classified from iPhone model metadata"
            case .otherApple:
                note = "Apple make without an iPhone model"
            case .notApple:
                note = "Missing Make/Model metadata"
            }
        } else {
            note = "Make=\(make.isEmpty ? "—" : make) · Model=\(model.isEmpty ? "—" : model)"
        }
        return Classification(folder: folder, markers: markers, note: note)
    }
}
