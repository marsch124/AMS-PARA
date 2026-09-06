import SwiftUI
import AMSParaCore

/// The day's Apple Calendar events as rows for a List section or a VStack. The container
/// loads them with `.task(id: date) { await model.loadEvents(for: date) }`.
struct CalendarEventRows: View {
    @EnvironmentObject private var model: AppModel
    let date: DateOnly

    var body: some View {
        if model.calendarAccessGranted == false {
            Text("Calendar access is off. Allow it in System Settings › Privacy & Security › Calendars, or turn events off in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let events = model.events(on: date)
            if events.isEmpty {
                Text(model.calendarAccessGranted == nil ? "Loading events…" : "No events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events) { event in
                    CalendarEventRow(event: event, date: date)
                }
            }
        }
    }
}

struct CalendarEventRow: View {
    @EnvironmentObject private var model: AppModel
    let event: CalendarEvent
    let date: DateOnly

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(event.color)
                .frame(width: 8, height: 8)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 3 }
            Text(event.timeLabel(on: date))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .lineLimit(1)
                    if event.isTimeBlock {
                        Text("block")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(event.color.opacity(0.18), in: Capsule())
                    }
                }
                if let location = event.location {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button {
                model.openInCalendar(event)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Open in Calendar")
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.openInCalendar(event) }
        .contextMenu {
            Button("Open in Calendar") { model.openInCalendar(event) }
        }
        .help("\(event.title) (\(event.calendarTitle)). Double-click to open in Calendar.")
    }
}
