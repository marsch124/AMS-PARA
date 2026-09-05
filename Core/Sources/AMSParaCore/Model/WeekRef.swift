import Foundation

/// An ISO 8601 week (Monday to Sunday), as in NotePlan's `Calendar/2026-W36.md` weekly notes.
public struct WeekRef: Hashable, Comparable, Codable, CustomStringConvertible, Sendable {
    public var year: Int
    public var week: Int

    public static let calendar: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone.current
        return c
    }()

    public init(year: Int, week: Int) {
        self.year = year
        self.week = week
    }

    /// The ISO week that contains a day.
    public init(containing day: DateOnly) {
        let cal = Self.calendar
        let date = day.date(calendar: cal) ?? Date()
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        self.init(year: c.yearForWeekOfYear ?? day.year, week: c.weekOfYear ?? 1)
    }

    /// Parses `2026-W36`.
    public init?(_ string: String) {
        let parts = string.uppercased().split(separator: "-")
        guard parts.count == 2, parts[1].hasPrefix("W"),
              let y = Int(parts[0]), let w = Int(parts[1].dropFirst()), (1...53).contains(w) else { return nil }
        self.init(year: y, week: w)
    }

    /// `2026-W36`
    public var description: String { String(format: "%04d-W%02d", year, week) }

    public var monday: DateOnly {
        let cal = Self.calendar
        var c = DateComponents()
        c.yearForWeekOfYear = year
        c.weekOfYear = week
        c.weekday = 2
        return DateOnly(cal.date(from: c) ?? Date(), calendar: cal)
    }

    public var sunday: DateOnly { monday.adding(days: 6, calendar: Self.calendar) }

    /// Monday through Sunday.
    public var days: [DateOnly] { (0..<7).map { monday.adding(days: $0, calendar: Self.calendar) } }

    public func contains(_ day: DateOnly) -> Bool { day >= monday && day <= sunday }

    public func adding(weeks: Int) -> WeekRef {
        WeekRef(containing: monday.adding(days: 7 * weeks, calendar: Self.calendar))
    }

    public static func < (lhs: WeekRef, rhs: WeekRef) -> Bool {
        (lhs.year, lhs.week) < (rhs.year, rhs.week)
    }

    public static func current() -> WeekRef { WeekRef(containing: .today()) }

    /// `Week 36, 31 Aug – 6 Sep 2026`
    public var title: String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d MMM")
        let start = monday.date().map(f.string(from:)) ?? monday.description
        let end = sunday.date().map(f.string(from:)) ?? sunday.description
        return "Week \(week), \(start) – \(end) \(sunday.year)"
    }
}

/// A month, for the month overview.
public struct MonthRef: Hashable, Comparable, Sendable {
    public var year: Int
    public var month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(containing day: DateOnly) {
        self.init(year: day.year, month: day.month)
    }

    public var firstDay: DateOnly { DateOnly(year: year, month: month, day: 1) }

    public var dayCount: Int {
        let cal = Calendar.current
        guard let date = firstDay.date(calendar: cal), let range = cal.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    public var days: [DateOnly] { (1...dayCount).map { DateOnly(year: year, month: month, day: $0) } }

    public func adding(months: Int) -> MonthRef {
        var m = month - 1 + months
        var y = year
        y += Int(floor(Double(m) / 12))
        m = ((m % 12) + 12) % 12
        return MonthRef(year: y, month: m + 1)
    }

    public static func < (lhs: MonthRef, rhs: MonthRef) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    public static func current() -> MonthRef { MonthRef(containing: .today()) }

    /// `September 2026`
    public var title: String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return firstDay.date().map(f.string(from:)) ?? "\(year)-\(month)"
    }
}
