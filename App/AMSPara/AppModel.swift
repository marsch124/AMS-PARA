import Foundation
import SwiftUI
import Combine
import AMSParaCore
#if os(macOS)
import AppKit
#endif

enum SidebarSection: Hashable, Identifiable {
    case inbox
    case today
    case calendar
    case review
    case map
    case timeBlocks
    case search
    case kind(ParaKind)

    var id: String { title }

    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .calendar: return "Calendar"
        case .review: return "Weekly review"
        case .map: return "Map"
        case .timeBlocks: return "Time Blocks"
        case .search: return "Search"
        case .kind(let kind): return kind.displayName
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: return "tray"
        case .today: return "sun.max"
        case .calendar: return "calendar"
        case .review: return "checklist.checked"
        case .map: return "point.3.filled.connected.trianglepath.dotted"
        case .timeBlocks: return "calendar.badge.clock"
        case .search: return "magnifyingglass"
        case .kind(.daily): return "calendar"
        case .kind(.goal): return "star"
        case .kind(.project): return "flag"
        case .kind(.area): return "circle.grid.2x2"
        case .kind(.resource): return "books.vertical"
        case .kind(.archive): return "archivebox"
        case .kind(.inbox): return "tray"
        }
    }

    static let all: [SidebarSection] = [.inbox, .today, .calendar, .timeBlocks, .review, .map, .search, .kind(.goal), .kind(.project), .kind(.area), .kind(.resource), .kind(.archive)]
}

/// The sheets the main window can present.
enum AppSheet: String, Identifiable {
    case newNote
    case quickCapture
    case settings

    var id: String { rawValue }
}

/// Bumped on every push so the running build can be told apart from an older one.
enum BuildStamp {
    static let number = 36
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var vault: Vault?
    @Published private(set) var notes: [Note] = [] {
        didSet { index = NoteIndex(notes: notes) }
    }
    /// Rebuilt whenever `notes` changes, so views never build it during a redraw.
    @Published private(set) var index = NoteIndex(notes: [])
    @Published var section: SidebarSection? = .inbox {
        didSet { if section != oldValue { log("section -> \(section.map(\.title) ?? "nil")"); tameSoon() } }
    }
    @Published var selectedNotePath: String? {
        didSet { if selectedNotePath != oldValue { log("note -> \(selectedNotePath ?? "nil")"); tameSoon() } }
    }

