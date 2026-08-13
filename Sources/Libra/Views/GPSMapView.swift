import SwiftUI
import MapKit

/// Lightweight Apple Maps mini-map — native MapKit only.
/// Caller should only present this when `files` contain coordinates.
struct GPSMapPanel: View {
    let files: [VideoInfo]
    var startsExpanded: Bool = false
    @StateObject private var model = GPSMapModel()
    @State private var expanded = false

    var body: some View {
        let coordinateFiles = files.filter(\.hasCoordinates)
        let totals = GPSMediaCounts.totals(in: coordinateFiles)
        VStack(spacing: 10) {
            Button {
                expanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "map")
                        .foregroundColor(.yellow)
                    Text("City / GPS Map")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer(minLength: 8)
                    Text(summaryText(photos: totals.photos, videos: totals.videos))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
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
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )

                if let selected = model.selectedCluster {
                    selectedClusterCard(selected)
                } else {
                    Text("Click a yellow pin to see every video at that city (5 mi + same city).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray).opacity(0.12))
        .cornerRadius(12)
        .onAppear {
            expanded = startsExpanded
            model.update(files: files)
        }
        .onChange(of: files.map(\.path)) { _, _ in
            model.update(files: files)
        }
    }

    private func summaryText(photos: Int, videos: Int) -> String {
        let places = model.clusters.count
        return "\(GPSMediaCounts.label(photos: photos, videos: videos)) · \(places) place\(places == 1 ? "" : "s") · 5 mi / city"
    }

    @ViewBuilder
    private func selectedClusterCard(_ cluster: GPSLocationCluster) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                Text(cluster.placeName ?? "Resolving city…")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(cluster.mediaCountLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Text("All media within 5 miles, merged by city when names match")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(String(format: "%.5f, %.5f", cluster.latitude, cluster.longitude))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(cluster.files) { file in
                        Button {
                            MediaOpen.open(file.path)
                        } label: {
                            Text(file.name + "." + file.ext)
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .help("Open \(file.name).\(file.ext)")
                        .contextMenu {
                            Button("Open") { MediaOpen.open(file.path) }
                            Button("Reveal in Finder") { MediaOpen.reveal(file.path) }
                        }
                    }
                }
            }
            .frame(maxHeight: 140)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.35))
        .cornerRadius(8)
    }
}

/// Slimmer yellow map pin than the default MapKit Marker balloon.
private struct GPSMapPin: View {
    var selected: Bool

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.yellow)
                .frame(width: selected ? 12 : 10, height: selected ? 12 : 10)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.45), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.35), radius: selected ? 2 : 1, y: 1)
            Capsule()
                .fill(Color.yellow)
                .frame(width: 2, height: 5)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
        .accessibilityHidden(true)
    }
}
