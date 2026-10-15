import Foundation

public enum GrowthStage: Int, Codable, Equatable, CaseIterable, Identifiable {
    case seed = 0
    case sprout
    case seedling
    case leafy
    case budding
    case bloom

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .seed: return "Seed"
        case .sprout: return "Sprout"
        case .seedling: return "Seedling"
        case .leafy: return "Leafy"
        case .budding: return "Budding"
        case .bloom: return "Bloom"
        }
    }

    public var blurb: String {
        switch self {
        case .seed: return "A patient beginning."
        case .sprout: return "The first green yes."
        case .seedling: return "Real leaves now."
        case .leafy: return "Settling in."
        case .budding: return "Something is about to open."
        case .bloom: return "In full color."
        }
    }

    /// Thriving days needed before this stage appears.
    public var daysRequired: Int {
        switch self {
        case .seed: return 0
        case .sprout: return 1
        case .seedling: return 4
        case .leafy: return 8
        case .budding: return 16
        case .bloom: return 28
        }
    }

    public var next: GrowthStage? {
        GrowthStage(rawValue: rawValue + 1)
    }

    public static func forThrivingDays(_ days: Int) -> GrowthStage {
        switch days {
        case ..<1: return .seed
        case 1..<4: return .sprout
        case 4..<8: return .seedling
        case 8..<16: return .leafy
        case 16..<28: return .budding
        default: return .bloom
        }
    }
}

public enum WiltLevel: Int, Codable, Equatable, CaseIterable {
    case perky = 0
    case thirsty
    case drooping
    case crisis

    public var title: String {
        switch self {
        case .perky: return "Perky"
        case .thirsty: return "Thirsty"
        case .drooping: return "Drooping"
        case .crisis: return "Needs you both"
        }
    }
}

public enum PlantSpecies: String, Codable, CaseIterable, Identifiable, Equatable {
    case sproutling
    case sunbloom
    case moonfern
    case rosythorn
    case bubbleshroom
    case starlily

    public var id: String { rawValue }

    public init(stored id: String) {
        self = PlantSpecies(rawValue: id) ?? .sproutling
    }

    public var displayName: String {
        switch self {
        case .sproutling: return "Sproutling"
        case .sunbloom: return "Sunbloom"
        case .moonfern: return "Moonfern"
        case .rosythorn: return "Rosythorn"
        case .bubbleshroom: return "Bubbleshroom"
        case .starlily: return "Starlily"
        }
    }

    public var blurb: String {
        switch self {
        case .sproutling: return "The original. Cheerful, round, and easy to love."
        case .sunbloom: return "Warm petals that look like a small sun."
        case .moonfern: return "Silver fronds for quiet evenings."
        case .rosythorn: return "A soft rose with a little backbone."
        case .bubbleshroom: return "A spotty cap who thinks it's a flower."
        case .starlily: return "Six pointed petals and a night-sky center."
        }
    }

    public var unlockThrivingDays: Int {
        switch self {
        case .sproutling: return 0
        case .sunbloom: return 5
        case .moonfern: return 12
        case .rosythorn: return 20
        case .bubbleshroom: return 28
        case .starlily: return 45
        }
    }
}

public enum PotStyle: String, Codable, CaseIterable, Identifiable, Equatable {
    case terracotta
    case ceramic
    case moss
    case galaxy
    case seashell
    case golden

    public var id: String { rawValue }

    public init(stored id: String) {
        self = PotStyle(rawValue: id) ?? .terracotta
    }

    public var displayName: String {
        switch self {
        case .terracotta: return "Terracotta"
        case .ceramic: return "Ceramic"
        case .moss: return "Moss"
        case .galaxy: return "Galaxy"
        case .seashell: return "Seashell"
        case .golden: return "Golden"
        }
    }

    public var blurb: String {
        switch self {
        case .terracotta: return "Classic, warm, and a little dusty."
        case .ceramic: return "White clay with a blue stripe."
        case .moss: return "Green, soft, and slightly wild."
        case .galaxy: return "Dark glaze and tiny stars."
        case .seashell: return "Peach curves, like a day at the shore."
        case .golden: return "For a plant who stayed."
        }
    }

    public var unlockThrivingDays: Int {
        switch self {
        case .terracotta: return 0
        case .ceramic: return 3
        case .moss: return 8
        case .galaxy: return 16
        case .seashell: return 24
        case .golden: return 36
        }
    }
}

public enum InviteCode {
    public static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    public static func make(length: Int = 6) -> String {
        var generator = SystemRandomNumberGenerator()
        return make(length: length, using: &generator)
    }

    public static func make(length: Int, using generator: inout some RandomNumberGenerator) -> String {
        String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    public static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { alphabet.contains($0) }.prefix(6))
    }
}
