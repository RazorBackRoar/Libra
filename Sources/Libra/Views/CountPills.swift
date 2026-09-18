import SwiftUI

enum MediaBrowserFilter: Hashable, Identifiable {
    case all
    case resolution(String)
    case fps(Int)
    case gps
    case noGps
    case appleMake
    case iPhoneModel
    case appleDevice
    case both
    case otherApple
    case notApple
    case unknown

    var id: String {
        switch self {
        case .all: return "all"
        case .resolution(let label): return "res-\(label)"
        case .fps(let value): return "fps-\(value)"
        case .gps: return "gps"
        case .noGps: return "no-gps"
        case .appleMake: return "apple-make"
        case .iPhoneModel: return "iphone-model"
        case .appleDevice: return "apple-device"
        case .both: return "both"
        case .otherApple: return "other-apple"
        case .notApple: return "not-apple"
        case .unknown: return "unknown"
        }
    }

    var title: String {
        switch self {
        case .all: return "All videos"
        case .resolution(let label): return label
        case .fps(let value): return "\(value)"
        case .gps: return "GPS"
        case .noGps: return "No GPS"
        case .appleMake: return "Apple"
        case .iPhoneModel: return "iPhone"
        case .appleDevice: return "Apple device"
        case .both: return "Apple make + iPhone model"
        case .otherApple: return "Other Apple"
        case .notApple: return "Not Apple"
        case .unknown: return "Unknown"
        }
    }

    func matches(_ file: VideoInfo) -> Bool {
        switch self {
        case .all:
            return true
        case .resolution(let label):
            return file.resolutionClass == label
        case .fps(let value):
            return FileNaming.fpsBucket(file.fps) == value
        case .gps:
            return file.hasCoordinates
        case .noGps:
            return !file.hasCoordinates
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
        case .unknown:
            return !file.isApple && file.make.isEmpty && file.model.isEmpty
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
                    // Fixed contract order: SD → 720p → HD → 1080p → FHD →
                    // QHD → 4K, then bare FPS values, then device makes.
                    ForEach(VideoInfo.resolutionClasses.reversed(), id: \.self) { label in
                        shownPill(
                            filter: .resolution(label),
                            label: label,
                            value: files.filter { $0.resolutionClass == label }.count
                        )
                    }
                    if tool != .photoSweep {
                        ForEach(FileNaming.fpsBuckets, id: \.self) { bucket in
                            shownPill(
                                filter: .fps(bucket),
                                label: "\(bucket)",
                                value: files.filter { FileNaming.fpsBucket($0.fps) == bucket }.count
                            )
                        }
                    }
                    shownPill(filter: .iPhoneModel, label: "iPhone", value: files.filter { $0.hasiPhoneModel }.count)
                    shownPill(filter: .appleMake, label: "Apple", value: files.filter { $0.hasAppleMake }.count)
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

/// Gold-outlined capsule — same language as the Back button: dark fill,
/// visible gold edge, white label with a gold count. Selected inverts to
/// the gold gradient so the active filter is unmistakable.
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
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .black : .white)
                Text("\(value)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .black.opacity(0.7) : LibraTheme.yellow)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
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
                        ? LibraTheme.amber.opacity(0.8)
                        : hovering ? LibraTheme.yellow.opacity(0.7) : LibraTheme.gold.opacity(0.45),
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
