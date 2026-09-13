import SwiftUI
import ParagonCore

/// Plan the day: the calendar, your own blocks, and the day's actions.
///
/// He drew this and chose its shape twice from previews — first the three parts and a shared
/// hour ruler (https://claude.ai/code/artifact/82be810e-11ca-4c7b-8fc2-3863ff07cfbd), then where
/// they sit (https://claude.ai/code/artifact/c8934eb1-0b1e-46ca-a3e7-4a3a90b2a5ae): the actions
/// in the **middle column** and the day's two lanes in the **detail column** of the ordinary
/// window, with the floating window kept as an extra.
///
/// So the screen is two pieces that also work apart:
/// - `PlannerActionsView` — the middle column.
/// - `PlannerDayView` — the detail column: the header, the hours, the two lanes.
/// - `PlannerView` — both side by side, for the ⇧⌘P window and for the phone.
///
/// The day they show is `AppModel.plannerDay`, not each view's own state, or the two columns
/// would drift apart.
///
/// A block is deliberately **not** a calendar event and **not** a task. It says where he means
/// to be, and it is a line in the daily note under `## Plan`. Nothing here writes to Apple
/// Calendar — that is `TimeBlocksView`, and it is reached from the header button.
struct PlannerView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif

    var body: some View {
        if isPhone {
            // One scroll for the whole page, never two inside each other (build 127).
            ScrollView {
                VStack(spacing: 0) {
                    PlannerDayView(scrolls: false)
                    Divider().padding(.vertical, 10)
                    PlannerActionsView(scrolls: false)
                }
            }
        } else {
            HStack(spacing: 0) {
                PlannerDayView(scrolls: true)
                Divider()
                PlannerActionsView(scrolls: true)
                    .frame(width: 290)
            }
        }
    }
}

// MARK: The day: hours, calendar, blocks

/// The detail column: the day's header and its two lanes.
struct PlannerDayView: View {
    @EnvironmentObject private var model: AppModel
    /// False when a parent is already scrolling, so the phone never nests two scroll views.
    var scrolls: Bool = true

    @State private var editing: PlanBlock?
    @State private var draftTitle = ""
    @State private var draftStart = 9 * 60
    @State private var draftMinutes = 60
    @State private var draftInCalendar = false
    @State private var sheet: PlannerSheet?

    /// Six in the morning to eleven at night covers a day without making the column a mile long.
    private let firstHour = 6
    private let lastHour = 23
    private let hourHeight: CGFloat = 44

