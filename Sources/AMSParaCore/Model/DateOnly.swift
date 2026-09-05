import Foundation

/// A calendar date without a time component, as written in notes (`2026-09-10`).
public struct DateOnly: Hashable, Comparable, Codable, CustomStringConvertible, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `YYYY-MM-DD`.
    public init?(_ string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d), y > 0 else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    public init?(components: DateComponents) {
        guard let y = components.year, let m = components.month, let d = components.day else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var dateComponents: DateComponents {
        DateComponents(year: year, month: month, day: day)
    }

    public func date(calendar: Calendar = .current) -> Date? {
        calendar.date(from: dateComponents)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: DateOnly, rhs: DateOnly) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public static func today(calendar: Calendar = .current) -> DateOnly {
        DateOnly(Date(), calendar: calendar)
    }
}

/// A wall-clock time without a date, as written in `>2026-09-10T14:30`.
public struct TimeOfDay: Hashable, Comparable, Codable, CustomStringConvertible, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Parses `HH:mm` (a single-digit hour is accepted).
    public init?(_ string: String) {
        let parts = string.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        self.init(hour: h, minute: m)
    }

    public init?(components: DateComponents) {
        guard let h = components.hour, let m = components.minute else { return nil }
        self.init(hour: h, minute: m)
    }

    public var description: String { String(format: "%02d:%02d", hour, minute) }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

public extension DateOnly {
    /// Date components for this day, with the time added when given.
    func dateComponents(at time: TimeOfDay?) -> DateComponents {
        var c = dateComponents
        if let time {
            c.hour = time.hour
            c.minute = time.minute
        }
        return c
    }

    func date(at time: TimeOfDay?, calendar: Calendar = .current) -> Date? {
        calendar.date(from: dateComponents(at: time))
    }
}

/// Formats and parses NotePlan style `@done(YYYY-MM-DD HH:mm)` stamps in local time.
public enum DoneStamp {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    public static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    public static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if let d = formatter.date(from: trimmed) { return d }
        if let day = DateOnly(trimmed) { return day.date() }
        return nil
    }
}
