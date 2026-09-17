import SwiftUI

enum MediaBrowserFilter: Hashable, Identifiable {
    case all
    case resolution(String)
    case gps
    case appleMake
    case iPhoneModel
    case appleDevice
    case both
    case otherApple
    case notApple
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
        case .otherApple: return "other-apple"
        case .notApple: return "not-apple"
        case .duplicates: return "duplicates"
        }
    }

    var title: String {
        switch self {
        case .all: return "All videos"
        case .resolution(let label): return label
        case .gps: return "Has location"
        case .appleMake: return "Apple make"
        case .iPhoneModel: return "iPhone model"
        case .appleDevice: return "Apple device"
        case .both: return "Apple make + iPhone model"
        case .otherApple: return "Other Apple"
        case .notApple: return "Not Apple"
        case .duplicates: return "Likely duplicates (same size, duration, format)"
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
        case .otherApple:
            return file.hasAppleMake && !file.hasiPhoneModel
        case .notApple:
            return !file.hasAppleMake && !file.hasiPhoneModel
        case .duplicates:
            return duplicateExtras.contains(file.path)
        }
    }
}

struct CountPills: View {
    let files: [VideoInfo]
    var tool: Tool? = nil
    /// Non-nil on GPS: pills show which map filter is active instead of
    /// opening the category browser.
    var selection: MediaBrowserFilter? = nil
    var onSelect: ((MediaBrowserFilter) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(filter: .all, label: "Videos", value: files.count)
                if tool == .iphoneSorter {
                    shownPill(filter: .iPhoneModel, label: "iPhone", value: files.filter { $0.hasiPhoneModel }.count)
                    shownPill(filter: .otherApple, label: "Other Apple", value: files.filter { $0.hasAppleMake && !$0.hasiPhoneModel }.count)
                    shownPill(filter: .notApple, label: "Not Apple", value: files.filter { !$0.hasAppleMake && !$0.hasiPhoneModel }.count)
                } else {
                    ForEach(VideoInfo.resolutionClasses, id: \.self) { label in
                        shownPill(
                            filter: .resolution(label),
                            label: label,
                            value: files.filter { $0.resolutionClass == label }.count
                        )
                    }
                    shownPill(filter: .gps, label: "Has location", value: files.filter { $0.hasGPS }.count)
                    shownPill(filter: .appleDevice, label: "Apple device", value: files.filter { $0.isApple }.count)
                    shownPill(
                        filter: .duplicates,
                        label: "Likely duplicates",
                        value: DuplicateDetector.extraCount(in: files),
                        help: "Same size, duration, and video format — not a byte-for-byte match"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func shownPill(filter: MediaBrowserFilter, label: String, value: Int, help: String? = nil) -> some View {
        if value > 0 {
            pill(filter: filter, label: label, value: value, help: help)
        }
    }

    @ViewBuilder
    private func pill(filter: MediaBrowserFilter, label: String, value: Int, help: String? = nil) -> some View {
        let defaultHelp =
            value == 0
            ? "No \(label.lowercased())"
            : selection != nil
                ? (filter == .all ? "Show all pins" : "Show only \(label.lowercased()) on the map")
                : "Browse \(label.lowercased())"
        CountPill(label: label, value: value, helpText: help ?? defaultHelp, isSelected: selection == filter) {
            guard value > 0 else { return }
            onSelect?(filter)
        }
    }
}

struct CountPill: View {
    let label: String
    let value: Int
    var helpText: String? = nil
    var isSelected: Bool = false
    var action: (() -> Void)? = nil
    @State private var hovering = false

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? .black : LibraTheme.yellow)
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .black.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    if isSelected {
                        Capsule().fill(
                            LinearGradient(
                                colors: [LibraTheme.yellow, LibraTheme.gold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.45), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    } else {
                        Capsule().fill(LibraTheme.panel)
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color.white.opacity(hovering ? 0.16 : 0.08), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    }
                }
            )
            .overlay(
                Capsule().stroke(
                    isSelected
                        ? LibraTheme.amber.opacity(0.7)
                        : hovering ? LibraTheme.yellow.opacity(0.45) : LibraTheme.hairline,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(value == 0 || action == nil)
        .opacity(value == 0 ? 0.55 : 1)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .help(helpText ?? (value == 0 ? "No \(label.lowercased())" : label))
        .accessibilityLabel("\(value) \(label)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
