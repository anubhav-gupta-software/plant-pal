import XCTest
@testable import PlantPalCore

final class PlantEngineTests: XCTestCase {
    private let alex = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let sam = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let zone = "UTC"

    func testCreationDayHasNoWilt() {
        let created = date(2024, 5, 1)
        let plant = duo(created: created)
        let derived = PlantEngine.derive(plant, now: date(2024, 5, 1, hour: 21))
        XCTAssertEqual(derived.wilt, .perky)
        XCTAssertEqual(derived.totalThrivingDays, 0)
        XCTAssertEqual(derived.stage, .seed)
        XCTAssertTrue(derived.eveningThirst)
        XCTAssertEqual(derived.appearanceWilt, .thirsty)
        _ = plant
    }

    func testSoloWaterCountsAsThriving() {
        var plant = PlantEngine.makePlant(
            ownerName: "Alex",
            plantName: "Pip",
            palName: nil,
            now: date(2024, 5, 1),
            timeZoneIdentifier: zone,
            ownerID: alex
        )
        XCTAssertEqual(PlantEngine.water(&plant, partnerID: alex, now: date(2024, 5, 1, hour: 9)), .watered)
        let derived = PlantEngine.derive(plant, now: date(2024, 5, 2))
        XCTAssertEqual(derived.totalThrivingDays, 1)
        XCTAssertEqual(derived.currentStreak, 1)
        XCTAssertEqual(derived.stage, .sprout)
        XCTAssertEqual(derived.wilt, .perky)
    }

    func testSoloMissWilts() {
        let plant = PlantEngine.makePlant(
            ownerName: "Alex",
            plantName: "Pip",
            palName: nil,
            now: date(2024, 5, 1),
            timeZoneIdentifier: zone,
            ownerID: alex
        )
        let derived = PlantEngine.derive(plant, now: date(2024, 5, 2))
        XCTAssertEqual(derived.wilt, .thirsty)
        XCTAssertEqual(derived.currentStreak, 0)
        XCTAssertEqual(derived.stage, .seed)
    }

    func testBothPartnersAreRequired() {
        var plant = duo(created: date(2024, 5, 1))
        XCTAssertEqual(PlantEngine.water(&plant, partnerID: alex, now: date(2024, 5, 1, hour: 8)), .watered)
        XCTAssertEqual(PlantEngine.water(&plant, partnerID: sam, now: date(2024, 5, 1, hour: 18)), .watered)
        let derived = PlantEngine.derive(plant, now: date(2024, 5, 2, hour: 9))
        XCTAssertEqual(derived.totalThrivingDays, 1)
        XCTAssertEqual(derived.wilt, .perky)
        XCTAssertFalse(derived.everyoneWateredToday)
    }

    func testPartialWaterDoesNotThrive() {
        var plant = duo(created: date(2024, 5, 1))
        _ = PlantEngine.water(&plant, partnerID: alex, now: date(2024, 5, 1))
        let derived = PlantEngine.derive(plant, now: date(2024, 5, 2))
        XCTAssertEqual(derived.totalThrivingDays, 0)
        XCTAssertEqual(derived.wilt, .thirsty)
        XCTAssertEqual(derived.currentStreak, 0)
    }

    func testStreakResetsAndRemembersTheLongest() {
        var plant = duo(created: date(2024, 5, 1))
        waterBoth(&plant, day: date(2024, 5, 1))
        waterBoth(&plant, day: date(2024, 5, 2))
        let derived = PlantEngine.derive(plant, now: date(2024, 5, 5))
        XCTAssertEqual(derived.totalThrivingDays, 2)
        XCTAssertEqual(derived.longestStreak, 2)
        XCTAssertEqual(derived.currentStreak, 0)
        XCTAssertEqual(derived.wilt, .drooping)
    }

    func testWiltCapsAndHealsOneStep() {
        var plant = duo(created: date(2024, 5, 1))
        let derived = PlantEngine.derive(plant, now: date(2024, 5, 8))
        XCTAssertEqual(derived.wilt, .crisis)
        waterBoth(&plant, day: date(2024, 5, 8))
        let healed = PlantEngine.derive(plant, now: date(2024, 5, 9))
        XCTAssertEqual(healed.wilt, .drooping)
        XCTAssertEqual(healed.currentStreak, 1)
        XCTAssertEqual(healed.totalThrivingDays, 1)
    }