    private var day: DateOnly { model.plannerDay }
    private var blocks: [PlanBlock] { model.planBlocks(for: day) }
    private var laneHeight: CGFloat { CGFloat(lastHour - firstHour + 1) * hourHeight }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if scrolls {
                ScrollView { lanesRow }
            } else {
                lanesRow
            }
        }
        .navigationTitle("Plan the day")
        .task(id: day) {
            await model.loadEvents(for: day)
            // Which of this day's blocks he has copied into Apple Calendar. Asked per day: the
            // planner can stand on any date, and `timeBlocks` only covers the coming weeks.
            await model.loadPlanLinks(for: day)
        }
        // One sheet for all of it, keyed by what is being shown (build 44).
        .sheet(item: $sheet) { which in
            switch which {
            case .block: editorSheet
            case .calendarBlocks: calendarBlocksSheet
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(dayTitle)
                    .font(.headline)
                    .lineLimit(2)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            HStack(spacing: 2) {
                Button { move(-1) } label: { Image(systemName: "chevron.left") }
                    .help("The day before")
                Button("Today") { model.plannerDay = .today() }
                    .disabled(day == .today())
                Button { move(1) } label: { Image(systemName: "chevron.right") }
                    .help("The day after")
            }
            .buttonStyle(.borderless)
            .fixedSize()
            Button {
                startNewBlock(at: nextFreeStart())
            } label: {
                Label("Block", systemImage: "plus")
            }
            .fixedSize()
            .help("Add a block to this day's plan")
            Button {
                sheet = .calendarBlocks
            } label: {
                Image(systemName: "calendar.badge.clock")
            }
            .buttonStyle(.borderless)
            .fixedSize()
            .help("The other kind of block: real events in Apple Calendar")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var dayTitle: String {
        guard let date = day.date() else { return day.description }
        return PlannerDayView.longDate.string(from: date)
    }

    /// Plain text, built outside the ViewBuilder.
    private var summary: String {
        var parts: [String] = []
        parts.append(blocks.isEmpty ? "no blocks yet" : (blocks.count == 1 ? "1 block" : "\(blocks.count) blocks"))
        let events = model.events(on: day).filter { !$0.isAllDay }.count
        if events > 0 { parts.append(events == 1 ? "1 event" : "\(events) events") }
        return parts.joined(separator: " \u{00b7} ")
    }

    private static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM y")
        return f
    }()

    private func move(_ days: Int) {
        model.plannerDay = day.adding(days: days, calendar: WeekRef.calendar)
    }

    // MARK: The lanes

    private var lanesRow: some View {
        HStack(alignment: .top, spacing: 0) {
            hours
            lane(title: "Calendar", tint: SidebarSection.calendar.tint, placements: placedEvents)
            Divider()
            lane(title: "Time blocks", tint: Theme.planBlockTint, placements: placedBlocks)
        }
    }

    private var hours: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(firstHour...lastHour, id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(height: hourHeight, alignment: .top)
                    .padding(.trailing, 6)
            }
        }
        .frame(width: 34)
        .padding(.top, 26)
    }

    /// One titled column of hour rules with its items on top.
    ///
    /// Items are placed with `.offset` inside a top-leading stack, **never `.position`**: a
    /// positioned view claims its parent's whole size and swallows every click in it (build 85).
    /// Their width comes from `GeometryReader`, because two things at the same hour share it.
    private func lane(title: String, tint: Color, placements: [PlannerPlacement]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: title, count: nil, tint: tint)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .frame(height: 26, alignment: .bottom)
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(firstHour...lastHour, id: \.self) { _ in
                            Divider()
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: laneHeight)
                    ForEach(placements) { placed in
                        let box = slot(placed, width: geometry.size.width)
                        if let block = placed.block {
                            PlanBlockCard(block: block,
                                          inCalendar: model.isInAppleCalendar(block, on: day),
                                          x: box.x, width: box.width,
                                          hourHeight: hourHeight,
                                          firstHour: firstHour, lastHour: lastHour,
                                          edit: { startEditing(block) },
                                          change: { start, minutes in change(block, start: start, minutes: minutes) },
                                          remove: { model.removePlanBlock(block, on: day) },
                                          setInCalendar: { wanted in
                                              Task { await model.setInAppleCalendar(wanted, for: block, on: day) }
                                          },
                                          openEvent: openEventAction(for: block))
                        } else {
                            item(placed, tint: tint, x: box.x, width: box.width)
                        }
                    }
                }
            }
            .frame(height: laneHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Where one item sits across the lane. Two events at the same time stand side by side at
    /// half the width, three at a third, and so on — the same rule the Calendar section's
    /// schedule has used since build 61.
    private func slot(_ placed: PlannerPlacement, width: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let usable = max(40, width - 12)
        let each = usable / CGFloat(max(1, placed.lanes))
        return (4 + each * CGFloat(placed.lane), max(30, each - 3))
    }

    /// An event from Apple Calendar. Read only: nothing here writes to the calendar.
    private func item(_ placed: PlannerPlacement, tint: Color, x: CGFloat, width: CGFloat) -> some View {
        PlanCardFace(title: placed.title, time: placed.time, tint: tint, filled: false)
            .frame(width: width, height: placed.height)
            .offset(x: x, y: placed.top)
    }

    /// "Open in Calendar", but only when the block really has a copy out there. Written as a
    /// function rather than a `map` on the optional: a closure that returns a closure is the
    /// kind of thing Swift's inference gives up on, and there is no compiler in this container.
    private func openEventAction(for block: PlanBlock) -> (() -> Void)? {
        guard let event = model.calendarBlock(for: block, on: day) else { return nil }
        return { model.openInCalendar(event) }
    }

    /// Moves or resizes a block and keeps its Apple Calendar copy with it, through the one
    /// sequential path (build 151): a move rewrites the key the event is found by.
    private func change(_ block: PlanBlock, start: Int, minutes: Int) {
        var moved = block
        moved.start = start
        moved.end = start + minutes
        let wanted = model.isInAppleCalendar(block, on: day)
        Task { await model.savePlanBlock(moved, on: day, replacing: block, inAppleCalendar: wanted) }
    }

    // MARK: Where things sit

    private func top(forMinutes minutes: Int) -> CGFloat {
        CGFloat(minutes - firstHour * 60) / 60 * hourHeight
    }

    private func height(forMinutes minutes: Int) -> CGFloat {
        max(22, CGFloat(minutes) / 60 * hourHeight)
    }

    private var placedEvents: [PlannerPlacement] {
        let calendar = WeekRef.calendar
        let spans: [PlannerSpan] = model.events(on: day).compactMap { event in
            guard !event.isAllDay else { return nil }
            let from = calendar.dateComponents([.hour, .minute], from: event.start)
            let to = calendar.dateComponents([.hour, .minute], from: event.end)
            let start = (from.hour ?? 0) * 60 + (from.minute ?? 0)
            var end = (to.hour ?? 0) * 60 + (to.minute ?? 0)
            if end <= start { end = start + 30 }
            return PlannerSpan(id: event.id, start: start, end: end, title: event.title, block: nil)
        }
        return place(spans)
    }

    private var placedBlocks: [PlannerPlacement] {
        place(blocks.map {
            PlannerSpan(id: "block-\($0.index)", start: $0.start, end: $0.end, title: $0.title, block: $0)
        })
    }

    /// Spans that overlap share the width. Sorted by start, then greedily given the first lane
    /// whose last item has finished; a gap with nothing running closes the group off.
    private func place(_ spans: [PlannerSpan]) -> [PlannerPlacement] {
        var result: [PlannerPlacement] = []
        var group: [(span: PlannerSpan, lane: Int)] = []
        var laneEnds: [Int] = []

        func flush() {
            let count = max(1, laneEnds.count)
            for pair in group {
                result.append(PlannerPlacement(span: pair.span,
                                               top: top(forMinutes: pair.span.start),
                                               height: height(forMinutes: max(1, pair.span.end - pair.span.start)),
                                               lane: pair.lane,
                                               lanes: count))
            }
            group.removeAll()
            laneEnds.removeAll()
        }

        for span in spans.sorted(by: { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }) {
            if let latest = laneEnds.max(), span.start >= latest { flush() }
            if let free = laneEnds.firstIndex(where: { $0 <= span.start }) {
                laneEnds[free] = span.end
                group.append((span, free))
            } else {
                laneEnds.append(span.end)
                group.append((span, laneEnds.count - 1))
            }
        }
        flush()
        return result
    }

    // MARK: Making and changing a block

    /// Just after the last block, so a new one lands somewhere sensible.
    private func nextFreeStart() -> Int {
        guard let last = blocks.map(\.end).max() else { return 9 * 60 }
        return min(last, lastHour * 60)
    }

    private func startNewBlock(at start: Int, titled title: String = "") {
        editing = nil
        draftTitle = title
        draftStart = start
        draftMinutes = 60
        draftInCalendar = false
        sheet = .block
    }

    private func startEditing(_ block: PlanBlock) {
        editing = block
        draftTitle = block.title
        draftStart = block.start
        draftMinutes = block.minutes
        draftInCalendar = model.isInAppleCalendar(block, on: day)
        sheet = .block
    }

    private var editorSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editing == nil ? "New block" : "Edit block")
                .font(.headline)
            TextField("What is this time for?", text: $draftTitle)
                .textFieldStyle(.roundedBorder)
            // Build 152, at his word: "the time editing process is very crude". Two long
            // dropdowns became the system's own time field, a row of lengths, and one line
            // saying what that adds up to — so the answer is visible without opening anything.
            HStack(spacing: 10) {
                Text("Starts")
                    .foregroundStyle(.secondary)
                DatePicker("", selection: startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Button {
                    draftStart = max(firstHour * 60, draftStart - 15)
                } label: {
                    Image(systemName: "minus")
                }
                Button {
                    draftStart = min((lastHour + 1) * 60 - 15, draftStart + 15)
                } label: {
                    Image(systemName: "plus")
                }
                Spacer(minLength: 0)
            }
            .buttonStyle(.borderless)
            VStack(alignment: .leading, spacing: 6) {
                Text("For how long")
                    .foregroundStyle(.secondary)
                WrappingHStack(spacing: 6, lineSpacing: 6) {
                    ForEach(lengthChoices, id: \.self) { minutes in
                        LengthChip(title: PlannerDayView.durationLabel(minutes),
                                   isOn: draftMinutes == minutes) { draftMinutes = minutes }
                    }
                }
                .lineLimit(1)
            }
            Text(draftSummary)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Theme.planBlockTint)
            Toggle("Also put this block in Apple Calendar", isOn: $draftInCalendar)
            Text(draftInCalendar
                 ? "An event is written to the calendar under Settings \u{203a} Apple Calendar \u{203a} Time blocks go to. Change the block here and the event follows it; remove the block, or take the tick off, and the event goes."
                 : "A block is only for you. It is a line in this day's note under Plan, it never becomes a task, and nothing outside PARAGON sees it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if let editing {
                    Button("Remove", role: .destructive) {
                        model.removePlanBlock(editing, on: day)
                        sheet = nil
                    }
                }
                Spacer()
                Button("Cancel") { sheet = nil }
                Button("Save", action: saveDraft)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draftTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(18)
        .frame(minWidth: 360)
    }

    private var calendarBlocksSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Blocks in Apple Calendar")
                    .font(.headline)
                Spacer()
                Button("Done") { sheet = nil }
            }
            .padding(14)
            Divider()
            TimeBlocksView()
        }
        .frame(minWidth: 420, minHeight: 460)
    }

    /// The start time as a `Date` on this day, for the system's own time field. Written back as
    /// minutes since midnight, which is all a `PlanBlock` ever holds.
    private var startTime: Binding<Date> {
        Binding(get: { dateOnDay(minutes: draftStart) ?? Date() },
                set: { chosen in
                    let parts = WeekRef.calendar.dateComponents([.hour, .minute], from: chosen)
                    draftStart = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                })
    }

    private func dateOnDay(minutes: Int) -> Date? {
        guard let midnight = day.date() else { return nil }
        return WeekRef.calendar.date(byAdding: .minute, value: minutes, to: midnight)
    }

    /// "09:30 \u2013 11:00 \u00b7 1 h 30 min". Built outside the ViewBuilder.
    private var draftSummary: String {
        "\(PlanBlock.clock(draftStart)) \u{2013} \(PlanBlock.clock(draftStart + draftMinutes)) \u{00b7} \(PlannerDayView.durationLabel(draftMinutes))"
    }

    static let durations = [15, 30, 45, 60, 90, 120, 180, 240]

    /// The lengths offered, plus the block's own if a drag left it on something in between —
    /// otherwise no chip would be lit and the row would look like it had lost the answer.
    private var lengthChoices: [Int] {
        var all = PlannerDayView.durations
        if !all.contains(draftMinutes) {
            all.append(draftMinutes)
            all.sort()
        }
        return all
    }

    static func durationLabel(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min"
            : (minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min")
    }

    private func saveDraft() {
        let title = draftTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let made = PlanBlock(start: draftStart, end: draftStart + draftMinutes, title: title,
                             index: editing?.index ?? 0)
        // The note and the event are settled in one call, in order: moving a block changes the
        // key the event is found by, so the two cannot be done side by side.
        let previous = editing
        let wanted = draftInCalendar
        Task { await model.savePlanBlock(made, on: day, replacing: previous, inAppleCalendar: wanted) }
        sheet = nil
    }
}

