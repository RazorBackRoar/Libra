import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var settings: AppSettings = .default

    private let fileURL: URL

    private init() {
        Paths.ensureDirectory(Paths.applicationSupportDirectory())
        fileURL = Paths.applicationSupportDirectory().appendingPathComponent("settings.json")
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }

    func save() {
        Paths.ensureDirectory(Paths.applicationSupportDirectory())
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func update(_ block: (inout AppSettings) -> Void) {
        block(&settings)
        save()
    }
}
