import SwiftUI
import MapKit

/// Lightweight Apple Maps mini-map — native MapKit only.
struct GPSMapPanel: View {
    let files: [VideoInfo]
    @StateObject private var model = GPSMapModel()

    var body: some View {
        let coordinateFiles = files.filter(\.hasCoordinates)
        let totals = GPSMediaCounts.totals(in: coordinateFiles)
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                Text("City / GPS Map")
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(summaryText(photos: totals.photos, videos: totals.videos, empty: coordinateFiles.isEmpty))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            if coordinateFiles.isEmpty {
                Text(files.contains(where: \.hasGPS)
                    ? "GPS tags were found, but no usable coordinates could be read yet."
                    : "Drop media with GPS metadata to plot locations on Apple Maps.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
                    .background(Color(.systemGray).opacity(0.12))
                    .cornerRadius(10)
            } else {
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
                    Text("Click a yellow pin to see every photo and video within 5 miles.")
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
        .onAppear { model.update(files: files) }
        .onChange(of: files.map(\.path)) { _, _ in
            model.update(files: files)
        }
    }

    private func summaryText(photos: Int, videos: Int, empty: Bool) -> String {
        if empty { return "No mapped locations" }
        let places = model.clusters.count
        return "\(GPSMediaCounts.label(photos: photos, videos: videos)) · \(places) place\(places == 1 ? "" : "s") · 5 mi radius"
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
            Text("All media within 5 miles of this pin")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(String(format: "%.5f, %.5f", cluster.latitude, cluster.longitude))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)

            ForEach(cluster.files.prefix(8)) { file in
                Text("• \(file.name).\(file.ext)")
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            if cluster.files.count > 8 {
                Text("…and \(cluster.files.count - 8) more")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
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