// MARK: The cards

/// What a block or an event looks like. One view for both lanes, so they cannot drift apart.
private struct PlanCardFace: View {
    let title: String
    let time: String
    let tint: Color
    let filled: Bool
    var alsoAnEvent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text(time)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(tint.opacity(0.85))
                if alsoAnEvent {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(SidebarSection.calendar.tint)
                }
                Spacer(minLength: 0)
            }
            Text(title)
                .font(.caption.weight(filled ? .semibold : .regular))
                .foregroundStyle(tint)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(filled ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(tint.opacity(filled ? 0.5 : 0.28), lineWidth: 1)
        )
    }
}

/// One of his own blocks, which can be picked up and moved.
///
/// **Its own view because a live drag needs `@GestureState`** — the shape `MapNodeBox` has had
/// since build 83.
///
/// **One gesture on the card, not two** (build 85): a single `DragGesture(minimumDistance: 0)`
/// that decides in `onEnded` — no movement is a tap, which opens the sheet. The grip at the
/// foot is a *different* view, so its own drag never argues with the card's; it takes the press
/// with `highPriorityGesture` because it sits on top of the card.
///
/// **Dragging is macOS only, deliberately.** On the phone the lane is inside the page's scroll
/// view and a vertical drag belongs to that scroll. Taking it would be builds 71 to 74 in a new
/// place, and CI cannot catch it. The phone edits a block in the sheet, which is what build 152
/// rebuilt.
private struct PlanBlockCard: View {
    let block: PlanBlock
    let inCalendar: Bool
    let x: CGFloat
    let width: CGFloat
    let hourHeight: CGFloat
    let firstHour: Int
    let lastHour: Int
    let edit: () -> Void
    /// New start and new length, both in minutes.
    let change: (Int, Int) -> Void
    let remove: () -> Void
    let setInCalendar: (Bool) -> Void
    /// Set only when the block really has a copy in Apple Calendar.
    let openEvent: (() -> Void)?

