import SwiftUI

struct ResultsTable: View {
    let files: [VideoInfo]
    let results: [OperationResult]

    var body: some View {
        if files.isEmpty && results.isEmpty {
            Text("No files yet. Drop a folder or files above.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding()
        } else {
            List {
                if !files.isEmpty {
                    Section("Scanned Videos") {
                        ForEach(files) { file in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name + "." + file.ext)
                                    .font(.system(size: 13, weight: .semibold))
                                Text("\(file.resolutionClass) · \(file.orientation) · \(file.codec) / \(file.container) · \(formatDuration(file.durationSec)) · \(formatSize(file.sizeBytes))")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                if let error = file.error {
                                    Text(error)
                                        .font(.system(size: 11))
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if !results.isEmpty {
                    Section("Results") {
                        ForEach(results) { result in
                            HStack {
                                Text(result.path)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                Text(result.status.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(result.status == .success ? .green : (result.status == .failed ? .red : .secondary))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .frame(minHeight: 200)
        }
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
