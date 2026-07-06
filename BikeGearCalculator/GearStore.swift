import Foundation
import Combine

class GearStore: ObservableObject {

    @Published var savedConfigs: [SavedConfig] = []
    @Published var selectedTab: Int = 0
    @Published var pendingLoad: PendingLoad? = nil
    @Published var ownedGears = OwnedGears()

    struct PendingLoad: Equatable {
        let config: SavedConfig
        let restoreRiderSettings: Bool

        static func == (lhs: PendingLoad, rhs: PendingLoad) -> Bool {
            lhs.config.id == rhs.config.id && lhs.restoreRiderSettings == rhs.restoreRiderSettings
        }
    }

    private let savedKey = "savedConfigs_v1"
    private let riderKey = "riderSettings_v1"
    private let ownedKey = "ownedGears_v1"

    init() {
        load()
        ownedGears = loadOwnedGears()
    }

    // MARK: - Owned gears persistence

    func saveOwnedGears(_ gears: OwnedGears) {
        ownedGears = gears
        guard let data = try? JSONEncoder().encode(gears) else { return }
        UserDefaults.standard.set(data, forKey: ownedKey)
    }

    private func loadOwnedGears() -> OwnedGears {
        guard let data = UserDefaults.standard.data(forKey: ownedKey),
              let gears = try? JSONDecoder().decode(OwnedGears.self, from: data)
        else { return OwnedGears() }
        return gears
    }

    // MARK: - Rider settings persistence

    func saveRiderSettings(_ settings: RiderSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: riderKey)
    }

    func loadRiderSettings() -> RiderSettings {
        guard let data = UserDefaults.standard.data(forKey: riderKey),
              let settings = try? JSONDecoder().decode(RiderSettings.self, from: data)
        else { return RiderSettings() }
        return settings
    }

    // MARK: - Saved configs

    func save(_ config: SavedConfig) {
        if let idx = savedConfigs.firstIndex(where: { $0.id == config.id }) {
            savedConfigs[idx] = config
        } else {
            savedConfigs.insert(config, at: 0)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        offsets.sorted(by: >).forEach { savedConfigs.remove(at: $0) }
        persist()
    }

    func delete(_ config: SavedConfig) {
        savedConfigs.removeAll { $0.id == config.id }
        persist()
    }

    // MARK: - Cross-tab navigation

    func loadPreset(_ preset: GearPreset, riderSettings: RiderSettings) {
        pendingLoad = PendingLoad(config: preset.toConfig(riderSettings: riderSettings),
                                 restoreRiderSettings: false)
        selectedTab = 0
    }

    func loadSaved(_ config: SavedConfig) {
        pendingLoad = PendingLoad(config: config, restoreRiderSettings: true)
        selectedTab = 0
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(savedConfigs) else { return }
        UserDefaults.standard.set(data, forKey: savedKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: savedKey),
              let configs = try? JSONDecoder().decode([SavedConfig].self, from: data) else { return }
        savedConfigs = configs
    }
}