    @GestureState private var shift: CGFloat = 0
    @GestureState private var stretch: CGFloat = 0

    #if os(macOS)
    private let canDrag = true
    #else
    private let canDrag = false
    #endif

    var body: some View {
        face
            .frame(width: width, height: height)
            .offset(x: x, y: top)
            .contextMenu { menu }
    }

    @ViewBuilder
    private var face: some View {
        let card = PlanCardFace(title: block.title, time: liveTime,
                                tint: Theme.planBlockTint, filled: true, alsoAnEvent: inCalendar)
        if canDrag {
            card
                .gesture(carry)
                .overlay(alignment: .bottom) { grip }
                .shadow(color: .black.opacity(moving ? 0.18 : 0), radius: moving ? 4 : 0, y: moving ? 2 : 0)
        } else {
            Button(action: edit) { card }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button("Edit\u{2026}", action: edit)
        // A tick, not "Add to Apple Calendar": a control says which state you are in, never the
        // state you would get (build 142).
        Toggle("In Apple Calendar", isOn: Binding(get: { inCalendar }, set: setInCalendar))
        if let openEvent {
            Button("Open in Calendar", action: openEvent)
        }
        Divider()
        Button("Remove", role: .destructive, action: remove)
    }

    /// Picking the whole block up. No movement at all is a tap, and a tap opens the sheet.
    private var carry: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($shift) { value, state, _ in state = value.translation.height }
            .onEnded { value in
                if abs(value.translation.height) < 4 {
                    edit()
                } else {
                    change(start(movedBy: value.translation.height), block.minutes)
                }
            }
    }

