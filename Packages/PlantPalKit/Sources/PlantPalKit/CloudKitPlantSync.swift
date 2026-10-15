import CloudKit
import Foundation

public enum CloudSyncError: LocalizedError {
    case noAccount
    case restricted
    case plantNotFound
    case unavailable(String)
    case conflict
    case invalidPayload

    public var errorDescription: String? {
        switch self {
        case .noAccount:
            return "Sign into iCloud in Settings, then try again."
        case .restricted:
            return "iCloud is restricted on this phone."
        case .plantNotFound:
            return "No plant is using that code yet."
        case .unavailable(let detail):
            return "iCloud sync isn't available (\(detail)). This phone and plant postcards keep working without it."
        case .conflict:
            return "The plant changed while saving. Try once more."
        case .invalidPayload:
            return "The iCloud plant record didn't make sense."
        }
    }
}

/// Optional CloudKit sync. The container id lives in `SyncConfig` and is a
/// placeholder until the iCloud capability is added. That capability needs
/// a paid Apple Developer Program membership, so a free personal team should
/// leave sync on This Phone.
public struct CloudKitPlantSync {
    public var containerID: String

    public init(containerID: String = SyncConfig.cloudKitContainerIdentifier) {
        self.containerID = containerID
    }

    public func ensureAccount() async throws {
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            throw map(error)
        }
        switch status {
        case .available:
            return
        case .noAccount:
            throw CloudSyncError.noAccount
        case .restricted:
            throw CloudSyncError.restricted
        case .couldNotDetermine, .temporarilyUnavailable:
            throw CloudSyncError.unavailable("iCloud didn't answer")
        @unknown default:
            throw CloudSyncError.unavailable("iCloud isn't available")
        }
    }

    public func fetch(inviteCode: String) async throws -> PlantDocument {
        try await ensureAccount()
        let recordID = CKRecord.ID(recordName: recordName(for: inviteCode))
        do {
            let record = try await database.record(for: recordID)
            return try decode(record)
        } catch let error as CloudSyncError {
            throw error
        } catch {
            throw map(error)
        }
    }

    /// Uploads the plant, unioning any sip the server learned about first.
    public func upload(_ document: PlantDocument) async throws -> PlantDocument {
        try await ensureAccount()
        var working = document
        let recordID = CKRecord.ID(recordName: recordName(for: working.inviteCode))
        for _ in 0..<4 {
            let existing: CKRecord?
            do {
                existing = try await database.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                existing = nil
            } catch let error as CloudSyncError {
                throw error
            } catch {
                throw map(error)
            }

            let record: CKRecord
            if let existing {
                let remote = try decode(existing)
                let merged = PlantMerge.merge(local: working, remote: remote)
                if PlantMerge.isSameContent(merged, remote), PlantMerge.isSameContent(merged, working) {
                    return working
                }
                working = merged
                record = existing
            } else {
                record = CKRecord(recordType: SyncConfig.recordType, recordID: recordID)
            }
            try apply(working, to: record)
            do {
                _ = try await database.save(record)
                return working
            } catch let error as CKError where error.code == .serverRecordChanged {
                continue
            } catch {
                throw map(error)
            }
        }
        throw CloudSyncError.conflict
    }

    private var container: CKContainer {
        CKContainer(identifier: containerID)
    }

    private var database: CKDatabase {
        container.publicCloudDatabase
    }

    private func recordName(for code: String) -> String {
        "plant-\(InviteCode.normalize(code))"
    }

    private func apply(_ document: PlantDocument, to record: CKRecord) throws {
        let data = try PlantCoding.encoder().encode(document)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw CloudSyncError.invalidPayload
        }
        record["payload"] = payload as NSString
        record["inviteCode"] = document.inviteCode as NSString
    }

    private func decode(_ record: CKRecord) throws -> PlantDocument {
        guard let payload = record["payload"] as? String,
              let data = payload.data(using: .utf8) else {
            throw CloudSyncError.invalidPayload
        }
        do {
            return try PlantCoding.decoder().decode(PlantDocument.self, from: data)
        } catch {
            throw CloudSyncError.invalidPayload
        }
    }

    private func map(_ error: Error) -> CloudSyncError {
        if let cloud = error as? CloudSyncError { return cloud }
        guard let ck = error as? CKError else {
            return .unavailable(error.localizedDescription)
        }
        switch ck.code {
        case .notAuthenticated:
            return .noAccount
        case .unknownItem:
            return .plantNotFound
        case .badContainer, .permissionFailure, .managedAccountRestricted:
            return .unavailable(ck.localizedDescription)
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .unavailable("the network hiccuped")
        default:
            return .unavailable(ck.localizedDescription)
        }
    }
}
