import Foundation

public struct PlantCalendar: Equatable {
    public let timeZone: TimeZone

    public init(identifier: String) {
        timeZone = TimeZone(identifier: identifier) ?? .current
    }

    public func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public func hour(of date: Date) -> Int {
        calendar.component(.hour, from: date)
    }

    public func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Days from the plant's birthday up to, but not including, today.
    public func pastDayKeys(from start: Date, now: Date) -> [String] {
        let startDay = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: now)
        guard startDay < today else { return [] }
        var keys: [String] = []
        var cursor = startDay
        while cursor < today {
            keys.append(dayKey(for: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return keys
    }

    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }
}
