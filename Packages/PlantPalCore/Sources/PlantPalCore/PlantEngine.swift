import Foundation

public enum WaterResult: Equatable {
    case watered
    case alreadyWatered
    case unknownPartner
}

public struct UnlockProgress: Equatable {
    public enum Kind: Equatable {
        case stage
        case pot
        case species
    }

    public var title: String
    public var daysRemaining: Int
    public var kind: Kind
}

public struct DayDot: Equatable, Identifiable {
    public enum State: Equatable {
        case beforePlant
        case missed
        case thriving
        case today(watered: Int, needed: Int)
    }

    public var key: String
    public var weekday: String
    public var state: State

    public var id: String { key }
}

public struct DerivedPlant: Equatable {
    public var todayKey: String
    public var totalThrivingDays: Int
    public var currentStreak: Int
    public var longestStreak: Int
    public var wilt: WiltLevel
    public var appearanceWilt: WiltLevel
    public var eveningThirst: Bool
    public var stage: GrowthStage
    public var wateredToday: Set<UUID>
    public var daysTogether: Int
    public var nextStage: GrowthStage?
    public var thrivingDaysUntilNextStage: Int?
    public var unlockedSpecies: [PlantSpecies]
    public var unlockedPots: [PotStyle]
    public var nextUnlock: UnlockProgress?
    public var everyoneWateredToday: Bool
}