    func testStagesAndUnlocks() {
        XCTAssertEqual(GrowthStage.forThrivingDays(0), .seed)
        XCTAssertEqual(GrowthStage.forThrivingDays(1), .sprout)
        XCTAssertEqual(GrowthStage.forThrivingDays(3), .sprout)
        XCTAssertEqual(GrowthStage.forThrivingDays(4), .seedling)
        XCTAssertEqual(GrowthStage.forThrivingDays(8), .leafy)
        XCTAssertEqual(GrowthStage.forThrivingDays(16), .budding)
        XCTAssertEqual(GrowthStage.forThrivingDays(27), .budding)
        XCTAssertEqual(GrowthStage.forThrivingDays(28), .bloom)

        var plant = duo(created: date(2024, 1, 1))
        for offset in 0..<5 {
            waterBoth(&plant, day: date(2024, 1, 1 + offset))
        }
        let derived = PlantEngine.derive(plant, now: date(2024, 1, 7))
        XCTAssertEqual(derived.totalThrivingDays, 5)
        XCTAssertEqual(derived.stage, .seedling)
        XCTAssertTrue(derived.unlockedPots.contains(.ceramic))
        XCTAssertTrue(derived.unlockedSpecies.contains(.sunbloom))
        XCTAssertFalse(derived.unlockedPots.contains(.moss))
        XCTAssertFalse(PlantEngine.equip(species: .moonfern, on: &plant, now: date(2024, 1, 7)))
        XCTAssertTrue(PlantEngine.equip(species: .sunbloom, on: &plant, now: date(2024, 1, 7)))
        XCTAssertEqual(plant.species, .sunbloom)
    }

    func testCannotWaterTwiceOrAsAStranger() {
        var plant = duo(created: date(2024, 5, 1))
        XCTAssertEqual(PlantEngine.water(&plant, partnerID: alex, now: date(2024, 5, 1, hour: 8)), .watered)
        let revision = plant.revision
        XCTAssertEqual(PlantEngine.water(&plant, partnerID: alex, now: date(2024, 5, 1, hour: 10)), .alreadyWatered)
        XCTAssertEqual(plant.revision, revision)
        XCTAssertEqual(plant.wateredDays["2024-05-01"]?.count, 1)
        XCTAssertEqual(PlantEngine.water(&plant, partnerID: UUID(), now: date(2024, 5, 1)), .unknownPartner)
        XCTAssertEqual(plant.revision, revision)
    }

    func testInviteCodesStayInTheSafeAlphabet() {
        var generator = SplitMix64(seed: 42)
        for _ in 0..<40 {
            let code = InviteCode.make(length: 6, using: &generator)
            XCTAssertEqual(code.count, 6)
            XCTAssertTrue(code.allSatisfy { InviteCode.alphabet.contains($0) })
        }
        XCTAssertEqual(InviteCode.normalize(" ab-cd-ef "), "ABCDEF")
        XCTAssertEqual(InviteCode.normalize("pip123"), "PP23")
    }

    func testPostcardRoundTrip() throws {
        var plant = duo(created: date(2024, 5, 1))
        waterBoth(&plant, day: date(2024, 5, 1))
        let text = try Postcard.encode(plant)
        XCTAssertTrue(text.hasPrefix(Postcard.prefix))
        let decoded = try Postcard.decode("  \(text)\n")
        XCTAssertEqual(decoded, plant)
        XCTAssertThrowsError(try Postcard.decode("hello"))
    }

    func testMergeUnionsSipsAndKeepsTheNewerPot() {
        var local = duo(created: date(2024, 5, 1))
        var remote = local
        _ = PlantEngine.water(&local, partnerID: alex, now: date(2024, 5, 2, hour: 9))
        remote.potID = PotStyle.ceramic.rawValue
        remote.updatedAt = date(2024, 5, 2, hour: 11)
        remote.revision = 4
        _ = PlantEngine.water(&remote, partnerID: sam, now: date(2024, 5, 2, hour: 10))
        let merged = PlantMerge.merge(local: local, remote: remote, now: date(2024, 5, 2, hour: 12))
        XCTAssertEqual(merged.pot, .ceramic)
        XCTAssertEqual(Set(merged.wateredDays["2024-05-02"] ?? []), Set([alex, sam]))
        XCTAssertGreaterThan(merged.revision, remote.revision)
        let again = PlantMerge.merge(local: merged, remote: remote, now: date(2024, 5, 2, hour: 13))
        XCTAssertEqual(again.revision, merged.revision)
        XCTAssertTrue(PlantMerge.isSameContent(again, merged))
    }

