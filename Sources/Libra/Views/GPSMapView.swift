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
    /// Map-only visual filter — never changes Preview/Write scope. A binding
    /// in primary mode so the floating pills can drive it.
    var filter: Binding<MediaBrowserFilter>? = nil
    var presentation: Presentation = .compact
    var startsExpanded: Bool = false
    /// Primary mode only: the map itself is the drop/browse surface.
    var onDrop: (([String]) -> Void)? = nil
    var onBrowse: (() -> Void)? = nil
    var onSelectFiles: (() -> Void)? = nil

    @StateObject private var model = GPSMapModel()
    @State private var expanded = false
    @State private var mapDropActive = false

    private var isPrimary: Bool { presentation == .primary }
    private var activeFilter: MediaBrowserFilter { filter?.wrappedValue ?? .all }

    var body: some View {
        let coordinateFiles = files.filter(\.hasCoordinates)
        let totals = GPSMediaCounts.totals(in: coordinateFiles)
        VStack(spacing: 10) {
            if isPrimary {
                primaryMap(totals: totals)
            } else {
                // Gold button pinned at the bottom; the map expands upward
                // above it when opened.
                if expanded {
                    compactMap
                        .transition(
                            .move(edge: .bottom).combined(with: .opacity))
                }
                goldCollapseButton(photos: totals.photos, videos: totals.videos)
            }
        }
        .padding(isPrimary || expanded ? 12 : 0)
        .modifier(CollapsedPanel(isPanelled: isPrimary || expanded))
        .onAppear {
            expanded = startsExpanded
            model.update(files: files, resolvedNames: resolvedNames, filter: activeFilter)
        }
        .onChange(of: files.map(\.path)) { _, _ in
            if startsExpanded, files.contains(where: \.hasCoordinates) {
                expanded = true
            }
            model.update(files: files, resolvedNames: resolvedNames, filter: activeFilter)
        }
        .onChange(of: resolvedNames) { _, names in
            model.update(files: files, resolvedNames: names, filter: activeFilter)
        }
        .onChange(of: filter?.wrappedValue) { _, _ in
            model.update(files: files, resolvedNames: resolvedNames, filter: activeFilter)
        }
        .onChange(of: expanded) { _, isExpanded in
            if isExpanded {
                model.update(files: files, resolvedNames: resolvedNames, filter: activeFilter)
            }
        }
    }

    /// Collapsed state for non-GPS tools: a gold button that expands the
    /// location details upward when clicked. The map is hidden until asked
    /// for — nothing is displayed openly.
    private func goldCollapseButton(photos: Int, videos: Int) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                expanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .foregroundColor(.black)
                Text("Location details")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                Spacer(minLength: 8)
                Text(summaryText(photos: photos, videos: videos))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.black.opacity(0.65))
                    .lineLimit(1)
                Image(systemName: expanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [LibraTheme.yellow, LibraTheme.gold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .shadow(color: LibraTheme.yellow.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            expanded ? "Hide location details" : "Show location details")
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

    /// Primary mode: the map owns the whole workspace — it is the drop
    /// surface, hosts floating chips (stats, filter pills, Add menu), and
    /// shows the centered empty state. The selected location docks as a
    /// names-only card at the bottom, clear of MapKit's scale/attribution.
    private func primaryMap(totals: (photos: Int, videos: Int)) -> some View {
        ZStack {
            mapSurface
                .onDrop(of: [.fileURL], isTargeted: $mapDropActive) { providers in
                    guard let onDrop else { return false }
                    DropZone.loadPaths(from: providers, completion: onDrop)
                    return true
                }

            if !files.isEmpty {
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        statsChip(totals: totals)
                        if let filter {
                            CountPills(
                                files: files, tool: .gps,
                                selection: filter.wrappedValue
                            ) { picked in
                                filter.wrappedValue = filter.wrappedValue == picked ? .all : picked
                            }
                        }
                        Spacer(minLength: 8)
                        addMenu
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
            }

            if files.isEmpty {
                emptyState
            } else if let status = mapStatusMessage {
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
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    selectedLocationOverlay(selected)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: model.selectedClusterID)
        .frame(maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    mapDropActive ? LibraTheme.gold : LibraTheme.hairline,
                    lineWidth: mapDropActive ? 1.5 : 1
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drop videos here")
    }

    /// Centered empty state — the map's own drop affordance, no dashed box.
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(LibraTheme.yellow)
            Text("Drop videos to place them on the map.")
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Folders or videos.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button("Open Folder…") { onBrowse?() }
                    .buttonStyle(LibraPrimaryButtonStyle(compact: true))
                    .accessibilityLabel("Open Folder")
                Button("Select Videos…") { onSelectFiles?() }
                    .buttonStyle(LibraSecondaryButtonStyle(compact: true))
                    .accessibilityLabel("Select Videos")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LibraTheme.hairline, lineWidth: 1)
        )
        .padding()
    }

    /// Floating glass capsule — counts only; the cluster radius is a
    /// clustering constant, not user-facing information.
    private func statsChip(totals: (photos: Int, videos: Int)) -> some View {
        Text(
            "\(GPSMediaCounts.label(photos: totals.photos, videos: totals.videos)) · \(model.clusters.count) place\(model.clusters.count == 1 ? "" : "s")"
        )
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.white)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(LibraTheme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    /// Top-trailing Add menu — keeps extra drops browseable after the first
    /// scan without a persistent drop box.
    private var addMenu: some View {
        Menu {
            Button("Open Folder…") { onBrowse?() }
            Button("Select Videos…") { onSelectFiles?() }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(LibraTheme.yellow)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(LibraTheme.hairline, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Add videos")
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
        if !files.contains(where: \.hasCoordinates) {
            return "No GPS coordinates found — these videos will use No-GPS/."
        }
        if model.clusters.isEmpty { return "No mapped videos match this filter." }
        return nil
    }

    private func summaryText(photos: Int, videos: Int) -> String {
        let places = model.clusters.count
        return "\(GPSMediaCounts.label(photos: photos, videos: videos)) · \(places) place\(places == 1 ? "" : "s")"
    }

    /// Names only — no thumbnails, metadata rows, or playback. Docks flush
    /// against the map's bottom edge, fully opaque; buttons open the file
    /// externally and the context menu reveals it in Finder.
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LibraTheme.panel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LibraTheme.gold.opacity(0.45))
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected location")
    }
}

/// Applies the dark glass panel only when the section is expanded (or
/// primary) — a collapsed compact section is just the gold button itself.
private struct CollapsedPanel: ViewModifier {
    let isPanelled: Bool

    func body(content: Content) -> some View {
        if isPanelled {
            content.libraPanel()
        } else {
            content
        }
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