    /// The grip along the foot of the card: drag it to make the block longer or shorter.
    private var grip: some View {
        Capsule()
            .fill(Theme.planBlockTint.opacity(stretching ? 0.9 : 0.45))
            .frame(width: 26, height: 3)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, minHeight: 10)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .updating($stretch) { value, state, _ in state = value.translation.height }
                    .onEnded { value in
                        change(block.start, length(changedBy: value.translation.height))
                    }
            )
    }

    // MARK: What it looks like right now

    private var moving: Bool { shift != 0 }
    private var stretching: Bool { stretch != 0 }

    private var liveStart: Int { moving ? start(movedBy: shift) : block.start }
    private var liveMinutes: Int { stretching ? length(changedBy: stretch) : block.minutes }
    private var liveTime: String {
        "\(PlanBlock.clock(liveStart)) \u{2013} \(PlanBlock.clock(liveStart + liveMinutes))"
    }

    private var top: CGFloat { CGFloat(liveStart - firstHour * 60) / 60 * hourHeight }
    private var height: CGFloat { max(22, CGFloat(liveMinutes) / 60 * hourHeight) }

    /// Where the block would start after a drag of this many points, snapped to five minutes
    /// and kept inside the hours the lane draws.
    private func start(movedBy points: CGFloat) -> Int {
        let wanted = snapped(block.start + minutes(in: points))
        return max(firstHour * 60, min(wanted, (lastHour + 1) * 60 - block.minutes))
    }

    /// How long the block would be after the grip is dragged this far. Never under a quarter of
    /// an hour, and never past the foot of the lane.
    private func length(changedBy points: CGFloat) -> Int {
        let wanted = snapped(block.minutes + minutes(in: points))
        return max(15, min(wanted, (lastHour + 1) * 60 - block.start))
    }

    private func minutes(in points: CGFloat) -> Int {
        Int((points / hourHeight * 60).rounded())
    }

    private func snapped(_ minutes: Int) -> Int {
        Int((Double(minutes) / 5).rounded()) * 5
    }
}