    func testMergeDropsPracticePalWhenARealPalExists() {
        var local = PlantEngine.makePlant(
            ownerName: "Alex",
            plantName: "Pip",
            palName: nil,
            now: date(2024, 5, 1),
            timeZoneIdentifier: zone,
            ownerID: alex
        )
        let standIn = PlantEngine.addPracticePal(&local, name: "Practice", now: date(2024, 5, 1, hour: 2))!
        _ = PlantEngine.water(&local, partnerID: standIn, now: date(2024, 5, 1, hour: 3))
        var remote = local
        remote.updatedAt = date(2024, 5, 1, hour: 1)
        let real = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        remote.partners = [
            local.partners[0],
            Partner(id: real, name: "Sam", joinedAt: date(2024, 5, 1, hour: 13), isStandIn: false),
        ]
        let merged = PlantMerge.merge(local: local, remote: remote, now: date(2024, 5, 2))
        XCTAssertEqual(merged.partners.map(\.id), [alex, real])
        XCTAssertFalse(merged.wateredDays.values.flatMap { $0 }.contains(standIn))
    }

    func testJoinReplacesPracticePal() {
        var plant = PlantEngine.makePlant(
            ownerName: "Alex",
            plantName: "Pip",
            palName: nil,
            now: date(2024, 5, 1),
            timeZoneIdentifier: zone,
            ownerID: alex
        )
        let standIn = PlantEngine.addPracticePal(&plant, name: "Practice", now: date(2024, 5, 1))!
        _ = PlantEngine.water(&plant, partnerID: standIn, now: date(2024, 5, 1, hour: 8))
        let joined = PlantEngine.joinPartner(&plant, name: "Sam", id: sam, now: date(2024, 5, 2))
        XCTAssertEqual(joined, sam)
        XCTAssertEqual(plant.partners.map(\.name), ["Alex", "Sam"])
        XCTAssertFalse(plant.partners.contains(where: \.isStandIn))
        XCTAssertNil(PlantEngine.joinPartner(&plant, name: "Extra", now: date(2024, 5, 2)))
        XCTAssertFalse(plant.wateredDays.values.flatMap { $0 }.contains(standIn))
    }

    func testRecentDotsMarkTodaySeparately() {
        var plant = duo(created: date(2024, 5, 3))
        waterBoth(&plant, day: date(2024, 5, 3))
        _ = PlantEngine.water(&plant, partnerID: alex, now: date(2024, 5, 4, hour: 9))
        let dots = PlantEngine.recentDots(document: plant, now: date(2024, 5, 4, hour: 10), count: 3)
        XCTAssertEqual(dots.map(\.state), [
            .beforePlant,
            .thriving,
            .today(watered: 1, needed: 2),
        ])
    }

    func testTimeZoneKeepsTheCreatorsDay() {
        let plant = PlantEngine.makePlant(
            ownerName: "Alex",
            plantName: "Pip",
            palName: "Sam",
            now: date(2024, 6, 1, hour: 18),
            timeZoneIdentifier: "America/Los_Angeles",
            ownerID: alex
        )
        let sameEvening = PlantEngine.derive(plant, now: date(2024, 6, 2, hour: 6, minute: 30))
        XCTAssertEqual(sameEvening.wilt, .perky)
        XCTAssertEqual(sameEvening.todayKey, "2024-06-01")
        let nextMorning = PlantEngine.derive(plant, now: date(2024, 6, 2, hour: 8))
        XCTAssertEqual(nextMorning.todayKey, "2024-06-02")
        XCTAssertEqual(nextMorning.wilt, .thirsty)
    }

    func testCopyMentionsBothPeople() {
        var plant = duo(created: date(2024, 5, 1))
        _ = PlantEngine.water(&plant, partnerID: alex, now: date(2024, 5, 1, hour: 9))
        let derived = PlantEngine.derive(plant, now: date(2024, 5, 1, hour: 10))
        XCTAssertEqual(PlantCopy.headline(document: plant, derived: derived), "Halfway watered")
        XCTAssertTrue(PlantCopy.detail(document: plant, derived: derived).contains("Sam"))
        XCTAssertEqual(PlantCopy.widgetLine(document: plant, derived: derived, myPartnerID: alex), "Your sip's in")
    }

    private func duo(created: Date) -> PlantDocument {
        PlantDocument(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            name: "Pip",
            speciesID: PlantSpecies.sproutling.rawValue,
            potID: PotStyle.terracotta.rawValue,
            createdAt: created,
            timeZoneIdentifier: zone,
            inviteCode: "PIP234",
            partners: [
                Partner(id: alex, name: "Alex", joinedAt: created),
                Partner(id: sam, name: "Sam", joinedAt: created),
            ],
            wateredDays: [:],
            updatedAt: created,
            revision: 1
        )
    }

    private func waterBoth(_ plant: inout PlantDocument, day: Date) {
        _ = PlantEngine.water(&plant, partnerID: alex, now: day)
        _ = PlantEngine.water(&plant, partnerID: sam, now: day.addingTimeInterval(60))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

/// Tiny deterministic generator so invite-code tests don't depend on the clock.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58476D1CE4E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D049BB133111EB
        return mixed ^ (mixed >> 31)
    }
}
