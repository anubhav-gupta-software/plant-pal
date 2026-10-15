import Foundation

public enum PlantMerge {
    /// Combines two copies of the same plant. Sips are unioned, so a day when
    /// each phone recorded a different person still becomes a thriving day.
    public static func merge(local: PlantDocument, remote: PlantDocument, now: Date = Date()) -> PlantDocument {
        guard local.id == remote.id else {
            return remote.updatedAt >= local.updatedAt ? remote : local
        }
        let newer = local.updatedAt >= remote.updatedAt ? local : remote
        let older = local.updatedAt >= remote.updatedAt ? remote : local
        var result = newer
        result.createdAt = min(local.createdAt, remote.createdAt)
        if local.createdAt == remote.createdAt {
            result.timeZoneIdentifier = newer.timeZoneIdentifier
        } else if local.createdAt < remote.createdAt {
            result.timeZoneIdentifier = local.timeZoneIdentifier
        } else {
            result.timeZoneIdentifier = remote.timeZoneIdentifier
        }
        result.partners = mergedPartners(newer: newer.partners, older: older.partners)
        let allowed = Set(result.partners.map(\.id))
        result.wateredDays = unionWater(local.wateredDays, remote.wateredDays, allowed: allowed)
        result.inviteCode = newer.inviteCode
        if isSameContent(result, local) {
            return local
        }
        if isSameContent(result, remote) {
            return remote
        }
        result.revision = max(local.revision, remote.revision) + 1
        result.updatedAt = now
        return result
    }

    public static func isSameContent(_ lhs: PlantDocument, _ rhs: PlantDocument) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.speciesID == rhs.speciesID
            && lhs.potID == rhs.potID
            && lhs.inviteCode == rhs.inviteCode
            && Set(lhs.partners) == Set(rhs.partners)
            && normalized(lhs.wateredDays) == normalized(rhs.wateredDays)
    }

    private static func mergedPartners(newer: [Partner], older: [Partner]) -> [Partner] {
        var pool = newer
        for partner in older where !pool.contains(where: { $0.id == partner.id }) {
            pool.append(partner)
        }
        let reals = pool.filter { !$0.isStandIn }.sorted { $0.joinedAt < $1.joinedAt }
        if reals.count >= 2 {
            return Array(reals.prefix(2))
        }
        if pool.count > 2 {
            return Array(pool.prefix(2))
        }
        return pool
    }

    private static func unionWater(
        _ lhs: [String: [UUID]],
        _ rhs: [String: [UUID]],
        allowed: Set<UUID>
    ) -> [String: [UUID]] {
        var combined: [String: [UUID]] = [:]
        for key in Set(lhs.keys).union(rhs.keys) {
            let ids = Set(lhs[key] ?? []).union(rhs[key] ?? []).intersection(allowed)
            if !ids.isEmpty {
                combined[key] = ids.sorted { $0.uuidString < $1.uuidString }
            }
        }
        return combined
    }

    private static func normalized(_ days: [String: [UUID]]) -> [String: Set<UUID>] {
        var result: [String: Set<UUID>] = [:]
        for (key, ids) in days where !ids.isEmpty {
            result[key] = Set(ids)
        }
        return result
    }
}
