import Foundation

public struct Partner: Codable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var joinedAt: Date
    public var isStandIn: Bool

    public init(id: UUID = UUID(), name: String, joinedAt: Date, isStandIn: Bool = false) {
        self.id = id
        self.name = name
        self.joinedAt = joinedAt
        self.isStandIn = isStandIn
    }
}

public enum PlayMode: String, Codable, Equatable {
    /// Both people water on this phone.
    case passAndPlay
    /// Each person waters on their own phone.
    case linkedPhones
}

public enum SyncMode: String, Codable, Equatable {
    case local
    case cloudKit
}

public struct PlantDocument: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var speciesID: String
    public var potID: String
    public var createdAt: Date
    /// Day boundaries follow the timezone of the person who started the plant,
    /// so both phones agree on what "today" means.
    public var timeZoneIdentifier: String
    public var inviteCode: String
    public var partners: [Partner]
    /// Calendar day key (`yyyy-MM-dd`) to the partners who watered that day.
    public var wateredDays: [String: [UUID]]
    public var updatedAt: Date
    public var revision: Int

    public init(
        id: UUID,
        name: String,
        speciesID: String,
        potID: String,
        createdAt: Date,
        timeZoneIdentifier: String,
        inviteCode: String,
        partners: [Partner],
        wateredDays: [String: [UUID]],
        updatedAt: Date,
        revision: Int
    ) {
        self.id = id
        self.name = name
        self.speciesID = speciesID
        self.potID = potID
        self.createdAt = createdAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.inviteCode = inviteCode
        self.partners = partners
        self.wateredDays = wateredDays
        self.updatedAt = updatedAt
        self.revision = revision
    }

    public var species: PlantSpecies { PlantSpecies(stored: speciesID) }
    public var pot: PotStyle { PotStyle(stored: potID) }
}

public struct DeviceProfile: Codable, Equatable {
    public var displayName: String
    public var myPartnerID: UUID?
    public var playMode: PlayMode
    public var remindersEnabled: Bool
    public var reminderHour: Int
    public var reminderMinute: Int
    public var syncMode: SyncMode
    public var onboardingComplete: Bool
    public var updatedAt: Date

    public init(
        displayName: String = "",
        myPartnerID: UUID? = nil,
        playMode: PlayMode = .passAndPlay,
        remindersEnabled: Bool = false,
        reminderHour: Int = 19,
        reminderMinute: Int = 0,
        syncMode: SyncMode = .local,
        onboardingComplete: Bool = false,
        updatedAt: Date = .distantPast
    ) {
        self.displayName = displayName
        self.myPartnerID = myPartnerID
        self.playMode = playMode
        self.remindersEnabled = remindersEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.syncMode = syncMode
        self.onboardingComplete = onboardingComplete
        self.updatedAt = updatedAt
    }
}
