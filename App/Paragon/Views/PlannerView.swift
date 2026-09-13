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
            lane(title: "Calendar", tint: SidebarSection.calendar.tint,
                 placements: placedEvents, filled: false)
            Divider()
            lane(title: "Time blocks", tint: SidebarSection.review.tint,
                 placements: placedBlocks, filled: true)
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
    private func lane(title: String, tint: Color, placements: [PlannerPlacement], filled: Bool) -> some View {
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
                        item(placed, tint: tint, filled: filled, width: geometry.size.width)
                    }
                }
            }
            .frame(height: laneHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two events at the same time stand side by side at half width, three at a third, and so
    /// on — the same rule the Calendar section's schedule has used since build 61.
    @ViewBuilder
    private func item(_ placed: PlannerPlacement, tint: Color, filled: Bool, width: CGFloat) -> some View {
        let usable = max(40, width - 12)
        let each = usable / CGFloat(max(1, placed.lanes))
        // Named `box`, not `card`: a local called `card` would shadow the method of that name
        // inside its own initial value.
        let inCalendar = placed.block.map { model.isInAppleCalendar($0, on: day) } ?? false
        let box = card(title: placed.title, time: placed.time, tint: tint, filled: filled, alsoAnEvent: inCalendar)
            .frame(width: max(30, each - 3), height: placed.height)
            .offset(x: 4 + each * CGFloat(placed.lane), y: placed.top)
        if let block = placed.block {
            Button { startEditing(block) } label: { box }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Edit\u{2026}") { startEditing(block) }
                    // A tick, not "Add to Apple Calendar": the control says which state you are
                    // in, never the state you would get (build 142).
                    Toggle("In Apple Calendar", isOn: Binding(
                        get: { model.isInAppleCalendar(block, on: day) },
                        set: { wanted in Task { await model.setInAppleCalendar(wanted, for: block, on: day) } }))
                    if let event = model.calendarBlock(for: block, on: day) {
                        Button("Open in Calendar") { model.openInCalendar(event) }
                    }
                    Divider()
                    Button("Remove", role: .destructive) { model.removePlanBlock(block, on: day) }
                }
        } else {
            box
        }
    }

    /// `alsoAnEvent` puts a small calendar symbol on a block he has copied into Apple Calendar,
    /// so the state can be seen without opening a menu — an action only a right-click reveals is
    /// an action nobody finds (build 74).
    private func card(title: String, time: String, tint: Color, filled: Bool, alsoAnEvent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text(time)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(tint.opacity(0.85))
                if alsoAnEvent {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(SidebarSection.calendar.tint)
                        .help("Also an event in Apple Calendar")
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
            HStack(spacing: 10) {
                Picker("Starts", selection: $draftStart) {
                    ForEach(startChoices, id: \.self) { minutes in
                        Text(PlanBlock.clock(minutes)).tag(minutes)
                    }
                }
                Picker("For", selection: $draftMinutes) {
                    ForEach(PlannerDayView.durations, id: \.self) { minutes in
                        Text(PlannerDayView.durationLabel(minutes)).tag(minutes)
                    }
                }
            }
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

    private var startChoices: [Int] {
        stride(from: firstHour * 60, through: lastHour * 60 + 30, by: 15).map { $0 }
    }

    private static let durations = [15, 30, 45, 60, 90, 120, 180, 240]

    private static func durationLabel(_ minutes: Int) -> String {
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
        .navigationTitle("Actions")
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
                                .foregroundStyle(SidebarSection.review.tint)
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