public enum PlantEngine {
    public static func makePlant(
        ownerName: String,
        plantName: String,
        palName: String?,
        now: Date = Date(),
        timeZoneIdentifier: String = TimeZone.current.identifier,
        id: UUID = UUID(),
        ownerID: UUID = UUID()
    ) -> PlantDocument {
        let owner = Partner(
            id: ownerID,
            name: cleaned(ownerName, fallback: "You", limit: 18),
            joinedAt: now
        )
        var partners = [owner]
        if let palName {
            let trimmed = palName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                partners.append(Partner(id: UUID(), name: cleaned(trimmed, fallback: "Pal", limit: 18), joinedAt: now))
            }
        }
        return PlantDocument(
            id: id,
            name: cleaned(plantName, fallback: "Pip", limit: 24),
            speciesID: PlantSpecies.sproutling.rawValue,
            potID: PotStyle.terracotta.rawValue,
            createdAt: now,
            timeZoneIdentifier: timeZoneIdentifier,
            inviteCode: InviteCode.make(),
            partners: partners,
            wateredDays: [:],
            updatedAt: now,
            revision: 1
        )
    }

    @discardableResult
    public static func water(_ document: inout PlantDocument, partnerID: UUID, now: Date = Date()) -> WaterResult {
        guard document.partners.contains(where: { $0.id == partnerID }) else {
            return .unknownPartner
        }
        let key = PlantCalendar(identifier: document.timeZoneIdentifier).dayKey(for: now)
        var ids = document.wateredDays[key] ?? []
        if ids.contains(partnerID) {
            return .alreadyWatered
        }
        ids.append(partnerID)
        document.wateredDays[key] = ids
        document.revision += 1
        document.updatedAt = now
        return .watered
    }

    @discardableResult
    public static func addPracticePal(_ document: inout PlantDocument, name: String, now: Date = Date()) -> UUID? {
        guard document.partners.count < 2 else { return nil }
        let pal = Partner(id: UUID(), name: cleaned(name, fallback: "Practice Pal", limit: 18), joinedAt: now, isStandIn: true)
        document.partners.append(pal)
        touch(&document, now: now)
        return pal.id
    }

    /// Adds a real pal, replacing a practice pal when one is holding the second spot.
    @discardableResult
    public static func joinPartner(
        _ document: inout PlantDocument,
        name: String,
        id: UUID = UUID(),
        now: Date = Date()
    ) -> UUID? {
        let safeName = cleaned(name, fallback: "Pal", limit: 18)
        if let index = document.partners.firstIndex(where: \.isStandIn) {
            let oldID = document.partners[index].id
            document.partners[index] = Partner(id: id, name: safeName, joinedAt: now, isStandIn: false)
            for key in Array(document.wateredDays.keys) {
                let remaining = (document.wateredDays[key] ?? []).filter { $0 != oldID }
                document.wateredDays[key] = remaining.isEmpty ? nil : remaining
            }
        } else if document.partners.count >= 2 {
            return nil
        } else {
            document.partners.append(Partner(id: id, name: safeName, joinedAt: now, isStandIn: false))
        }
        touch(&document, now: now)
        return id
    }

    public static func renamePlant(_ document: inout PlantDocument, name: String, now: Date = Date()) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        document.name = String(trimmed.prefix(24))
        touch(&document, now: now)
    }

    public static func renamePartner(_ document: inout PlantDocument, id: UUID, name: String, now: Date = Date()) {
        guard let index = document.partners.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        document.partners[index].name = String(trimmed.prefix(18))
        touch(&document, now: now)
    }

    @discardableResult
    public static func equip(species: PlantSpecies, on document: inout PlantDocument, now: Date = Date()) -> Bool {
        let days = derive(document, now: now).totalThrivingDays
        guard species.unlockThrivingDays <= days else { return false }
        document.speciesID = species.rawValue
        touch(&document, now: now)
        return true
    }

    @discardableResult
    public static func equip(pot: PotStyle, on document: inout PlantDocument, now: Date = Date()) -> Bool {
        let days = derive(document, now: now).totalThrivingDays
        guard pot.unlockThrivingDays <= days else { return false }
        document.potID = pot.rawValue
        touch(&document, now: now)
        return true
    }

    public static func dayWasThriving(_ document: PlantDocument, key: String) -> Bool {
        let watered = Set(document.wateredDays[key] ?? [])
        if document.partners.count <= 1 {
            guard let only = document.partners.first else { return false }
            return watered.contains(only.id)
        }
        return document.partners.allSatisfy { watered.contains($0.id) }
    }

    public static func derive(_ document: PlantDocument, now: Date = Date()) -> DerivedPlant {
        let calendar = PlantCalendar(identifier: document.timeZoneIdentifier)
        let todayKey = calendar.dayKey(for: now)
        var streak = 0
        var longest = 0
        var total = 0
        var wilt = 0
        for key in calendar.pastDayKeys(from: document.createdAt, now: now) {
            if dayWasThriving(document, key: key) {
                streak += 1
                total += 1
                wilt = max(0, wilt - 1)
                longest = max(longest, streak)
            } else {
                streak = 0
                wilt = min(3, wilt + 1)
            }
        }

        let wateredToday = Set(document.wateredDays[todayKey] ?? [])
        let everyone = !document.partners.isEmpty && document.partners.allSatisfy { wateredToday.contains($0.id) }
        let stage = GrowthStage.forThrivingDays(total)
        let nextStage = stage.next
        let daysUntilStage = nextStage.map { max(0, $0.daysRequired - total) }
        let unlockedSpecies = PlantSpecies.allCases.filter { $0.unlockThrivingDays <= total }
        let unlockedPots = PotStyle.allCases.filter { $0.unlockThrivingDays <= total }
        let evening = calendar.hour(of: now) >= 18 && !everyone && !document.partners.isEmpty
        let wiltLevel = WiltLevel(rawValue: wilt) ?? .crisis
        let appearance: WiltLevel = wiltLevel == .perky && evening ? .thirsty : wiltLevel

        let createdStart = calendar.startOfDay(for: document.createdAt)
        let todayStart = calendar.startOfDay(for: now)
        let together = (calendar.calendar.dateComponents([.day], from: createdStart, to: todayStart).day ?? 0) + 1

        return DerivedPlant(
            todayKey: todayKey,
            totalThrivingDays: total,
            currentStreak: streak,
            longestStreak: longest,
            wilt: wiltLevel,
            appearanceWilt: appearance,
            eveningThirst: evening,
            stage: stage,
            wateredToday: wateredToday,
            daysTogether: max(together, 1),
            nextStage: nextStage,
            thrivingDaysUntilNextStage: daysUntilStage,
            unlockedSpecies: unlockedSpecies,
            unlockedPots: unlockedPots,
            nextUnlock: nextUnlock(total: total, stage: stage),
            everyoneWateredToday: everyone
        )
    }

    public static func recentDots(document: PlantDocument, now: Date = Date(), count: Int = 7) -> [DayDot] {
        let plantCalendar = PlantCalendar(identifier: document.timeZoneIdentifier)
        let calendar = plantCalendar.calendar
        let todayStart = calendar.startOfDay(for: now)
        let createdStart = calendar.startOfDay(for: document.createdAt)
        let symbols = calendar.shortWeekdaySymbols
        var dots: [DayDot] = []
        let safeCount = max(count, 1)
        for offset in stride(from: safeCount - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let key = plantCalendar.dayKey(for: date)
            let weekdayIndex = calendar.component(.weekday, from: date) - 1
            let symbol = symbols.indices.contains(weekdayIndex) ? symbols[weekdayIndex] : ""
            let state: DayDot.State
            if date < createdStart {
                state = .beforePlant
            } else if offset == 0 {
                let watered = Set(document.wateredDays[key] ?? []).intersection(Set(document.partners.map(\.id))).count
                state = .today(watered: watered, needed: max(document.partners.count, 1))
            } else if dayWasThriving(document, key: key) {
                state = .thriving
            } else {
                state = .missed
            }
            dots.append(DayDot(key: key, weekday: String(symbol.prefix(2)), state: state))
        }
        return dots
    }

    private static func nextUnlock(total: Int, stage: GrowthStage) -> UnlockProgress? {
        var options: [UnlockProgress] = []
        if let next = stage.next {
            options.append(UnlockProgress(title: next.title, daysRemaining: max(0, next.daysRequired - total), kind: .stage))
        }
        if let pot = PotStyle.allCases.first(where: { $0.unlockThrivingDays > total }) {
            options.append(UnlockProgress(title: "\(pot.displayName) pot", daysRemaining: pot.unlockThrivingDays - total, kind: .pot))
        }
        if let species = PlantSpecies.allCases.first(where: { $0.unlockThrivingDays > total }) {
            options.append(UnlockProgress(title: species.displayName, daysRemaining: species.unlockThrivingDays - total, kind: .species))
        }
        return options.min { lhs, rhs in
            if lhs.daysRemaining == rhs.daysRemaining { return kindRank(lhs.kind) < kindRank(rhs.kind) }
            return lhs.daysRemaining < rhs.daysRemaining
        }
    }

    private static func kindRank(_ kind: UnlockProgress.Kind) -> Int {
        switch kind {
        case .stage: return 0
        case .pot: return 1
        case .species: return 2
        }
    }

    private static func touch(_ document: inout PlantDocument, now: Date) {
        document.revision += 1
        document.updatedAt = now
    }

    private static func cleaned(_ raw: String, fallback: String, limit: Int) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        return String(value.prefix(limit))
    }
}

