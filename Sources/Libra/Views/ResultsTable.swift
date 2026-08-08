import SwiftUI

struct ResultsTable: View {
    let files: [VideoInfo]
    let results: [OperationResult]

    var body: some View {
        Group {
            if files.isEmpty && results.isEmpty {
                Text("No files yet. Drop a folder or files above.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.vertical, 4)
            } else {
                List {
                    if !files.isEmpty {
                        Section("Scanned Files") {
                            ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.yellow)
                                        .frame(width: numberColumnWidth, alignment: .trailing)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.name + "." + file.ext)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(detailLine(for: file))
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        if let error = file.error {
                                            Text(error)
                                                .font(.system(size: 11))
                                                .foregroundColor(.red)
                                        } else if let warning = file.warning {
                                            Text(warning)
                                                .font(.system(size: 11))
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    if !results.isEmpty {
                        Section("Results") {
                            ForEach(results) { result in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text((result.path as NSString).lastPathComponent)
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                        Spacer()
                                        Text(result.status.rawValue)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(statusColor(result.status))
                                    }
                                    if let reason = result.reason {
                                        Text(reason)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    if let output = result.outputPath {
                                        Text("→ \(output)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var numberColumnWidth: CGFloat {
        switch files.count {
        case 0..<10: return 28
        case 10..<100: return 36
        default: return 48
        }
    }

    private func statusColor(_ status: OperationStatus) -> Color {
        switch status {
        case .success:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        case .skipped, .pending:
            return .secondary
        }
    }

    private func detailLine(for file: VideoInfo) -> String {
        var parts: [String] = []
        if !file.resolutionClass.isEmpty && file.resolutionClass != "Unknown" {
            parts.append(file.resolutionClass)
        }
        if !file.orientation.isEmpty && file.orientation != "Unknown" {
            parts.append(file.orientation)
        }
        if !file.codec.isEmpty {
            parts.append(file.codec)
        }
        if file.durationSec > 0 {
            parts.append(formatDuration(file.durationSec))
        }
        parts.append(formatSize(file.sizeBytes))
        let markers = FileNaming.metadataMarkers(
            hasAppleMake: file.hasAppleMake,
            hasiPhoneModel: file.hasiPhoneModel,
            hasGPS: file.hasGPS
        )
        if !markers.isEmpty {
            parts.append(markers)
        }
        if !file.make.isEmpty || !file.model.isEmpty {
            parts.append([file.make, file.model].filter { !$0.isEmpty }.joined(separator: " "))
        }
        return parts.joined(separator: " · ")
    }

    private func formatDuration(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    private func formatSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }
}
