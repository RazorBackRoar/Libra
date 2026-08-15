import SwiftUI

enum MediaBrowserFilter: Hashable, Identifiable {
    case all
    case resolution(String)
    case gps
    case appleMake
    case iPhoneModel
    case appleDevice
    case both
    case duplicates

    var id: String {
        switch self {
        case .all: return "all"
        case .resolution(let label): return "res-\(label)"
        case .gps: return "gps"
        case .appleMake: return "apple-make"
        case .iPhoneModel: return "iphone-model"
        case .appleDevice: return "apple-device"
        case .both: return "both"
        case .duplicates: return "duplicates"
        }
    }

    var title: String {
        switch self {
        case .all: return "All Files"
        case .resolution(let label): return label
        case .gps: return "Has location"
        case .appleMake: return "Apple make"
        case .iPhoneModel: return "iPhone model"
        case .appleDevice: return "Apple device"
        case .both: return "Apple make + iPhone model"
        case .duplicates: return "Likely duplicates"
        }
    }

    func matches(_ file: VideoInfo, duplicateExtras: Set<String> = []) -> Bool {
        switch self {
        case .all:
            return true
        case .resolution(let label):
            return file.resolutionClass == label
        case .gps:
            return file.hasGPS
        case .appleMake:
            return file.hasAppleMake
        case .iPhoneModel:
            return file.hasiPhoneModel
        case .appleDevice:
            return file.isApple
        case .both:
            return file.hasAppleMake && file.hasiPhoneModel
        case .duplicates:
            return duplicateExtras.contains(file.path)
        }
    }
}

struct CountPills: View {
    let files: [VideoInfo]
    var tool: Tool? = nil
    var onSelect: ((MediaBrowserFilter) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(filter: .all, label: "Files", value: files.count)
                if tool == .iphoneSorter {
                    pill(filter: .appleMake, label: "Apple make", value: files.filter { $0.hasAppleMake }.count)
                    pill(filter: .iPhoneModel, label: "iPhone model", value: files.filter { $0.hasiPhoneModel }.count)
                    pill(filter: .both, label: "Apple make + iPhone model", value: files.filter { $0.hasAppleMake && $0.hasiPhoneModel }.count)
                } else {
                    ForEach(VideoInfo.resolutionClasses, id: \.self) { label in
                        pill(
                            filter: .resolution(label),
                            label: label,
                            value: files.filter { $0.resolutionClass == label }.count
                        )
                    }
                    pill(filter: .gps, label: "Has location", value: files.filter { $0.hasGPS }.count)
                    pill(filter: .appleDevice, label: "Apple device", value: files.filter { $0.isApple }.count)
                    pill(
                        filter: .duplicates,
                        label: "Likely duplicates",
                        value: DuplicateDetector.extraCount(in: files)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func pill(filter: MediaBrowserFilter, label: String, value: Int) -> some View {
        CountPill(label: label, value: value) {
            guard value > 0 else { return }
            onSelect?(filter)
        }
    }
}

struct CountPill: View {
    let label: String
    let value: Int
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.yellow)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(.systemGray).opacity(0.2))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(value == 0 || action == nil)
        .opacity(value == 0 ? 0.55 : 1)
        .help(value == 0 ? "No \(label) files" : "Browse \(label) files")
    }
}
