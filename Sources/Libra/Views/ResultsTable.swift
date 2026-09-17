import SwiftUI

struct ResultsTable: View {
    let files: [VideoInfo]
    let results: [OperationResult]
    @State private var selectedKey: String?
    @State private var orderedResults: [OperationResult] = []

    private static func sortResults(_ results: [OperationResult]) -> [OperationResult] {
        results.sorted { lhs, rhs in
            let left = statusRank(lhs.status)
            let right = statusRank(rhs.status)
            if left != right { return left < right }
            return lhs.path < rhs.path
        }
    }

    var body: some View {
        Group {
            if files.isEmpty && results.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(LibraTheme.yellow.opacity(0.7))
                    Text("No videos yet")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Drop a folder or videos above.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.vertical, 8)
            } else {
                List(selection: $selectedKey) {
                    if !files.isEmpty {
                        Section("Videos") {
                            ForEach(Array(files.enumerated()), id: \.element.path) { index, file in
                                resultRow(
                                    index: index + 1,
                                    title: file.name + "." + file.ext,
                                    detail: file.identificationLine,
                                    error: file.error,
                                    warning: file.warning
                                )
                                .tag(Self.fileKey(file.path))
                                .contentShape(Rectangle())
                                .onTapGesture { MediaOpen.open(file.path) }
                                .contextMenu {
                                    Button("Open") { MediaOpen.open(file.path) }
                                    Button("Reveal in Finder") { MediaOpen.reveal(file.path) }
                                }
                            }
                        }
                    }

                    if !results.isEmpty {
                        Section("Results") {
                            ForEach(orderedResults, id: \.path) { result in
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
                                .tag(Self.resultKey(result.path))
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                                .onTapGesture { MediaOpen.open(result.outputPath ?? result.path) }
                                .contextMenu {
                                    Button("Open") {
                                        MediaOpen.open(result.outputPath ?? result.path)
                                    }
                                    Button("Reveal in Finder") {
                                        MediaOpen.reveal(result.outputPath ?? result.path)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .scrollContentBackground(.hidden)
                .libraPanel()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .focusable()
        .onKeyPress(.space) {
            guard selectedKey != nil else { return .ignored }
            openSelected()
            return .handled
        }
        .help("Space opens the selected video")
        .onAppear { orderedResults = Self.sortResults(results) }
        .onChange(of: results) { _, new in orderedResults = Self.sortResults(new) }
    }

    private static func fileKey(_ path: String) -> String { "file:\(path)" }
    private static func resultKey(_ path: String) -> String { "result:\(path)" }

    private func openSelected() {
        guard let selectedKey else { return }
        if selectedKey.hasPrefix("result:") {
            let path = String(selectedKey.dropFirst("result:".count))
            if let result = orderedResults.first(where: { $0.path == path }) {
                MediaOpen.open(result.outputPath ?? result.path)
            }
            return
        }
        if selectedKey.hasPrefix("file:") {
            MediaOpen.open(String(selectedKey.dropFirst("file:".count)))
        }
    }

    private func resultRow(
        index: Int,
        title: String,
        detail: String,
        error: String?,
        warning: String?
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index).")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(LibraTheme.gold)
                .frame(width: numberColumnWidth, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .help(detail)
                if let error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                } else if let warning {
                    Text(warning)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var numberColumnWidth: CGFloat {
        switch files.count {
        case 0..<10: return 28
        case 10..<100: return 36
        default: return 48
        }
    }

    private static func statusRank(_ status: OperationStatus) -> Int {
        switch status {
        case .failed: return 0
        case .cancelled: return 1
        case .skipped, .pending: return 2
        case .success: return 3
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
}
