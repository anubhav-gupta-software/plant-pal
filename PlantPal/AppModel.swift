import Foundation
import Observation
import PlantPalKit
import WidgetKit

enum PostcardOutcome {
    case merged
    case joined
    case needChoice(PlantDocument)
    case needReplace(PlantDocument)
    case failed
}

@MainActor
@Observable
final class AppModel {
    private(set) var document: PlantDocument?
    private(set) var profile: DeviceProfile
    var isWatering = false
    var banner: String?
    var syncMessage: String?
    var isSyncing = false
    var reminderDenied = false
    var waterTicks = 0

    private let store = SharedPlantStore()
    private let cloud = CloudKitPlantSync()
    private var bannerTask: Task<Void, Never>?

    var appGroupAvailable: Bool { store.appGroupAvailable }

    init() {
        profile = store.loadProfile() ?? DeviceProfile()
        document = store.loadDocument()
    }

    var derived: DerivedPlant? {
        guard let document else { return nil }
        return PlantEngine.derive(document)
    }

    var postcardText: String {
        guard let document else { return "" }
        return (try? Postcard.encode(document)) ?? ""
    }

    func canWater(_ partnerID: UUID) -> Bool {
        if profile.playMode == .passAndPlay { return true }
        return profile.myPartnerID == partnerID
    }

    func water(_ partnerID: UUID) {
        guard var document else { return }
        switch PlantEngine.water(&document, partnerID: partnerID) {
        case .watered:
            self.document = document
            store.saveDocument(document)
            isWatering = true
            waterTicks += 1
            reloadWidgets()
            let who = document.partners.first { $0.id == partnerID }?.name ?? "You"
            showBanner("\(who) watered \(document.name).")
            Task {
                await pushIfNeeded()
                await ensureReminder()
                try? await Task.sleep(for: .milliseconds(1400))
                isWatering = false
            }
        case .alreadyWatered:
            showBanner("Already sipped today.")
        case .unknownPartner:
            break
        }
    }

    func startPassAndPlay(myName: String, plantName: String, palName: String) {
        let plant = PlantEngine.makePlant(ownerName: myName, plantName: plantName, palName: palName)
        adopt(plant, myID: plant.partners[0].id, mode: .passAndPlay, name: plant.partners[0].name)
    }

    func startLinked(myName: String, plantName: String) {
        let plant = PlantEngine.makePlant(ownerName: myName, plantName: plantName, palName: nil)
        adopt(plant, myID: plant.partners[0].id, mode: .linkedPhones, name: plant.partners[0].name, complete: false)
    }

    func finishOnboarding() {
        profile.onboardingComplete = true
        saveProfile()
    }

    func startLinkedWithCloud(myName: String, plantName: String) async -> Bool {
        startLinked(myName: myName, plantName: plantName)
        return await setSyncMode(.cloudKit)
    }

    func joinWithCode(_ raw: String, myName: String) async -> Bool {
        let code = InviteCode.normalize(raw)
        guard code.count == 6 else {
            syncMessage = "Codes are 6 letters and numbers."
            return false
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await cloud.ensureAccount()
            profile.syncMode = .cloudKit
            saveProfile()
            var remote = try await cloud.fetch(inviteCode: code)
            guard let myID = PlantEngine.joinPartner(&remote, name: myName) else {
                syncMessage = "That plant already has two people."
                return false
            }
            let saved = try await cloud.upload(remote)
            adopt(saved, myID: myID, mode: .linkedPhones, name: saved.partners.first { $0.id == myID }?.name ?? myName)
            syncMessage = "You joined \(saved.name)."
            return true
        } catch {
            syncMessage = error.localizedDescription
            return false
        }
    }

    func addPracticePal(name: String) {
        guard var document else { return }
        guard PlantEngine.addPracticePal(&document, name: name) != nil else {
            showBanner("This plant already has two people.")
            return
        }
        self.document = document
        store.saveDocument(document)
        profile.playMode = .passAndPlay
        saveProfile()
        reloadWidgets()
        showBanner("A practice pal can water from this phone.")
        Task { await pushIfNeeded() }
    }

    func renamePlant(_ name: String) {
        guard var document else { return }
        PlantEngine.renamePlant(&document, name: name)
        self.document = document
        store.saveDocument(document)
        reloadWidgets()
        Task { await pushIfNeeded() }
    }

    func renamePartner(id: UUID, name: String) {
        guard var document else { return }
        PlantEngine.renamePartner(&document, id: id, name: name)
        if id == profile.myPartnerID {
            profile.displayName = document.partners.first { $0.id == id }?.name ?? profile.displayName
            saveProfile()
        }
        self.document = document
        store.saveDocument(document)
        Task { await pushIfNeeded() }
    }

    func equip(species: PlantSpecies) {
        guard var document else { return }
        guard PlantEngine.equip(species: species, on: &document) else {
            showBanner("That one is still growing in.")
            return
        }
        self.document = document
        store.saveDocument(document)
        reloadWidgets()
        showBanner("\(document.name) is a \(species.displayName) now.")
        Task { await pushIfNeeded() }
    }

    func equip(pot: PotStyle) {
        guard var document else { return }
        guard PlantEngine.equip(pot: pot, on: &document) else {
            showBanner("That pot is still locked.")
            return
        }
        self.document = document
        store.saveDocument(document)
        reloadWidgets()
        showBanner("New pot. Same plant.")
        Task { await pushIfNeeded() }
    }