/// One of the lengths offered in the block sheet. A filled capsule when it is the one chosen,
/// a dashed outline when it is not — the same two states `StateToggle` uses everywhere else
/// (build 142): the control shows which one you are on, never which one you would get.
private struct LengthChip: View {
    let title: String
    let isOn: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            Text(title)
                .font(.caption.weight(isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Theme.planBlockTint : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.planBlockTint.opacity(isOn ? 0.2 : 0), in: Capsule())
                .overlay(
                    Capsule().strokeBorder(isOn ? Theme.planBlockTint.opacity(0.7) : Color.secondary.opacity(0.4),
                                           style: StrokeStyle(lineWidth: 1, dash: isOn ? [] : [3, 3]))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// What the planner's one sheet is showing.
private enum PlannerSheet: String, Identifiable {
    case block
    case calendarBlocks
    var id: String { rawValue }
}

/// A stretch of the day waiting to be placed. A struct, not a tuple: a `ForEach` id is a key
/// path, and a key path cannot address a tuple member (build 61).
private struct PlannerSpan {
    let id: String
    let start: Int
    let end: Int
    let title: String
    /// Set for a plan block, nil for a calendar event. Only a block can be pressed.
    let block: PlanBlock?
}

private struct PlannerPlacement: Identifiable {
    let span: PlannerSpan
    let top: CGFloat
    let height: CGFloat
    /// Which of the side-by-side slots this one takes, and how many there are.
    let lane: Int
    let lanes: Int

    var id: String { span.id }
    var title: String { span.title }
    var block: PlanBlock? { span.block }
    var time: String { "\(PlanBlock.clock(span.start)) \u{2013} \(PlanBlock.clock(span.end))" }
}

// MARK: The actions

/// The middle column: what could go into the day.
///
/// Real `TaskRow`s, so a tick here ticks the task in its own note, the task menu is the same one
/// as everywhere else, and a name can be changed on the spot. `TaskRow` is draggable, which is
/// safe because this list has no selection of its own (builds 71 to 74 were about
/// `List(selection:)`).
struct PlannerActionsView: View {
    @EnvironmentObject private var model: AppModel
    var scrolls: Bool = true

    private var day: DateOnly { model.plannerDay }
    private var actions: [TaskRef] { model.actionsForPlanning(on: day) }

    var body: some View {
        Group {
            if scrolls {
                ScrollView { rows }
            } else {
                rows
            }
        }
        // The window's name has to be the sidebar row you pressed. It said "Actions" while
        // Time Blocks was selected (build 155, his report). The heading inside the column still
        // says Actions, because that is what the column is.
        .navigationTitle("Time Blocks")
    }

    @ViewBuilder
    private var rows: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Actions", count: actions.isEmpty ? nil : actions.count,
                         tint: SidebarSection.allActions.tint)
                .padding(.horizontal, 10)
                .padding(.bottom, 2)
                .frame(height: 26, alignment: .bottom)
            Text("Due today or earlier, then your next actions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            Divider()
            if actions.isEmpty {
                Text("Nothing due today and no next actions. Give a task a date, or mark one as the next action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
            }
            ForEach(actions) { ref in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top, spacing: 6) {
                        TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                        Button {
                            model.addPlanBlock(PlanBlock(start: nextFreeStart(),
                                                         end: nextFreeStart() + 60,
                                                         title: ref.task.title),
                                               on: day)
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Theme.planBlockTint)
                        }
                        .buttonStyle(.plain)
                        .help("Make an hour's block for this")
                    }
                    servesLine(for: ref)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                Divider()
            }
        }
    }

    /// What the task is in aid of: the goal its note serves, or the area it sits in. This is the
    /// chain the app is built on — task, project, goal — and a list of actions without sight of
    /// it is just a list.
    @ViewBuilder
    private func servesLine(for ref: TaskRef) -> some View {
        if let serves = serves(ref) {
            Label(serves.title, systemImage: serves.isGoal ? "star" : "circle.grid.2x2")
                .font(.caption2)
                .foregroundStyle(serves.isGoal ? ParaKind.goal.tint : ParaKind.area.tint)
                .lineLimit(1)
                .padding(.leading, 22)
        }
    }

    private struct Serves {
        let title: String
        let isGoal: Bool
    }

    private func serves(_ ref: TaskRef) -> Serves? {
        guard let note = model.note(at: ref.notePath) else { return nil }
        if let goal = note.goal {
            return Serves(title: model.index.goal(matching: goal)?.displayTitle ?? goal, isGoal: true)
        }
        if let area = note.area {
            return Serves(title: model.index.note(matching: area)?.displayTitle ?? area, isGoal: false)
        }
        return nil
    }

    private func nextFreeStart() -> Int {
        guard let last = model.planBlocks(for: day).map(\.end).max() else { return 9 * 60 }
        return min(last, 23 * 60)
    }
}