    /// Columns are re-created when the section changes; tame the new ones once they exist.
    private func tameSoon() {
        #if os(macOS)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            tameSplitViewColumns()
        }
        #endif
    }
    /// The full-text search query (Search section), separate from the list filter.
    @Published var queryText = ""
    @Published private(set) var isSyncing = false
    @Published private(set) var lastReport: SyncReport?
    @Published var errorMessage: String?
    /// SwiftUI only presents one sheet reliably per view, so all sheets go through this.
    @Published var activeSheet: AppSheet?
    @Published private(set) var lastCaptureMessage: String?
    @Published var selectedDate = DateOnly.today()
    @Published var selectedWeek = WeekRef.current()
    @Published var selectedMonth = MonthRef.current()
    @Published var calendarMode: CalendarMode = .day

    enum CalendarMode: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    let remindersStore = EventKitRemindersStore()
    let calendarStore = EventKitCalendarStore()
    /// Apple Calendar events per day, loaded when a day is shown.
    @Published private(set) var eventsByDay: [DateOnly: [CalendarEvent]] = [:]
    /// nil until Calendar access has been asked for; false when it was refused.
    @Published private(set) var calendarAccessGranted: Bool?
    /// Every calendar on this Mac, loaded once access is granted.
    @Published private(set) var calendars: [CalendarInfo] = []
    /// The blocks AMS PARA wrote to Apple Calendar, a week back and two months ahead.
    @Published private(set) var timeBlocks: [TimeBlock] = []

    private let defaults = UserDefaults.standard
    private let bookmarkKey = "vaultBookmark"
    private let deviceIDKey = "deviceID"
    private let autoSyncKey = "autoSyncMinutes"
    private let showCalendarKey = "showCalendarEvents"
    private let visibleCalendarsKey = "visibleCalendarIDs"
    private let timeBlockCalendarKey = "timeBlockCalendarID"
    private var securityScopedURL: URL?
    private var autoSyncTask: Task<Void, Never>?

    private var publishWatch: AnyCancellable?

    /// A short in-memory log of what the app did, for Help \u{203A} Copy Diagnostics.
    /// Not published: the publish watcher below appends to it.
    private(set) var diagnostics: [String] = []

    init() {
        log("launch build \(BuildStamp.number)")
        restoreVault()
        calendarStore.onChange = { [weak self] in
            Task { await self?.refreshEvents() }
        }
        if calendarStore.hasAccess {
            calendarAccessGranted = true
            calendars = calendarStore.calendars()
            Task { await loadTimeBlocks() }
        }
        #if os(macOS)
        installClickMonitor()
        for delay in [0.5, 2.0, 5.0] {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                tameSplitViewColumns()
            }
        }
        #endif
        // Reports our own frames whenever a change is published while SwiftUI is mid-update,
        // which is what "Publishing changes from within view updates" complains about.
        publishWatch = objectWillChange.sink { [weak self] _ in
            let frames = Thread.callStackSymbols
            guard frames.contains(where: { $0.contains("AG::") || $0.contains("AttributeGraph") || $0.contains("ViewGraph") }) else { return }
            let ours = frames.filter { $0.contains("AMSPara") }.prefix(8)
            self?.log("PUBLISH during view update:\n" + ours.joined(separator: "\n"))
        }
    }

    func log(_ line: String) {
        let stamp = Date().formatted(date: .omitted, time: .standard)
        diagnostics.append("\(stamp) \(line)")
        if diagnostics.count > 500 { diagnostics.removeFirst(100) }
        print("AMSPARA " + line)
    }

    var diagnosticsReport: String {
        var lines = ["AMS PARA build \(BuildStamp.number)",
                     "section: \(section.map(\.title) ?? "nil")  note: \(selectedNotePath ?? "nil")",
                     "notes: \(notes.count)  goals: \(notes.filter { $0.kind == .goal }.map(\.title))",
                     ""]
        lines += diagnostics
        return lines.joined(separator: "\n")
    }

    func copyDiagnostics() {
        #if os(macOS)
        reportLayout("on copy", after: 0)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticsReport, forType: .string)
        flash("Diagnostics copied. Paste them into the chat.")
        #endif
    }

    // MARK: Derived state

    var vaultPath: String? { vault?.rootURL.path }

    /// Stable per-device id; EventKit reminder identifiers are local to a device, so sync state is too.
    var deviceID: String {
        if let id = defaults.string(forKey: deviceIDKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: deviceIDKey)
        return id
    }

    var autoSyncMinutes: Int {
        get { defaults.integer(forKey: autoSyncKey) }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: autoSyncKey)
            scheduleAutoSync()
        }
    }

    /// Calendars whose events are shown; nil means all of them.
    var visibleCalendarIDs: Set<String>? {
        get { (defaults.array(forKey: visibleCalendarsKey) as? [String]).map(Set.init) }
        set {
            objectWillChange.send()
            if let newValue { defaults.set(Array(newValue).sorted(), forKey: visibleCalendarsKey) }
            else { defaults.removeObject(forKey: visibleCalendarsKey) }
            Task { await refreshEvents() }
        }
    }

    func isCalendarVisible(_ id: String) -> Bool {
        visibleCalendarIDs?.contains(id) ?? true
    }

    func setCalendar(_ id: String, visible: Bool) {
        var ids = visibleCalendarIDs ?? Set(calendars.map(\.id))
        if visible { ids.insert(id) } else { ids.remove(id) }
        visibleCalendarIDs = ids.count == calendars.count ? nil : ids
    }

    /// The calendar new time blocks are written to; nil means Calendar's default.
    var timeBlockCalendarID: String? {
        get { defaults.string(forKey: timeBlockCalendarKey) ?? calendarStore.defaultCalendarID }
        set {
            objectWillChange.send()
            if let newValue { defaults.set(newValue, forKey: timeBlockCalendarKey) }
            else { defaults.removeObject(forKey: timeBlockCalendarKey) }
        }
    }

    /// Whether Today and daily notes show the day's Apple Calendar events (on by default).
    var showsCalendarEvents: Bool {
        get { defaults.object(forKey: showCalendarKey) as? Bool ?? true }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: showCalendarKey)
            if newValue { Task { await self.refreshEvents() } }
        }
    }

    var config: VaultConfig {
        get { vault?.config ?? VaultConfig() }
        set {
            guard let vault else { return }
            objectWillChange.send()
            do { try vault.save(config: newValue) } catch { errorMessage = error.localizedDescription }
        }
    }

    func note(at path: String?) -> Note? {
        guard let path else { return nil }
        return notes.first { $0.relativePath == path }
    }

    /// Lists bind their selection through these so SwiftUI's own selection resets, which
    /// happen while it is redrawing, publish after the redraw instead of in the middle of it.
    var sectionSelection: Binding<SidebarSection?> {
        Binding(get: { self.section },
                set: { value in self.afterUpdate { if self.section != value { self.section = value } } })
    }

    /// Sheet dismissal and alert dismissal are also written by SwiftUI mid-update.
    var sheetSelection: Binding<AppSheet?> {
        Binding(get: { self.activeSheet },
                set: { value in self.afterUpdate { if self.activeSheet != value { self.activeSheet = value } } })
    }

    var errorPresented: Binding<Bool> {
        Binding(get: { self.errorMessage != nil },
                set: { shown in if !shown { self.afterUpdate { self.errorMessage = nil } } })
    }

    var noteSelection: Binding<String?> {
        Binding(get: { self.selectedNotePath },
                set: { value in self.afterUpdate { if self.selectedNotePath != value { self.selectedNotePath = value } } })
    }

    func notes(in section: SidebarSection?, matching searchText: String = "") -> [Note] {
        let base: [Note]
        switch section {
        case .inbox?: base = notes.filter { $0.kind == .inbox }
        case .kind(let kind)?: base = notes.filter { $0.kind == kind }
        case .calendar?: base = index.dailyNotes
        case .today?, .review?, .map?, .timeBlocks?, .search?, nil: base = notes
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) }
    }

    func count(for section: SidebarSection) -> Int {
        switch section {
        case .inbox: return note(at: vault?.config.inboxFile)?.openTasks.count ?? 0
        case .today: return index.openTasks(dueOnOrBefore: .today()).count + (todayNote?.openTasks.count ?? 0)
        case .calendar, .map, .search: return 0
        case .timeBlocks: return timeBlocks.filter { $0.day == .today() }.count
        case .review: return index.review(config: config).projectsNeedingAttention.count
        case .kind(let kind): return notes.filter { $0.kind == kind }.count
        }
    }

    // MARK: Vault lifecycle

    func openVault(at url: URL) {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = url.startAccessingSecurityScopedResource() ? url : nil
        do {
            let vault = try Vault(rootURL: url)
            try vault.bootstrap()
            storeBookmark(for: url)
            self.vault = vault
            selectedNotePath = nil
            reload()
            scheduleAutoSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeVault() {
        autoSyncTask?.cancel()
        autoSyncTask = nil
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        defaults.removeObject(forKey: bookmarkKey)
        vault = nil
        notes = []
        selectedNotePath = nil
    }

    private func restoreVault() {
        guard let data = defaults.data(forKey: bookmarkKey) else { return }
        var stale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        guard let url = try? URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &stale) else { return }
        securityScopedURL = url.startAccessingSecurityScopedResource() ? url : nil
        if stale { storeBookmark(for: url) }
        do {
            let vault = try Vault(rootURL: url)
            try vault.bootstrap()
            self.vault = vault
            reload()
            scheduleAutoSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func storeBookmark(for url: URL) {
        #if os(macOS)
        let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        let data = try? url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)
        #endif
        defaults.set(data, forKey: bookmarkKey)
    }

    func reload() {
        guard let vault else {
            notes = []
            return
        }
        do {
            notes = try vault.allNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Editing

    func save(_ note: Note) {
        guard let vault else { return }
        do {
            try vault.save(note)
            if let i = notes.firstIndex(where: { $0.relativePath == note.relativePath }) {
                notes[i] = note
            } else {
                reload()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveText(_ text: String, forNoteAt path: String) {
        guard var note = note(at: path), note.text != text else { return }
        note.text = text
        note.modifiedAt = Date()
        save(note)
    }

    func createNote(kind: ParaKind, title: String, extraFrontmatter: [(String, String)] = []) {
        guard let vault else { return }
        do {
            let note = try vault.createNote(kind: kind, title: title, extraFrontmatter: extraFrontmatter)
            reload()
            show(section: .kind(kind), notePath: note.relativePath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archive(_ note: Note) {
        guard let vault else { return }
        do {
            let archived = try vault.archive(note)
            reload()
            if selectedNotePath == note.relativePath { selectedNotePath = archived.relativePath }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Moves a note to the Trash. The Inbox note stays; empty it instead.
    func trash(_ note: Note) {
        guard let vault, note.kind != .inbox else { return }
        do {
            try vault.trash(note)
            log("trashed \(note.relativePath)")
            if selectedNotePath == note.relativePath { selectedNotePath = nil }
            reload()
            flash("Moved \u{201C}\(note.displayTitle)\u{201D} to the Trash")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Notes that can be archived: the working PARA kinds and goals.
    func canArchive(_ note: Note) -> Bool {
        [.project, .area, .resource, .goal].contains(note.kind)
    }

    func toggle(_ ref: TaskRef) {
        guard var note = note(at: ref.notePath) else { return }
        var task = ref.task
        if task.isDone { task.markOpen() } else { task.markDone() }
        note.replace(task: task)
        save(note)
    }

    func addTask(_ title: String, to path: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var note = note(at: path) else { return }
        note.append(task: TaskParser.normalized(TaskItem(title: trimmed)))
        save(note)
    }

    func addSubtask(_ title: String, to parent: TaskRef) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var note = note(at: parent.notePath) else { return }
        note.appendSubtask(TaskParser.normalized(TaskItem(title: trimmed)), to: parent.task)
        save(note)
    }

    func select(_ ref: TaskRef) {
        selectedNotePath = ref.notePath
    }

    // MARK: Daily notes

    var todayNote: Note? {
        guard let vault else { return nil }
        return note(at: vault.dailyNotePath(for: .today()))
    }

    /// Shows the weekly note for a week, creating the file when it does not exist yet.
    func openWeeklyNote(for week: WeekRef) {
        guard let vault else { return }
        selectedWeek = week
        selectedDate = week.contains(selectedDate) ? selectedDate : week.monday
        do {
            let existed = vault.weeklyNoteExists(for: week)
            let note = try vault.weeklyNote(for: week)
            if !existed { reload() }
            selectedNotePath = note.relativePath
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Shows the daily note for a date, creating the file when it does not exist yet.
    func openDailyNote(for date: DateOnly) {
        guard let vault else { return }
        selectedDate = date
        selectedWeek = WeekRef(containing: date)
        selectedMonth = MonthRef(containing: date)
        do {
            let existed = vault.dailyNoteExists(for: date)
            let note = try vault.dailyNote(for: date)
            if !existed { reload() }
            selectedNotePath = note.relativePath
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Follows a `[[wikilink]]` or `related:` reference. Unknown titles become a new resource note.
    func open(reference: String) {
        if let target = index.note(matching: reference) {
            show(target)
        } else {
            createNote(kind: .resource, title: reference)
        }
    }

    /// Navigates the way two clicks would: the section changes first, and the note is
    /// selected once the list for that section is on screen. Changing both in one
    /// pass from inside the detail column is what scrambled the window.
    func show(_ note: Note) {
        show(section: sidebarSection(for: note), notePath: note.relativePath)
    }

    func show(section target: SidebarSection, notePath: String?) {
        afterUpdate {
            if self.section != target { self.section = target }
            self.afterUpdate {
                if self.selectedNotePath != notePath { self.selectedNotePath = notePath }
            }
        }
    }

    /// A short, non-modal message in the bottom banner.
    func flash(_ message: String) {
        lastCaptureMessage = message
    }

    /// Follows a `goal:` reference. Unlike a wikilink this never creates a note: a goal that
    /// does not exist is a typo or a goal still to be written, so say so and show the Goals list.
    func openGoal(reference: String) {
        log("goal link clicked: \(reference)")
        let goals = notes.filter { $0.kind == .goal }
        let match = Self.goal(matching: reference, in: goals)
        log("goal match: \(match?.relativePath ?? "none")")
        #if os(macOS)
        reportLayout("before goal link", after: 0)
        #endif
        if let match {
            show(match)
        } else {
            show(section: .kind(.goal), notePath: nil)
            flash("No goal is called \"\(reference)\". Check the goal: line, or create it with New \u{203A} Goal.")
        }
        #if os(macOS)
        reportLayout("after goal link", after: 1)
        #endif
    }

    /// Finds the goal a `goal:` line points at; the matching lives in `NoteIndex.goal(matching:)`.
    static func goal(matching reference: String, in goals: [Note]) -> Note? {
        NoteIndex(notes: goals).goal(matching: reference)
    }

    #if os(macOS)
    private var clickMonitor: Any?

    /// Logs every click with the AppKit view it landed on, then checks whether the window's
    /// content grew past the window and records the view tree if it did.
    private func installClickMonitor() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self, let window = event.window, let content = window.contentView else { return event }
            let point = content.convert(event.locationInWindow, from: nil)
            let hit = content.hitTest(point)
            let kind = event.type == .leftMouseDown ? "mouseDown" : "mouseUp"
            let responder = window.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"
            self.log("\(kind) at \(point) on \(hit.map { String(describing: type(of: $0)) } ?? "nil") firstResponder=\(responder)")
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                self.repairOverflow(after: kind)
            }
            return event
        }
    }

    /// The split view sizes itself from its columns' intrinsic content size, and a column
    /// whose SwiftUI content fills the space it is given reports "what I have, plus the
    /// toolbar inset" every time it is re-measured. Each change (a task added, a section
    /// opened) then grew the split view past the window. Dropping the columns' intrinsic
    /// sizing breaks that loop; the split view is laid out by the window alone.
    @discardableResult
    func tameSplitViewColumns(in window: NSWindow? = nil) -> Int {
        guard let window = window ?? NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
              let content = window.contentView, let root = content.subviews.first else { return 0 }
        var changed = 0
        func walk(_ view: NSView, underSplit: Bool) {
            for sub in view.subviews {
                if sub is NSScrollView { continue }   // list rows and text views keep their sizing
                let inSplit = underSplit || sub is NSSplitView
                if inSplit, let host = sub as? IntrinsicSizingResettable, host.resetIntrinsicSizing() {
                    changed += 1
                }
                walk(sub, underSplit: inSplit)
            }
        }
        walk(root, underSplit: false)
        if changed > 0 {
            log("tamed \(changed) split view column(s)")
            content.needsLayout = true
        }
        return changed
    }

    private func repairOverflow(after cause: String) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
              let content = window.contentView, let host = content.subviews.first else { return }
        tameSplitViewColumns(in: window)
        let grown = host.subviews.first { $0.frame.height > content.bounds.height + 1 || $0.frame.minY < -1 }
        guard let grown else { return }
        log("OVERFLOW after \(cause): \(type(of: grown)) frame=\(grown.frame) in \(content.bounds.size)")
        log(layoutReport("overflow"))
        // Put the split view back where the window is; SwiftUI's next pass keeps it there
        // now that the columns no longer ask for more.
        grown.frame = CGRect(origin: .zero, size: content.bounds.size)
        grown.subviews.first?.frame = grown.bounds
        content.needsLayout = true
        content.layoutSubtreeIfNeeded()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            self.log(self.layoutReport("after repair"))
        }
    }

    /// Records the window's view tree, so a layout that went wrong can be read from the
    /// diagnostics: which scroll view moved, and whether the content overflows.
    func reportLayout(_ label: String, after seconds: Double) {
        if seconds <= 0 { log(layoutReport(label)); return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            log(layoutReport(label))
        }
    }

    private func layoutReport(_ label: String) -> String {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
              let content = window.contentView else { return "LAYOUT \(label): no window" }
        var lines = ["LAYOUT \(label): window \(window.frame.size) content \(content.bounds.size) safeArea \(content.safeAreaInsets)"]
        func walk(_ view: NSView, depth: Int) {
            if depth <= 6 || view is NSScrollView {
                var line = String(repeating: "  ", count: depth) + "\(type(of: view)) frame=\(view.frame)"
                if let host = view as? IntrinsicSizingResettable {
                    line += " hosting(intrinsic=\((host as? NSView)?.intrinsicContentSize ?? .zero))"
                }
                if let scroll = view as? NSScrollView {
                    line += " visibleOrigin=\(scroll.documentVisibleRect.origin) insets=\(scroll.contentInsets) doc=\(scroll.documentView?.frame.size ?? .zero)"
                }
                lines.append(line)
            }
            if view is NSScrollView { return }
            for sub in view.subviews { walk(sub, depth: depth + 1) }
        }
        walk(content, depth: 0)
        return lines.prefix(80).joined(separator: "\n")
    }
    #endif

    func sidebarSection(for note: Note) -> SidebarSection {
        switch note.kind {
        case .inbox: return .inbox
        case .daily: return .calendar
        default: return .kind(note.kind)
        }
    }

    // MARK: Quick capture

    static let appGroupID = "group.com.schabbauer.amspara"

    /// Shared with the share extension through the App Group; falls back to Application Support.
    static var outboxURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("AMS PARA", isDirectory: true)
        return base.appendingPathComponent("capture-outbox.jsonl")
    }

    /// Targets offered in the capture panel: Inbox, today's note, then every active project.
    var captureTargets: [CaptureTarget] {
        let projects = notes.filter { $0.kind == .project && !$0.isArchived && $0.status != "done" }
        return [CaptureTarget.inbox, .today] + projects.map { CaptureTarget.note(path: $0.relativePath) }
    }

    func captureTargetLabel(_ target: CaptureTarget) -> String {
        if case .note(let path) = target, let note = note(at: path) { return note.title }
        return target.label
    }

    /// Writes a capture straight into the vault, or parks it in the outbox when no vault is open.
    /// Runs a state change after the current SwiftUI update, so a view lifecycle
    /// callback never publishes while the view tree is being evaluated.
    func afterUpdate(_ work: @escaping () -> Void) {
        Task { @MainActor in work() }
    }

    func capture(_ item: CaptureItem) {
        guard let vault else {
            try? CaptureOutbox(fileURL: Self.outboxURL).append(item)
            lastCaptureMessage = "Saved, will be filed when a vault is open"
            return
        }
        do {
            let note = try vault.capture(item)
            reload()
            lastCaptureMessage = "Saved to \(note.displayTitle)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func capture(text: String, url: URL? = nil, target: CaptureTarget, asTask: Bool = true) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || url != nil else { return }
        capture(CaptureItem(text: trimmed, url: url, target: target, asTask: asTask))
    }

    /// Files everything the share extension left in the outbox. Returns how many items were filed.
    @discardableResult
    func drainOutbox() -> Int {
        guard let vault else { return 0 }
        let items = CaptureOutbox(fileURL: Self.outboxURL).drain()
        guard !items.isEmpty else { return 0 }
        var filed = 0
        for item in items {
            if (try? vault.capture(item)) != nil { filed += 1 }
        }
        reload()
        lastCaptureMessage = "\(filed) captured item\(filed == 1 ? "" : "s") filed"
        return filed
    }

    /// Handles `amspara://capture?...` and `amspara://<note title>` links.
    func handle(url: URL) {
        if let item = CaptureItem(url: url) {
            capture(item)
            return
        }
        if url.scheme?.lowercased() == CaptureItem.urlScheme, let host = url.host?.removingPercentEncoding, !host.isEmpty {
            open(reference: host)
        }
    }

    func clearCaptureMessage() {
        lastCaptureMessage = nil
    }

    // MARK: Search

    var searchQuery: SearchQuery { SearchQuery.parse(queryText) }

    var searchHits: [SearchHit] { index.search(searchQuery) }

    /// Jumps to the Search section with a query, e.g. from a tag or a saved search.
    func search(_ text: String) {
        queryText = text
        section = .search
        selectedNotePath = nil
    }

    // MARK: Review

    func setStatus(_ status: String, for note: Note) {
        var updated = note
        updated.frontmatter.set("status", status)
        save(updated)
    }

    func markReviewed(_ note: Note) {
        var updated = note
        updated.frontmatter.set("reviewed", DateOnly.today().description)
        save(updated)
    }

    func markAllReviewed() {
        for health in index.review(config: config).projects {
            markReviewed(health.note)
        }
    }

    // MARK: Apple Calendar

    func events(on day: DateOnly) -> [CalendarEvent] {
        eventsByDay[day] ?? []
    }

    /// Asks for Calendar access the first time and loads the calendar list.
    @discardableResult
    func ensureCalendarAccess() async -> Bool {
        if calendarAccessGranted == nil {
            let granted = await calendarStore.requestAccess()
            calendarAccessGranted = granted
            log("calendar access \(granted ? "granted" : "refused")")
        }
        guard calendarAccessGranted == true else { return false }
        if calendars.isEmpty { calendars = calendarStore.calendars() }
        return true
    }

    /// Loads a day's events from the chosen calendars.
    func loadEvents(for day: DateOnly) async {
        guard showsCalendarEvents, await ensureCalendarAccess() else { return }
        let events = calendarStore.events(on: day, calendarIDs: visibleCalendarIDs)
        if eventsByDay[day] != events { eventsByDay[day] = events }
    }

    /// Reloads every day shown so far and the time blocks, e.g. after Calendar reported a change.
    func refreshEvents() async {
        guard calendarAccessGranted == true else { return }
        calendars = calendarStore.calendars()
        for day in Array(eventsByDay.keys) { await loadEvents(for: day) }
        await loadTimeBlocks()
    }

    /// Opens the event in the Calendar app.
    func openInCalendar(_ event: CalendarEvent) {
        openInCalendar(eventIdentifier: event.eventIdentifier, start: event.start)
    }

    func openInCalendar(_ block: TimeBlock) {
        openInCalendar(eventIdentifier: block.id, start: block.start)
    }

    private func openInCalendar(eventIdentifier: String, start: Date) {
        #if os(macOS)
        if let url = URL(string: "ical://ekevent/\(eventIdentifier)") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: "calshow:\(start.timeIntervalSinceReferenceDate)") {
            UIApplication.shared.open(url)
        }
        #endif
    }

    // MARK: Time blocks

    func loadTimeBlocks() async {
        guard await ensureCalendarAccess() else { return }
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let to = Calendar.current.date(byAdding: .day, value: 60, to: now) ?? now
        let blocks = calendarStore.timeBlocks(from: from, to: to)
        if blocks != timeBlocks { timeBlocks = blocks }
    }

    /// Creates or updates a block in Apple Calendar. Returns false when it could not be saved.
    @discardableResult
    func saveTimeBlock(id: String?, title: String, start: Date, end: Date, notes: String, calendarID: String?) async -> Bool {
        guard await ensureCalendarAccess() else {
            errorMessage = "AMS PARA needs Calendar access to write time blocks. Allow it in System Settings › Privacy & Security › Calendars."
            return false
        }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        guard end > start else {
            errorMessage = "A time block has to end after it starts."
            return false
        }
        do {
            let block = try calendarStore.saveTimeBlock(id: id, title: name, start: start, end: end, notes: notes,
                                                        calendarID: calendarID ?? timeBlockCalendarID)
            log("time block \(id == nil ? "created" : "updated"): \(block.title) \(block.start)")
            await loadTimeBlocks()
            eventsByDay[block.day] = nil
            await loadEvents(for: block.day)
            flash(id == nil ? "Added to \(block.calendarTitle)" : "Time block updated")
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteTimeBlock(_ block: TimeBlock) async {
        do {
            try calendarStore.deleteTimeBlock(id: block.id)
            log("time block deleted: \(block.title)")
            await loadTimeBlocks()
            eventsByDay[block.day] = nil
            await loadEvents(for: block.day)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Sync

    func syncNow() async {
        guard let vault, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            guard try await remindersStore.requestAccess() else {
                errorMessage = "AMS PARA needs full access to Reminders. You can grant it in System Settings › Privacy & Security › Reminders."
                return
            }
            let engine = SyncEngine(vault: vault, store: remindersStore, deviceID: deviceID)
            lastReport = try await engine.run()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleAutoSync() {
        autoSyncTask?.cancel()
        autoSyncTask = nil
        let minutes = autoSyncMinutes
        guard minutes > 0, vault != nil else { return }
        autoSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(minutes * 60))
                guard !Task.isCancelled else { break }
                await self?.syncNow()
            }
        }
    }
}

#if os(macOS)
/// Lets any NSHostingView, whatever its content type, drop its intrinsic content size.
@MainActor protocol IntrinsicSizingResettable: AnyObject {
    /// Returns true when something changed.
    func resetIntrinsicSizing() -> Bool
}

extension NSHostingView: IntrinsicSizingResettable {
    func resetIntrinsicSizing() -> Bool {
        guard !sizingOptions.isEmpty else { return false }
        sizingOptions = []
        invalidateIntrinsicContentSize()
        return true
    }
}
#endif
