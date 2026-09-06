import Foundation
import EventKit
import SwiftUI
import AMSParaCore

/// One event from Apple Calendar, as shown next to the day's tasks.
struct CalendarEvent: Identifiable, Equatable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendarTitle: String
    var color: Color
    var location: String?

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

/// Apple Calendar through EventKit, read only. Separate from the Reminders store so each
/// keeps its own permission.
@MainActor
final class EventKitCalendarStore {
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

    /// Events touching a day, all-day ones first, then by start time.
    func events(on day: DateOnly, calendar: Calendar = .current) -> [CalendarEvent] {
        guard let start = day.date(calendar: calendar),
              let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        return eventStore.events(matching: predicate)
            .sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                if a.startDate != b.startDate { return a.startDate < b.startDate }
                return (a.title ?? "").localizedCaseInsensitiveCompare(b.title ?? "") == .orderedAscending
            }
            .map { event in
                let base = event.eventIdentifier ?? event.calendarItemIdentifier
                return CalendarEvent(id: "\(base)@\(event.startDate.timeIntervalSince1970)",
                                     title: event.title ?? "Untitled",
                                     start: event.startDate,
                                     end: event.endDate,
                                     isAllDay: event.isAllDay,
                                     calendarTitle: event.calendar?.title ?? "",
                                     color: event.calendar?.cgColor.map { Color(cgColor: $0) } ?? .accentColor,
                                     location: event.location?.isEmpty == false ? event.location : nil)
            }
    }
}
