import SwiftUI

struct CountPills: View {
    let files: [VideoInfo]
    var tool: Tool? = nil

    var body: some View {
        HStack(spacing: 8) {
            CountPill(label: "Files", value: files.count)
            if tool == .iphoneSorter {
                CountPill(label: "Apple", value: files.filter { $0.hasAppleMake }.count)
                CountPill(label: "iPhone", value: files.filter { $0.hasiPhoneModel }.count)
                CountPill(label: "Both", value: files.filter { $0.hasAppleMake && $0.hasiPhoneModel }.count)
            } else {
                ForEach(VideoInfo.resolutionClasses, id: \.self) { label in
                    CountPill(label: label, value: files.filter { $0.resolutionClass == label }.count)
                }
                CountPill(label: "GPS", value: files.filter { $0.hasGPS }.count)
                CountPill(label: "iPhone", value: files.filter { $0.isApple }.count)
            }
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
