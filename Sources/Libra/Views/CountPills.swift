import SwiftUI

struct CountPills: View {
    let files: [VideoInfo]

    var body: some View {
        HStack(spacing: 8) {
            CountPill(label: "Files", value: files.count)
            CountPill(label: "4K", value: files.filter { $0.resolutionClass == "4K" }.count)
            CountPill(label: "1080p", value: files.filter { $0.resolutionClass == "1080p" }.count)
            CountPill(label: "720p", value: files.filter { $0.resolutionClass == "720p" }.count)
            CountPill(label: "GPS", value: files.filter { $0.hasGPS }.count)
            CountPill(label: "iPhone", value: files.filter { $0.isApple }.count)
        }
    }
}

struct CountPill: View {
    let label: String
    let value: Int

    var body: some View {
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
}
