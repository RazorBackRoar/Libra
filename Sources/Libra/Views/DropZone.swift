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
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.yellow)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("Open Folder…") { onBrowse() }
                    .buttonStyle(LibraPrimaryButtonStyle())
                    .accessibilityLabel("Open Folder")
                Button("Select Files") { onSelectFiles() }
                    .buttonStyle(LibraSecondaryButtonStyle())
                    .accessibilityLabel("Select Files")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(isDragging ? Color.yellow.opacity(0.12) : Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDragging ? Color.yellow : Color.white.opacity(0.12), lineWidth: 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            return handleProviders(providers)
        }
    }

    private func handleProviders(_ providers: [NSItemProvider]) -> Bool {
        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                let url: URL? = await withCheckedContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        if let data = item as? Data, let loaded = URL(dataRepresentation: data, relativeTo: nil) {
                            continuation.resume(returning: loaded)
                        } else if let loaded = item as? URL {
                            continuation.resume(returning: loaded)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }
                if let url {
                    urls.append(url)
                }
            }
            onDrop(urls.map(\.path))
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
