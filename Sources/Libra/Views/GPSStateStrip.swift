import SwiftUI

struct GPSCitySummary: Identifiable {
    let name: String
    var files: [VideoInfo]

    var id: String { name }

    var mediaCountLabel: String {
        let counts = GPSMediaCounts.totals(in: files)
        return GPSMediaCounts.label(photos: counts.photos, videos: counts.videos)
    }
}

struct GPSStateSummary: Identifiable {
    let name: String
    var cities: [GPSCitySummary]

    var id: String { name }
    var fileCount: Int { cities.reduce(0) { $0 + $1.files.count } }
}

/// Splits resolved "City, State" place names into state → city summaries.
/// Pure transformation of ToolState's explicit resolve — never geocodes.
enum GPSStateGrouping {
    static func summarize(
        files: [VideoInfo],
        resolvedNames: [String: String]
    ) -> [GPSStateSummary] {
        var stateCities: [String: [String: [VideoInfo]]] = [:]
        for file in files {
            guard let place = resolvedNames[file.path]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !place.isEmpty
            else { continue }
            let parts = place.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard parts.count >= 2, let state = parts.last else { continue }
            let city = parts.dropLast().joined(separator: ", ")
            stateCities[state, default: [:]][city, default: []].append(file)
        }
        return stateCities.map { state, cities in
            GPSStateSummary(
                name: state,
                cities: cities.map { name, files in
                    GPSCitySummary(
                        name: name,
                        files: files.sorted {
                            ($0.creationTime ?? .distantFuture, $0.path)
                                < ($1.creationTime ?? .distantFuture, $1.path)
                        })
                }
                .sorted {
                    $0.files.count != $1.files.count
                        ? $0.files.count > $1.files.count : $0.name < $1.name
                })
        }
        .sorted {
            $0.fileCount != $1.fileCount
                ? $0.fileCount > $1.fileCount : $0.name < $1.name
        }
    }
}

/// Big gold state buttons pinned at the right edge of the GPS header —
/// the largest state sits rightmost, each smaller state to its left.
/// Clicking a state pops a panel of its cities with per-city media counts;
/// right-clicking a city reveals that city's media in Finder.
struct GPSStateStrip: View {
    let files: [VideoInfo]
    let resolvedNames: [String: String]
    @State private var openState: String?

    private var states: [GPSStateSummary] {
        GPSStateGrouping.summarize(files: files, resolvedNames: resolvedNames)
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(states.reversed()) { state in
                stateButton(state)
            }
        }
    }

    private func stateButton(_ state: GPSStateSummary) -> some View {
        Button {
            openState = state.id
        } label: {
            HStack(spacing: 6) {
                Text(state.name)
                    .font(.system(size: 13, weight: .bold))
                Text("\(state.fileCount)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.black.opacity(0.65))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    Capsule().fill(
                        LinearGradient(
                            colors: [LibraTheme.yellow, LibraTheme.gold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                }
            )
            .shadow(color: LibraTheme.yellow.opacity(0.25), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .help("Cities in \(state.name)")
        .accessibilityLabel("\(state.name), \(state.fileCount) items")
        .popover(
            isPresented: Binding(
                get: { openState == state.id },
                set: { if !$0 { openState = nil } }
            ),
            arrowEdge: .bottom
        ) {
            citiesPopover(state)
        }
    }

    private func citiesPopover(_ state: GPSStateSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(state.name)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
            ForEach(state.cities) { city in
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(LibraTheme.yellow)
                    Text(city.name)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 12)
                    Text(city.mediaCountLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Reveal in Finder") {
                        MediaOpen.reveal(city.files.map(\.path))
                    }
                }
            }
            Text("Right-click a city to reveal it in Finder.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 8)
        }
        .padding(.bottom, 10)
        .frame(minWidth: 250)
        .background(LibraTheme.panel)
    }
}