public enum PlantCopy {
    public static func headline(document: PlantDocument, derived: DerivedPlant) -> String {
        if document.partners.count < 2 && derived.everyoneWateredToday {
            return "You showed up"
        }
        if derived.everyoneWateredToday {
            return "You both showed up"
        }
        switch derived.wilt {
        case .crisis:
            return "\(document.name) really needs you"
        case .drooping:
            return "\(document.name) is drooping"
        case .thirsty:
            return "\(document.name) is thirsty"
        case .perky:
            if derived.eveningThirst {
                return "The day is getting late"
            }
            if document.partners.count < 2 {
                return "Room for one more"
            }
            if derived.wateredToday.isEmpty {
                return "A good day to sip"
            }
            return "Halfway watered"
        }
    }

    public static func detail(document: PlantDocument, derived: DerivedPlant) -> String {
        let name = document.name
        if document.partners.count < 2 {
            if derived.everyoneWateredToday {
                return "\(name) felt you today. When your pal joins, a thriving day takes both of you."
            }
            if derived.wilt == .perky {
                return "Water \(name) once today. Your sip counts until a second person joins."
            }
            return "\(name) missed a day. A sip today starts to perk it back up."
        }

        if derived.everyoneWateredToday {
            return "\(name) felt both of you today. That's how it grows."
        }

        if let waiting = document.partners.first(where: { !derived.wateredToday.contains($0.id) }),
           let done = document.partners.first(where: { derived.wateredToday.contains($0.id) }),
           !derived.wateredToday.isEmpty {
            return "\(done.name) watered. \(waiting.name) still has the rest of the day."
        }

        switch derived.wilt {
        case .crisis:
            return "A missed stretch left \(name) wilted. One day where you both water starts the comeback."
        case .drooping:
            return "\(name)'s leaves are heavy. They still brighten when you both show up."
        case .thirsty:
            return "Yesterday didn't get both sips. Today can still be a thriving day."
        case .perky:
            if derived.eveningThirst {
                return "It's getting late, and \(name) is looking toward the watering can."
            }
            return "Each of you gets one sip a day. \(name) only counts the day when it's both."
        }
    }

    public static func widgetLine(document: PlantDocument, derived: DerivedPlant, myPartnerID: UUID?) -> String {
        if derived.wilt == .crisis { return "Wilting" }
        if derived.wilt == .drooping || derived.wilt == .thirsty { return "Thirsty" }
        if derived.everyoneWateredToday { return "Both sipped" }
        if let myPartnerID, derived.wateredToday.contains(myPartnerID) { return "Your sip's in" }
        if derived.eveningThirst { return "Getting late" }
        if document.partners.count < 2 { return "Needs you" }
        return "Needs a sip"
    }
}

public enum SamplePlant {
    public static let alexID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA1")!
    public static let samID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA2")!

    public static func preview(now: Date = Date()) -> PlantDocument {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let created = calendar.date(byAdding: .day, value: -12, to: calendar.startOfDay(for: now))!
        let alex = Partner(id: alexID, name: "Alex", joinedAt: created)
        let sam = Partner(id: samID, name: "Sam", joinedAt: created)
        let plantCalendar = PlantCalendar(identifier: "UTC")
        var watered: [String: [UUID]] = [:]
        var day = created
        let today = calendar.startOfDay(for: now)
        while day < today {
            watered[plantCalendar.dayKey(for: day)] = [alex.id, sam.id]
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        watered[plantCalendar.dayKey(for: now)] = [alex.id]
        return PlantDocument(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            name: "Pip",
            speciesID: PlantSpecies.sproutling.rawValue,
            potID: PotStyle.terracotta.rawValue,
            createdAt: created,
            timeZoneIdentifier: "UTC",
            inviteCode: "PIP234",
            partners: [alex, sam],
            wateredDays: watered,
            updatedAt: now,
            revision: 4
        )
    }
}
