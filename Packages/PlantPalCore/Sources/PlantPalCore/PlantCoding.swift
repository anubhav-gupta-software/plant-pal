import Foundation

public enum PlantCoding {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public enum PostcardError: Error, Equatable {
    case unrecognized
}

/// A plant snapshot you can paste into a message. Two phones can trade these
/// when iCloud sync is off and still end up with both sips.
public enum Postcard {
    public static let prefix = "PLANTPAL1."

    public static func encode(_ document: PlantDocument) throws -> String {
        let data = try PlantCoding.encoder().encode(document)
        return prefix + data.base64EncodedString()
    }

    public static func decode(_ raw: String) throws -> PlantDocument {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: prefix) {
            let payload = trimmed[range.upperBound...].filter { !$0.isWhitespace }
            guard let data = Data(base64Encoded: String(payload)) else {
                throw PostcardError.unrecognized
            }
            return try PlantCoding.decoder().decode(PlantDocument.self, from: data)
        }
        if trimmed.contains("{"),
           let data = trimmed.data(using: .utf8),
           let document = try? PlantCoding.decoder().decode(PlantDocument.self, from: data) {
            return document
        }
        throw PostcardError.unrecognized
    }
}
