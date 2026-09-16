import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    /// Test seam: when set, load/save use this file instead of Application Support.
    static var fileURLOverride: URL?

    @Published var settings: AppSettings = .default {
        didSet { MediaKinds.sync(with: settings) }
    }

    private var fileURL: URL {
        Self.fileURLOverride
            ?? Paths.applicationSupportDirectory().appendingPathComponent("settings.json")
    }

    private init() {
        Paths.ensureDirectory(Paths.applicationSupportDirectory())
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        {
            settings = decoded
        }
    }

    func save() {
        Paths.ensureDirectory(fileURL.deletingLastPathComponent())
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func update(_ block: (inout AppSettings) -> Void) {
        block(&settings)
        save()
    }
}