    @discardableResult
    func setSyncMode(_ mode: SyncMode) async -> Bool {
        if mode == .local {
            profile.syncMode = .local
            saveProfile()
            syncMessage = "Staying on this phone."
            return true
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await cloud.ensureAccount()
            profile.syncMode = .cloudKit
            saveProfile()
            if let document {
                let saved = try await cloud.upload(document)
                self.document = saved
                store.saveDocument(saved)
                reloadWidgets()
            }
            syncMessage = "iCloud is connected."
            return true
        } catch {
            profile.syncMode = .local
            saveProfile()
            syncMessage = error.localizedDescription
            return false
        }
    }

    func refreshFromCloud(userInitiated: Bool) async {
        guard profile.syncMode == .cloudKit, let document else { return }
        if userInitiated { isSyncing = true }
        defer { if userInitiated { isSyncing = false } }
        do {
            let remote = try await cloud.fetch(inviteCode: document.inviteCode)
            let merged = PlantMerge.merge(local: document, remote: remote)
            self.document = merged
            store.saveDocument(merged)
            reloadWidgets()
            if !PlantMerge.isSameContent(merged, remote) {
                _ = try? await cloud.upload(merged)
            }
            if userInitiated { syncMessage = "Caught up." }
        } catch {
            if userInitiated { syncMessage = error.localizedDescription }
        }
    }

    func importPostcard(_ raw: String, myName: String) -> PostcardOutcome {
        let incoming: PlantDocument
        do {
            incoming = try Postcard.decode(raw)
        } catch {
            showBanner("That postcard didn't open. Ask for a fresh one.")
            return .failed
        }
        if let local = document {
            if local.id == incoming.id {
                let merged = PlantMerge.merge(local: local, remote: incoming)
                self.document = merged
                store.saveDocument(merged)
                reloadWidgets()
                showBanner("Postcard merged. Both sips count.")
                Task { await pushIfNeeded() }
                return .merged
            }
            return .needReplace(incoming)
        }
        return adoptFresh(incoming, myName: myName)
    }

    func replaceWithPostcard(_ incoming: PlantDocument, myName: String) -> PostcardOutcome {
        document = nil
        return adoptFresh(incoming, myName: myName)
    }

    func choosePartner(_ id: UUID, on incoming: PlantDocument) {
        guard let partner = incoming.partners.first(where: { $0.id == id }) else { return }
        adopt(incoming, myID: id, mode: .linkedPhones, name: partner.name)
        showBanner("This phone waters as \(partner.name).")
    }

    func setReminders(enabled: Bool, hour: Int, minute: Int) async {
        profile.reminderHour = hour
        profile.reminderMinute = minute
        if enabled {
            let allowed = await ReminderScheduler.authorize()
            profile.remindersEnabled = allowed
            reminderDenied = !allowed
            saveProfile()
            if allowed {
                await ReminderScheduler.schedule(plantName: document?.name ?? "Your plant", hour: hour, minute: minute)
            }
        } else {
            profile.remindersEnabled = false
            reminderDenied = false
            saveProfile()
            await ReminderScheduler.cancel()
        }
    }

    func updateReminderTime(hour: Int, minute: Int) async {
        profile.reminderHour = hour
        profile.reminderMinute = minute
        saveProfile()
        if profile.remindersEnabled {
            await ReminderScheduler.schedule(plantName: document?.name ?? "Your plant", hour: hour, minute: minute)
        }
    }

    func ensureReminder() async {
        guard profile.remindersEnabled else { return }
        await ReminderScheduler.schedule(
            plantName: document?.name ?? "Your plant",
            hour: profile.reminderHour,
            minute: profile.reminderMinute
        )
    }

    func handle(_ url: URL) {
        guard url.scheme == "plantpal", url.host == "water", let id = profile.myPartnerID else { return }
        water(id)
    }

    func resetGarden() {
        store.clear()
        document = nil
        profile = DeviceProfile()
        saveProfile()
        syncMessage = nil
        Task { await ReminderScheduler.cancel() }
        reloadWidgets()
    }

    private func adoptFresh(_ incoming: PlantDocument, myName: String) -> PostcardOutcome {
        var plant = incoming
        if plant.partners.count >= 2,
           plant.partners.first(where: { $0.name.compare(myName, options: .caseInsensitive) == .orderedSame && !$0.isStandIn }) == nil {
            return .needChoice(plant)
        }
        let myID: UUID
        if let existing = plant.partners.first(where: { $0.name.compare(myName, options: .caseInsensitive) == .orderedSame }) {
            myID = existing.id
        } else if let joined = PlantEngine.joinPartner(&plant, name: myName) {
            myID = joined
        } else {
            return .needChoice(plant)
        }
        let name = plant.partners.first { $0.id == myID }?.name ?? myName
        adopt(plant, myID: myID, mode: .linkedPhones, name: name)
        showBanner("You're in. Send a postcard back.")
        Task { await pushIfNeeded() }
        return .joined
    }

    private func adopt(_ plant: PlantDocument, myID: UUID, mode: PlayMode, name: String, complete: Bool = true) {
        document = plant
        profile.displayName = name
        profile.myPartnerID = myID
        profile.playMode = mode
        profile.onboardingComplete = complete
        profile.updatedAt = Date()
        store.saveDocument(plant)
        store.saveProfile(profile)
        reloadWidgets()
    }

    private func saveProfile() {
        profile.updatedAt = Date()
        store.saveProfile(profile)
    }

    private func showBanner(_ text: String) {
        banner = text
        bannerTask?.cancel()
        bannerTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            banner = nil
        }
    }

    private func pushIfNeeded() async {
        guard profile.syncMode == .cloudKit, let document else { return }
        do {
            let saved = try await cloud.upload(document)
            if saved != document {
                self.document = saved
                store.saveDocument(saved)
                reloadWidgets()
            }
        } catch {
            syncMessage = error.localizedDescription
        }
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
