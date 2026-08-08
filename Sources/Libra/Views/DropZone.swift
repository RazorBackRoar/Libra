import SwiftUI
import UniformTypeIdentifiers

struct DropZone: View {
    let title: String
    let subtitle: String
    let onDrop: ([String]) -> Void
    let onBrowse: () -> Void
    let onSelectFiles: () -> Void

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 32))
                .foregroundColor(.yellow)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("Open Folder…") { onBrowse() }
                    .buttonStyle(LibraPrimaryButtonStyle())
                Button("Select Files") { onSelectFiles() }
                    .buttonStyle(LibraSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(isDragging ? Color.yellow.opacity(0.1) : Color(.systemGray).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDragging ? Color.yellow : Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            return handleProviders(providers)
        }
    }

    private func handleProviders(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                } else if let url = item as? URL {
                    urls.append(url)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            onDrop(urls.map { $0.path })
        }
        return true
    }
}

struct LibraPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Color.orange : Color.yellow)
            .foregroundColor(.black)
            .cornerRadius(8)
    }
}

struct LibraSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.systemGray))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}
