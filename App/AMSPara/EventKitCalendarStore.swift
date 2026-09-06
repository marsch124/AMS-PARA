import Foundation
import EventKit
import SwiftUI
import AMSParaCore

/// One event from Apple Calendar, as shown next to the day's tasks.
struct CalendarEvent: Identifiable, Equatable {
    var id: String
    /// EventKit's identifier, used to open the event in Calendar.
    var eventIdentifier: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendarTitle: String
    var color: Color
    var location: String?
    /// True for events AMS PARA created in the Time Blocks section.
    var isTimeBlock: Bool = false

    /// "All day", "09:00 – 10:30", or an arrow when the event runs past the day's edges.
    func timeLabel(on day: DateOnly, calendar: Calendar = .current) -> String {
        if isAllDay { return "All day" }
        guard let dayStart = day.date(calendar: calendar),
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return start.formatted(date: .omitted, time: .shortened)
        }
        let from = start < dayStart ? "…" : start.formatted(date: .omitted, time: .shortened)
        let to = end > dayEnd ? "…" : end.formatted(date: .omitted, time: .shortened)
        return "\(from) – \(to)"
    }
}

/// One calendar in Apple Calendar, for the Settings pickers.
struct CalendarInfo: Identifiable, Equatable {
    var id: String
    var title: String
    var sourceTitle: String
    var color: Color
    var isWritable: Bool
}

/// A block of time AMS PARA wrote to Apple Calendar. It is an ordinary event marked with
/// `amspara://timeblock` as its URL, so it shows up on every device and can be edited there too.
struct TimeBlock: Identifiable, Equatable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var notes: String
    var calendarID: String
    var calendarTitle: String
    var color: Color

    var day: DateOnly { DateOnly(start) }
}

/// Apple Calendar through EventKit. Reads every calendar the user chose; writes only the
/// time blocks it created itself. Separate from the Reminders store so each keeps its own permission.
@MainActor
final class EventKitCalendarStore {
    static let timeBlockURL = URL(string: "amspara://timeblock")!
    static let timeBlockMarker = "ams-para:timeblock"
    private let eventStore = EKEventStore()
    private var observer: NSObjectProtocol?
    /// Called on the main queue whenever Calendar reports a change.
    var onChange: (() -> Void)?

    init() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.onChange?() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    var isDenied: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .denied, .restricted, .writeOnly: return true
        default: return false
        }
    }

    func requestAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .denied, .restricted, .writeOnly:
            return false
        default:
            return (try? await eventStore.requestFullAccessToEvents()) ?? false
        }
    }

    // MARK: Calendars

    func calendars() -> [CalendarInfo] {
        eventStore.calendars(for: .event)
            .map { CalendarInfo(id: $0.calendarIdentifier,
                                title: $0.title,
                                sourceTitle: $0.source?.title ?? "",
                                color: $0.cgColor.map { Color(cgColor: $0) } ?? .accentColor,
                                isWritable: $0.allowsContentModifications) }
            .sorted { a, b in
                if a.sourceTitle != b.sourceTitle { return a.sourceTitle.localizedCaseInsensitiveCompare(b.sourceTitle) == .orderedAscending }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
    }

    var defaultCalendarID: String? {
        eventStore.defaultCalendarForNewEvents?.calendarIdentifier
    }

    private func ekCalendars(for ids: Set<String>?) -> [EKCalendar]? {
        guard let ids else { return nil }
        let picked = eventStore.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
        return picked.isEmpty ? nil : picked
    }

    private static func isTimeBlock(_ event: EKEvent) -> Bool {
        event.url?.scheme == timeBlockURL.scheme || event.notes?.contains(timeBlockMarker) == true
    }

    // MARK: Reading

    /// Events touching a day, all-day ones first, then by start time. `calendarIDs` nil means every calendar.
    func events(on day: DateOnly, calendarIDs: Set<String>? = nil, calendar: Calendar = .current) -> [CalendarEvent] {
        guard let start = day.date(calendar: calendar),
              let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: ekCalendars(for: calendarIDs))
        return eventStore.events(matching: predicate)
            .sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                if a.startDate != b.startDate { return a.startDate < b.startDate }
                return (a.title ?? "").localizedCaseInsensitiveCompare(b.title ?? "") == .orderedAscending
            }
            .map { event in
                let base = event.eventIdentifier ?? event.calendarItemIdentifier
                return CalendarEvent(id: "\(base)@\(event.startDate.timeIntervalSince1970)",
                                     eventIdentifier: base,
                                     title: event.title ?? "Untitled",
                                     start: event.startDate,
                                     end: event.endDate,
                                     isAllDay: event.isAllDay,
                                     calendarTitle: event.calendar?.title ?? "",
                                     color: event.calendar?.cgColor.map { Color(cgColor: $0) } ?? .accentColor,
                                     location: event.location?.isEmpty == false ? event.location : nil,
                                     isTimeBlock: Self.isTimeBlock(event))
            }
    }

    // MARK: Time blocks

    private func timeBlock(from event: EKEvent) -> TimeBlock {
        let notes = (event.notes ?? "")
            .replacingOccurrences(of: Self.timeBlockMarker, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return TimeBlock(id: event.eventIdentifier ?? event.calendarItemIdentifier,
                         title: event.title ?? "Untitled",
                         start: event.startDate,
                         end: event.endDate,
                         notes: notes,
                         calendarID: event.calendar?.calendarIdentifier ?? "",
                         calendarTitle: event.calendar?.title ?? "",
                         color: event.calendar?.cgColor.map { Color(cgColor: $0) } ?? .accentColor)
    }

    /// The blocks AMS PARA created, in any calendar, between two dates.
    func timeBlocks(from: Date, to: Date) -> [TimeBlock] {
        let predicate = eventStore.predicateForEvents(withStart: from, end: to, calendars: nil)
        return eventStore.events(matching: predicate)
            .filter(Self.isTimeBlock)
            .sorted { $0.startDate < $1.startDate }
            .map(timeBlock(from:))
    }

    @discardableResult
    func saveTimeBlock(id: String?, title: String, start: Date, end: Date, notes: String, calendarID: String?) throws -> TimeBlock {
        let event: EKEvent
        if let id, let existing = eventStore.event(withIdentifier: id) {
            event = existing
        } else {
            event = EKEvent(eventStore: eventStore)
        }
        if let calendarID, let calendar = eventStore.calendar(withIdentifier: calendarID), calendar.allowsContentModifications {
            event.calendar = calendar
        } else if event.calendar == nil {
            guard let fallback = eventStore.defaultCalendarForNewEvents else {
                throw CalendarError.noWritableCalendar
            }
            event.calendar = fallback
        }
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = false
        event.url = Self.timeBlockURL
        let body = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        event.notes = body.isEmpty ? Self.timeBlockMarker : body + "\n\n" + Self.timeBlockMarker
        try eventStore.save(event, span: .thisEvent, commit: true)
        return timeBlock(from: event)
    }

    func deleteTimeBlock(id: String) throws {
        guard let event = eventStore.event(withIdentifier: id) else { return }
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    enum CalendarError: LocalizedError {
        case noWritableCalendar
        var errorDescription: String? {
            "No calendar accepts new events. Pick one under Settings › Apple Calendar › Time blocks go to."
        }
    }
}
