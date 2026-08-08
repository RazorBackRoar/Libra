import SwiftUI
import MapKit

/// Lightweight Apple Maps mini-map for GPS Sorter — native MapKit only.
struct GPSMapPanel: View {
    let files: [VideoInfo]
    @StateObject private var model = GPSMapModel()

    var body: some View {
        let coordinateCount = files.filter(\.hasCoordinates).count
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("City / GPS Map")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(summaryText(coordinateCount: coordinateCount))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if coordinateCount == 0 {
                Text(files.contains(where: \.hasGPS)
                    ? "GPS tags were found, but no usable coordinates could be read yet."
                    : "Drop media with GPS metadata to plot locations on Apple Maps.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    .background(Color(.systemGray).opacity(0.12))
                    .cornerRadius(10)
            } else {
                Map(position: $model.cameraPosition, selection: $model.selectedClusterID) {
                    ForEach(model.clusters) { cluster in
                        Marker(cluster.pinTitle, coordinate: cluster.coordinate)
                            .tint(.yellow)
                            .tag(cluster.id)
                    }
                }
                .mapStyle(.standard)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )

                if let selected = model.selectedCluster {
                    selectedClusterCard(selected)
                } else {
                    Text("Click a yellow pin to see the city and files at that spot.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
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

    private func summaryText(coordinateCount: Int) -> String {
        if coordinateCount == 0 { return "No mapped locations" }
        let places = model.clusters.count
        return "\(coordinateCount) with coords · \(places) place\(places == 1 ? "" : "s")"
    }

    @ViewBuilder
    private func selectedClusterCard(_ cluster: GPSLocationCluster) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.yellow)
                Text(cluster.placeName ?? "Resolving city…")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(cluster.files.count) file\(cluster.files.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
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
