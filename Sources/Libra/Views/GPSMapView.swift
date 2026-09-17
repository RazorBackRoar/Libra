import SwiftUI
import MapKit

/// Apple Maps surface — native MapKit only, no thumbnails or media playback.
/// `.primary` (the GPS tool): always expanded, fills the workspace, pin
/// selection shows a bottom overlay of glossy filename buttons.
/// `.compact` (other tools): a collapsible 168-pt mini-map.
struct GPSMapPanel: View {
    enum Presentation {
        case compact
        case primary
    }

    let files: [VideoInfo]
    /// file.path → place name from ToolState's explicit Resolve — the map
    /// never geocodes itself.
    var resolvedNames: [String: String] = [:]
    /// Map-only visual filter — never changes Preview/Write scope.
    var filter: MediaBrowserFilter = .all
    var presentation: Presentation = .compact
    var startsExpanded: Bool = false

    @StateObject private var model = GPSMapModel()
    @State private var expanded = false

    private var isPrimary: Bool { presentation == .primary }

    var body: some View {
        let coordinateFiles = files.filter(\.hasCoordinates)
        let totals = GPSMediaCounts.totals(in: coordinateFiles)
        VStack(spacing: 10) {
            if isPrimary {
                headerRow(photos: totals.photos, videos: totals.videos)
            } else {
                collapseHeader(photos: totals.photos, videos: totals.videos)
            }

            if isPrimary {
                primaryMap
            } else if expanded {
                compactMap
            }
        }
        .padding(isPrimary || expanded ? 12 : 10)
        .libraPanel()
        .onAppear {
            expanded = startsExpanded
            model.update(files: files, resolvedNames: resolvedNames, filter: filter)
        }
        .onChange(of: files.map(\.path)) { _, _ in
            if startsExpanded, files.contains(where: \.hasCoordinates) {
                expanded = true
            }
            model.update(files: files, resolvedNames: resolvedNames, filter: filter)
        }
        .onChange(of: resolvedNames) { _, names in
            model.update(files: files, resolvedNames: names, filter: filter)
        }
        .onChange(of: filter) { _, active in
            model.update(files: files, resolvedNames: resolvedNames, filter: active)
        }
        .onChange(of: expanded) { _, isExpanded in
            if isExpanded {
                model.update(files: files, resolvedNames: resolvedNames, filter: filter)
            }
        }
    }

    private func headerRow(photos: Int, videos: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "map")
                .foregroundColor(LibraTheme.yellow)
            Text("City / GPS Map")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Spacer(minLength: 8)
            Text(summaryText(photos: photos, videos: videos))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private func collapseHeader(photos: Int, videos: Int) -> some View {
        Button {
            expanded.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "map")
                    .foregroundColor(LibraTheme.yellow)
                Text("City / GPS Map")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer(minLength: 8)
                Text(summaryText(photos: photos, videos: videos))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var mapSurface: some View {
        // Map(selection:) does not reliably deliver taps to custom Annotation
        // content on macOS, so selection is resolved manually: a tap within
        // ~24pt of a pin selects it, anywhere else clears the selection.
        MapReader { proxy in
            Map(position: $model.cameraPosition, selection: $model.selectedClusterID) {
                ForEach(model.clusters) { cluster in
                    Annotation(cluster.pinTitle, coordinate: cluster.coordinate, anchor: .bottom) {
                        GPSMapPin(selected: model.selectedClusterID == cluster.id)
                    }
                    .tag(cluster.id)
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { point in
                selectCluster(nearScreenPoint: point, proxy: proxy)
            }
        }
    }

    private func selectCluster(nearScreenPoint point: CGPoint, proxy: MapProxy) {
        var best: (id: String, distance: CGFloat)?
        for cluster in model.clusters {
            guard let pinPoint = proxy.convert(cluster.coordinate, to: .local) else { continue }
            // Pins anchor at their tail tip; the visible dot sits ~10pt above.
            let distance = hypot(pinPoint.x - point.x, pinPoint.y - point.y)
            if distance < 24, best == nil || distance < best!.distance {
                best = (cluster.id, distance)
            }
        }
        model.selectedClusterID = best?.id
    }

    /// Primary mode: the map owns the space. Status messages float centered;
    /// the selected location docks as a names-only card at the bottom, clear
    /// of MapKit's scale/attribution edge.
    private var primaryMap: some View {
        ZStack {
            mapSurface

            if let status = mapStatusMessage {
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(LibraTheme.hairline, lineWidth: 1)
                    )
                    .padding()
                    .allowsHitTesting(false)
            }

            if let selected = model.selectedCluster {
                VStack {
                    Spacer()
                    selectedLocationOverlay(selected)
                }
                .padding(10)
                .padding(.bottom, 22)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(LibraTheme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var compactMap: some View {
        VStack(spacing: 8) {
            mapSurface
                .frame(height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LibraTheme.hairline, lineWidth: 1)
                )

            if let selected = model.selectedCluster {
                selectedLocationOverlay(selected)
            } else {
                Text("Click a yellow pin to see every video at that city.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var mapStatusMessage: String? {
        if model.isClustering { return "Placing videos on the map…" }
        if files.isEmpty { return "Drop videos to place them on the map." }
        if !files.contains(where: \.hasCoordinates) {
            return "No GPS coordinates found — these videos will use No-GPS/."
        }
        if model.clusters.isEmpty { return "No mapped videos match this filter." }
        return nil
    }

    private func summaryText(photos: Int, videos: Int) -> String {
        let places = model.clusters.count
        return "\(GPSMediaCounts.label(photos: photos, videos: videos)) · \(places) place\(places == 1 ? "" : "s") · 5 mi / city"
    }

    /// Names only — no thumbnails, metadata rows, or playback. Buttons open
    /// the file externally; the context menu can reveal it in Finder.
    private func selectedLocationOverlay(_ cluster: GPSLocationCluster) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(LibraTheme.yellow)
                Text(
                    cluster.placeName
                        ?? String(format: "%.4f, %.4f", cluster.latitude, cluster.longitude)
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                Spacer(minLength: 8)
                Text(cluster.mediaCountLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(LibraTheme.gold)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(cluster.files) { file in
                        Button {
                            MediaOpen.open(file.path)
                        } label: {
                            Text("\(file.name).\(file.ext)")
                                .lineLimit(1)
                        }
                        .buttonStyle(LibraFileButtonStyle())
                        .help("Open \(file.name).\(file.ext)")
                        .accessibilityLabel("Open \(file.name).\(file.ext)")
                        .contextMenu {
                            Button("Open") { MediaOpen.open(file.path) }
                            Button("Reveal in Finder") { MediaOpen.reveal(file.path) }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 30)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(LibraTheme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected location")
    }
}

/// Slimmer yellow map pin than the default MapKit Marker balloon.
private struct GPSMapPin: View {
    var selected: Bool

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [LibraTheme.yellow, LibraTheme.gold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: selected ? 12 : 10, height: selected ? 12 : 10)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.45), lineWidth: 0.8)
                )
                .shadow(color: LibraTheme.yellow.opacity(0.5), radius: selected ? 4 : 2, y: 1)
            Capsule()
                .fill(LibraTheme.gold)
                .frame(width: 2, height: 5)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
        .accessibilityLabel(selected ? "Selected map pin" : "Map pin")
    }
}
