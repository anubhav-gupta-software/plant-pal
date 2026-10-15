import Foundation

/// Keeps the plant where both the app and the widget can see it.
///
/// With the App Group entitlement, reads and writes go through
/// `group.com.plantpal.shared`. Without it (a free personal team cannot
/// sign App Groups), the same bytes stay in the app's own container so
/// the phone app still works. The widget then has nothing to read and
/// shows an empty sprout that opens the app.
public final class SharedPlantStore {
    private let documentKey = "plant.document"
    private let profileKey = "plant.profile"
    private let documentFile = "plant.json"
    private let profileFile = "profile.json"

    public init() {}

    public var appGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SyncConfig.appGroupIdentifier) != nil
    }

    public func loadDocument() -> PlantDocument? {
        best(candidates: [
            readFile(groupFolder, documentFile),
            readDefaults(groupDefaults, key: documentKey),
            readFile(localFolder, documentFile),
            readDefaults(.standard, key: documentKey),
        ])
    }

    public func saveDocument(_ document: PlantDocument) {
        guard let data = try? PlantCoding.encoder().encode(document) else { return }
        write(data, file: documentFile, key: documentKey)
    }

    public func loadProfile() -> DeviceProfile? {
        let profiles: [DeviceProfile] = [
            readProfile(groupFolder, profileFile),
            readProfileDefaults(groupDefaults, key: profileKey),
            readProfile(localFolder, profileFile),
            readProfileDefaults(.standard, key: profileKey),
        ].compactMap { $0 }
        return profiles.max { $0.updatedAt < $1.updatedAt }
    }

    public func saveProfile(_ profile: DeviceProfile) {
        guard let data = try? PlantCoding.encoder().encode(profile) else { return }
        write(data, file: profileFile, key: profileKey)
    }

    public func clear() {
        UserDefaults.standard.removeObject(forKey: documentKey)
        UserDefaults.standard.removeObject(forKey: profileKey)
        groupDefaults?.removeObject(forKey: documentKey)
        groupDefaults?.removeObject(forKey: profileKey)
        for folder in [groupFolder, localFolder].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(documentFile))
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(profileFile))
        }
    }

    private func best(candidates: [PlantDocument?]) -> PlantDocument? {
        candidates.compactMap { $0 }.max { $0.revision < $1.revision }
    }

    private func write(_ data: Data, file: String, key: String) {
        UserDefaults.standard.set(data, forKey: key)
        groupDefaults?.set(data, forKey: key)
        if let folder = localFolder {
            writeFile(data, folder: folder, name: file)
        }
        if let folder = groupFolder {
            writeFile(data, folder: folder, name: file)
        }
    }

    private func writeFile(_ data: Data, folder: URL, name: String) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appendingPathComponent(name), options: .atomic)
    }

    private func readFile(_ folder: URL?, _ name: String) -> PlantDocument? {
        guard let folder,
              let data = try? Data(contentsOf: folder.appendingPathComponent(name)) else { return nil }
        return try? PlantCoding.decoder().decode(PlantDocument.self, from: data)
    }

    private func readDefaults(_ defaults: UserDefaults?, key: String) -> PlantDocument? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? PlantCoding.decoder().decode(PlantDocument.self, from: data)
    }

    private func readProfile(_ folder: URL?, _ name: String) -> DeviceProfile? {
        guard let folder,
              let data = try? Data(contentsOf: folder.appendingPathComponent(name)) else { return nil }
        return try? PlantCoding.decoder().decode(DeviceProfile.self, from: data)
    }

    private func readProfileDefaults(_ defaults: UserDefaults?, key: String) -> DeviceProfile? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? PlantCoding.decoder().decode(DeviceProfile.self, from: data)
    }

    private var groupFolder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SyncConfig.appGroupIdentifier)
    }

    private var groupDefaults: UserDefaults? {
        UserDefaults(suiteName: SyncConfig.appGroupIdentifier)
    }

    private var localFolder: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("PlantPal", isDirectory: true)
    }
}
