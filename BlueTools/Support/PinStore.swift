import Foundation

final class PinStore: ObservableObject {
    @Published private(set) var pinned: Set<UUID>
    @Published private(set) var nicknames: [UUID: String]

    private let defaults: UserDefaults
    private let pinsKey = "pinnedDevices"
    private let namesKey = "deviceNicknames"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedPins = defaults.stringArray(forKey: pinsKey) ?? []
        pinned = Set(storedPins.compactMap(UUID.init(uuidString:)))
        let storedNames = defaults.dictionary(forKey: namesKey) as? [String: String] ?? [:]
        var names: [UUID: String] = [:]
        for (key, value) in storedNames {
            if let id = UUID(uuidString: key) { names[id] = value }
        }
        nicknames = names
    }

    func isPinned(_ id: UUID) -> Bool {
        pinned.contains(id)
    }

    func toggle(_ id: UUID) {
        if pinned.contains(id) {
            pinned.remove(id)
        } else {
            pinned.insert(id)
        }
        defaults.set(pinned.map(\.uuidString), forKey: pinsKey)
    }

    func nickname(for id: UUID) -> String? {
        nicknames[id]
    }

    func setNickname(_ name: String, for id: UUID) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            nicknames.removeValue(forKey: id)
        } else {
            nicknames[id] = trimmed
        }
        var raw: [String: String] = [:]
        for (key, value) in nicknames { raw[key.uuidString] = value }
        defaults.set(raw, forKey: namesKey)
    }
}
