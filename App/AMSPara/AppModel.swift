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
    case done
    case allActions
    case recent
    case deleted
    case templates
    case search
    /// Only in the sidebar once it has been asked for; see AppModel.workRevealed.
    case work
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
        case .done: return "Done"
        case .allActions: return "All actions"
        case .recent: return "Recent"
        case .deleted: return "Deleted"
        case .templates: return "Templates"
        case .search: return "Search"
        case .work: return "Work"
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
        case .done: return "checkmark.circle"
        case .allActions: return "list.bullet"
        case .recent: return "clock.arrow.circlepath"
        case .deleted: return "trash"
        case .templates: return "doc.badge.gearshape"
        case .search: return "magnifyingglass"
        case .work: return "briefcase"
        case .kind(.daily): return "calendar"
        case .kind(.goal): return "star"
        case .kind(.project): return "flag"
        case .kind(.area): return "circle.grid.2x2"
        case .kind(.resource): return "books.vertical"
        case .kind(.archive): return "archivebox"
        case .kind(.inbox): return "tray"
        }
    }

    static let all: [SidebarSection] = [.inbox, .today, .allActions, .recent, .calendar, .timeBlocks, .done, .review, .map, .deleted, .templates, .search, .kind(.goal), .kind(.project), .kind(.area), .kind(.resource), .kind(.archive)]
}

/// The sheets the main window can present.
enum AppSheet: String, Identifiable {
    case newNote
    case quickCapture
    case settings
    case syncReport
    /// A `[[link]]` was clicked that names no note yet; the sheet offers to make it.
    case noteFromLink

    var id: String { rawValue }
}

/// Bumped on every push so the running build can be told apart from an older one.
enum BuildStamp {
    static let number = 118
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
        didSet {
            guard selectedNotePath != oldValue else { return }
            log("note -> \(selectedNotePath ?? "nil")")
            if let selectedNotePath {
                rememberOpened(selectedNotePath)
                recordVisit(selectedNotePath)
            }
            tameSoon()
        }
    }

    /// The notes opened most recently, newest first, kept across launches so "Recent" is
    /// useful the moment the app starts. Paths, not notes: the files move and are renamed.
    @Published private(set) var recentNotePaths: [String] = UserDefaults.standard.stringArray(forKey: AppModel.recentKey) ?? []
    private static let recentKey = "recentNotePaths"
    private static let recentLimit = 40

    /// The recent paths that still lead to a note, in the order they were opened.
    var recentNotes: [Note] { recentNotePaths.compactMap { note(at: $0) } }

    private func rememberOpened(_ path: String) {
        var listed = recentNotePaths.filter { $0 != path }
        listed.insert(path, at: 0)
        recentNotePaths = Array(listed.prefix(Self.recentLimit))
        UserDefaults.standard.set(recentNotePaths, forKey: Self.recentKey)
    }

    func clearRecentNotes() {
        recentNotePaths = []
        UserDefaults.standard.removeObject(forKey: Self.recentKey)
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
        case day, week, month, notes
        var id: String { rawValue }
        var label: String { self == .notes ? "Notes" : rawValue.capitalized }
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
    /// Filled by "Block time for this…" on a task; the Time Blocks form picks it up.
    @Published var timeBlockDraft: TimeBlockDraft?
    /// The inbox line being sorted, as `TaskRef.triageID`. Shared so the middle column and
    /// the "File it" column on the right are talking about the same line.
    @Published var inboxSelection: String?
    /// True only while "Open the Inbox note" is showing the raw note. Otherwise the Inbox's
    /// right-hand column is "File it" — a note selected elsewhere must not take it over.
    @Published var inboxShowsNote = false
    /// Saved copies of the vault, newest first.
    @Published private(set) var backups: [VaultBackup] = []
    /// The report shown in the sync sheet, and whether it was a rehearsal.
    @Published private(set) var reportToShow: SyncReport?
    @Published private(set) var reportIsPreview = false

    struct TimeBlockDraft: Equatable {
        var title: String
        var notes: String
    }

    private let defaults = UserDefaults.standard
    private let bookmarkKey = "vaultBookmark"
    private let deviceIDKey = "deviceID"
    private let autoSyncKey = "autoSyncMinutes"
    private let showCalendarKey = "showCalendarEvents"
    private let visibleCalendarsKey = "visibleCalendarIDs"
    private let timeBlockCalendarKey = "timeBlockCalendarID"
    private let backupBeforeSyncKey = "backUpBeforeSync"
    private let lastBackupDayKey = "lastBackupDay"
    private var securityScopedURL: URL?
    private var autoSyncTask: Task<Void, Never>?

    private var publishWatch: AnyCancellable?

    /// Set by the note editor while a note is open: writes any unsaved text now. Called before
    /// every change the model makes to notes, before a sync, and when the app quits, so the
    /// editor's text and the model's copy never overwrite each other.
    var flushEditor: (() -> Void)?
    private var externalChangeTask: Task<Void, Never>?
    private var vaultSignature: String?
    private var terminationObserver: NSObjectProtocol?

    /// Tells the app when iCloud has brought a file down, so notes appear as they arrive
    /// instead of being found by the next poll.
    private let cloudWatcher = CloudWatcher()

    /// A short in-memory log of what the app did, for Help \u{203A} Copy Diagnostics.
    /// Not published: the publish watcher below appends to it.
    private(set) var diagnostics: [String] = []

    init() {
        log("launch build \(BuildStamp.number)")
        // Before the vault is opened: opening it is what starts the watch.
        cloudWatcher.onChange = { [weak self] in self?.cloudFilesChanged() }
        restoreVault()
        fetchCloudFiles(force: true)
        #if os(macOS)
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.flushPendingEdits() }
        }
        #endif
        watchForExternalChanges()
        backUpDaily()
        purgeOldDeleted()
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

    /// Whether a copy of the vault is saved before each sync (on by default).
    var backsUpBeforeSync: Bool {
        get { defaults.object(forKey: backupBeforeSyncKey) as? Bool ?? true }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: backupBeforeSyncKey)
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
        // Work notes are not in `notes` — that is what keeps them out of Today, the Map, the
        // search and Reminders — but the editor and the row actions look a note up by path,
        // so they are found here and nowhere else.
        return notes.first { $0.relativePath == path } ?? workNotes.first { $0.relativePath == path }
    }

    // MARK: Work notes

    /// Notes in the vault's Work folder: a separate set, deliberately outside everything else.
    @Published private(set) var workNotes: [Note] = []
    /// Whether the Work row is in the sidebar. Not stored anywhere: it goes when the app does.
    @Published var workRevealed = false
    func refreshWorkNotes() {
        workNotes = vault?.workNotes() ?? []
    }

    /// The hidden way in: a long press, or the keyboard shortcut. Reveals the row and goes there.
    func revealWork() {
        refreshWorkNotes()
        workRevealed = true
        show(section: .work, notePath: nil)
    }

    /// Puts it away again. The notes stay where they are; only the row goes.
    func hideWork() {
        workRevealed = false
        forgetWorkVisits()
        if section == .work { show(section: .inbox, notePath: nil) }
    }

    /// A work note by title, but only from inside another work note: the two sets do not see
    /// each other, which is the whole point of the Work section.
    func workNote(titled title: String, near note: Note) -> Note? {
        guard isWorkNote(note) else { return nil }
        return workNotes.first { $0.displayTitle.localizedCaseInsensitiveCompare(title) == .orderedSame }
    }

    // MARK: [[links]]

    /// The titles `[[` offers in a given note. A work note is offered its own set; every other
    /// note is offered the ordinary vault, so nothing leaks either way.
    func linkableTitles(from path: String) -> [String] {
        let here = note(at: path)
        let pool = (here.map(isWorkNote) ?? false) ? workNotes : notes
        return pool.filter { $0.relativePath != path && $0.kind != .inbox }.map(\.displayTitle)
    }

    /// Opens the note a `[[link]]` names. Says so plainly when there is no such note yet.
    func openWikiLink(_ title: String, from path: String) {
        guard let here = note(at: path) else { return }
        if let target = workNote(titled: title, near: here) ?? index.note(matching: title) {
            show(target)
        } else {
            // Never offer to make a note that may already exist and simply has not come
            // down from iCloud yet: that is how you end up with two of it (build 100).
            guard notesWaitingForCloud.isEmpty else {
                flash("Not found \u{2014} but \(notesWaitingForCloud.count) notes are still coming from iCloud")
                return
            }
            // The click can land inside a SwiftUI update (build 116), so the sheet is asked
            // for after the update rather than in the middle of one.
            afterUpdate {
                self.linkToCreate = LinkToCreate(title: title, fromPath: path, isWork: self.isWorkNote(here))
                self.activeSheet = .noteFromLink
            }
        }
    }

    /// The notes pointing at this one: through `goal`/`area`/`parent`/`related`, and through
    /// `[[links]]` in their text. Work notes are looked up among work notes only.
    func backlinks(to note: Note) -> [Note] {
        let title = note.displayTitle
        if isWorkNote(note) {
            return workNotes.filter { candidate in
                candidate.relativePath != note.relativePath
                    && WikiLinks.titles(in: candidate.text).contains { $0.localizedCaseInsensitiveCompare(title) == .orderedSame }
            }
        }
        var result = index.backlinks(to: note)
        for candidate in notes where !result.contains(where: { $0.relativePath == candidate.relativePath }) {
            guard candidate.relativePath != note.relativePath,
                  WikiLinks.titles(in: candidate.text).contains(where: { $0.localizedCaseInsensitiveCompare(title) == .orderedSame })
            else { continue }
            result.append(candidate)
        }
        return result
    }

    // MARK: Where you have been

    /// One place the app has been: a note, and the section it was shown in. Both, because
    /// coming back to a note in the wrong list would leave the middle column pointing
    /// somewhere else.
    struct Visit: Equatable {
        let section: SidebarSection?
        let path: String
    }

    /// The notes behind and ahead of the one on screen. Published so the Back and Forward
    /// buttons know whether there is anywhere to go.
    @Published private(set) var backStack: [Visit] = []
    @Published private(set) var forwardStack: [Visit] = []
    /// Where we are, as far as the history is concerned.
    private var currentVisit: Visit?
    /// The one arrival a Back or Forward is about to cause, so it is not filed as a new
    /// place visited — which would push what we just left back on and never move. It is
    /// dropped again a few turns later whatever happens: a guard that outlives its move
    /// would swallow the next note opened by hand.
    private var expectedVisit: String?
    private var expectedVisitToken = 0
    /// Enough to get back through an afternoon's reading without growing without bound.
    private static let historyLimit = 60

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// Forgets where we have been. Called when the vault changes: the same relative path
    /// means a different note in a different vault, and Back must not walk into it.
    func clearHistory() {
        if !backStack.isEmpty { backStack = [] }
        if !forwardStack.isEmpty { forwardStack = [] }
        currentVisit = nil
        expectedVisit = nil
    }

    /// Drops every work note from the history. Hiding the Work section has to mean hidden:
    /// otherwise Back or Forward would put one back on screen, and the section with it.
    private func forgetWorkVisits() {
        backStack = backStack.filter { !isWorkVisit($0) }
        forwardStack = forwardStack.filter { !isWorkVisit($0) }
        if let currentVisit, isWorkVisit(currentVisit) { self.currentVisit = nil }
    }

    private func isWorkVisit(_ visit: Visit) -> Bool {
        vault?.isWorkPath(visit.path) ?? false
    }

    /// Called for every note that is opened, however it was opened.
    private func recordVisit(_ path: String) {
        if expectedVisit == path {
            expectedVisit = nil
            return
        }
        let visit = Visit(section: section, path: path)
        // Opening the same note again (from another list, say) is not a step.
        guard visit.path != currentVisit?.path else {
            currentVisit = visit
            return
        }
        if let currentVisit { backStack.append(currentVisit) }
        if backStack.count > Self.historyLimit {
            backStack.removeFirst(backStack.count - Self.historyLimit)
        }
        currentVisit = visit
        // Going somewhere new is what ends the forward road, exactly as in a browser.
        if !forwardStack.isEmpty { forwardStack.removeAll() }
    }

    /// Back to the note you came from. Notes deleted since are stepped over rather than
    /// opened as a blank screen.
    func goBack() {
        flushPendingEdits()
        while let target = backStack.popLast() {
            // A note that is gone, or the one already on screen: neither is a step back.
            guard note(at: target.path) != nil, target.path != selectedNotePath else { continue }
            if let currentVisit { forwardStack.append(currentVisit) }
            go(to: target)
            return
        }
    }

    /// Forward again, after a Back.
    func goForward() {
        flushPendingEdits()
        while let target = forwardStack.popLast() {
            guard note(at: target.path) != nil, target.path != selectedNotePath else { continue }
            if let currentVisit { backStack.append(currentVisit) }
            go(to: target)
            return
        }
    }

    private func go(to visit: Visit) {
        currentVisit = visit
        // Only a move that will really happen needs the guard: arming it for a note already
        // on screen would leave it set, and it would eat the next genuine visit there.
        expectedVisit = selectedNotePath == visit.path ? nil : visit.path
        expectedVisitToken += 1
        let token = expectedVisitToken
        // The Inbox's own middle column clears the selection as it appears, so a note
        // remembered while that section was open is shown in the list it belongs to instead.
        let remembered = visit.section == .inbox ? note(at: visit.path).map { sidebarSection(for: $0) } : visit.section
        if let target = remembered {
            show(section: target, notePath: visit.path)
        } else {
            afterUpdate { if self.selectedNotePath != visit.path { self.selectedNotePath = visit.path } }
        }
        // Three turns is past the two `show` takes, so the guard cannot outlive its move.
        afterUpdate {
            self.afterUpdate {
                self.afterUpdate { if self.expectedVisitToken == token { self.expectedVisit = nil } }
            }
        }
    }

    // MARK: A link to a note that is not there yet

    /// A `[[link]]` that names no note, and the note it was clicked in. The sheet reads it.
    struct LinkToCreate: Equatable {
        let title: String
        let fromPath: String
        /// A work note's links make work notes; everything else makes an ordinary note.
        let isWork: Bool
    }

    @Published var linkToCreate: LinkToCreate?

    /// Makes the note a link asked for. The title is the link's own words, so the link
    /// resolves the moment the note exists.
    func createNoteFromLink(kind: ParaKind) {
        guard let request = linkToCreate else { return }
        linkToCreate = nil
        if request.isWork {
            createWorkNote(title: request.title)
        } else {
            createNote(kind: kind, title: request.title)
        }
    }

    func createWorkNote(title: String) {
        guard let vault else { return }
        do {
            let note = try vault.createWorkNote(title: title)
            refreshWorkNotes()
            show(section: .work, notePath: note.relativePath)
        } catch {
            errorMessage = error.localizedDescription
        }
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
        case .recent?: base = recentNotes
        case .deleted?, .templates?: base = []
        case .work?: base = workNotes
        case .today?, .review?, .map?, .timeBlocks?, .done?, .allActions?, .search?, nil: base = notes
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
        case .recent: return recentNotes.count
        case .deleted: return deletedNotes.count
        case .templates: return 0
        case .work: return workNotes.count
        case .allActions: return index.openTasks(includeArchived: false).count
        case .timeBlocks: return timeBlocks.filter { $0.day == .today() }.count
        case .done: return index.tasksCompleted(on: .today()).count
        case .review: return index.review(config: config).projectsNeedingAttention.count
        case .kind(let kind): return notes.filter { $0.kind == kind }.count
        }
    }

    // MARK: Vault lifecycle

    func openVault(at url: URL) {
        guard !isSyncing else {
            errorMessage = "A sync is running. Try again when it has finished."
            return
        }
        flushPendingEdits()
        // Open the new folder first; the current vault stays usable if that fails.
        let scoped = url.startAccessingSecurityScopedResource()
        let opened: Vault
        do {
            opened = try Vault(rootURL: url)
            try opened.bootstrap()
        } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            errorMessage = error.localizedDescription
            return
        }
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = scoped ? url : nil
        storeBookmark(for: url)
        selectedNotePath = nil
        clearHistory()
        vault = opened
        cloudWatcher.watch(opened.rootURL)
        reload()
        fetchCloudFiles(force: true)
        backUpDaily()
        purgeOldDeleted()
        scheduleAutoSync()
    }

    func closeVault() {
        guard !isSyncing else {
            errorMessage = "A sync is running. Try again when it has finished."
            return
        }
        flushPendingEdits()
        autoSyncTask?.cancel()
        autoSyncTask = nil
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        defaults.removeObject(forKey: bookmarkKey)
        cloudWatcher.stop()
        vault = nil
        notes = []
        selectedNotePath = nil
        clearHistory()
    }

    /// Writes the editor's unsaved text, if any.
    func flushPendingEdits() {
        flushEditor?()
    }

    // MARK: Changes made outside the app

    /// A cheap fingerprint of every note file's path and modification date.
    private func currentVaultSignature() -> String? {
        guard let vault else { return nil }
        var parts: [String] = []
        for note in notes {
            parts.append("\(note.relativePath)@\(vault.modificationDate(of: note.relativePath)?.timeIntervalSince1970 ?? 0)")
        }
        // Folder dates change when notes are added or removed. Templates is in the list so a
        // template edited on the other device is picked up too; nothing else notices it.
        for folder in [vault.config.projectsFolder, vault.config.areasFolder, vault.config.resourcesFolder,
                       vault.config.archiveFolder, vault.config.calendarFolder, vault.config.goalsFolder,
                       vault.config.templatesFolder] {
            parts.append("\(folder)/@\(vault.modificationDate(of: folder)?.timeIntervalSince1970 ?? 0)")
        }
        for name in vault.templateNames() {
            let path = "\(vault.config.templatesFolder)/\(name).md"
            parts.append("\(path)@\(vault.modificationDate(of: path)?.timeIntervalSince1970 ?? 0)")
        }
        return parts.joined(separator: "|")
    }

    // MARK: Files iCloud has not sent yet

    /// Vault files this device does not have the contents of, by relative path. A note or a
    /// template written on the Mac reaches the iPhone as a placeholder, and iCloud only
    /// fetches it when something asks: `Vault.downloadCloudFiles` is that asking, and this is
    /// what it is still waiting for.
    @Published private(set) var cloudDownloads: [String] = []
    private var lastCloudCheck: Date?

    /// Asks iCloud for everything missing. Runs on the change poll, but at most once a minute:
    /// a download takes longer than the poll's ten seconds anyway.
    ///
    /// The walk touches every file in the vault and asks iCloud about each one, which on a
    /// phone can take long enough for iOS to kill the app for not finishing its launch
    /// (build 101). So it runs off the main thread and comes back with the answer.
    func fetchCloudFiles(force: Bool = false) {
        guard let vault else { return }
        if !force, let last = lastCloudCheck, Date().timeIntervalSince(last) < 60 { return }
        lastCloudCheck = Date()
        let root = vault.rootURL
        let skipped = Vault.stateFolderName
        Task.detached(priority: .utility) { [weak self] in
            let pending = CloudFiles.downloadMissing(under: root, skipping: skipped)
            await MainActor.run { self?.cloudDownloadsFound(pending) }
        }
    }

    /// iCloud has finished with something in the vault. A note that has just come down is not
    /// a change the vault signature can see — materialising a file leaves its date alone — so a
    /// vault with anything outstanding is simply read again.
    private func cloudFilesChanged() {
        guard vault != nil, !isSyncing else { return }
        if !notesWaitingForCloud.isEmpty || !cloudDownloads.isEmpty {
            log("iCloud reported a change; re-reading the vault")
            reload()
        } else {
            checkForExternalChanges()
        }
    }

    private func cloudDownloadsFound(_ pending: [String]) {
        guard pending != cloudDownloads else { return }
        cloudDownloads = pending
        if !pending.isEmpty { log("waiting for iCloud: \(pending.joined(separator: ", "))") }
    }

    /// Notes on this device that could not be read because iCloud has not sent their contents
    /// yet. An empty list is not proof of an empty vault, and the app must say which it is.
    @Published private(set) var notesWaitingForCloud: [String] = []
    /// Notes that could not be read for some other reason: damaged, or in an encoding this
    /// app does not understand.
    @Published private(set) var unreadableNotes: [String] = []

    /// One line for the sidebar when the vault is not all here, or nil when everything is.
    var vaultWarning: String? {
        let waiting = notesWaitingForCloud.count
        let unreadable = unreadableNotes.count
        if waiting > 0, unreadable > 0 {
            return "\(waiting) note\(waiting == 1 ? "" : "s") still coming from iCloud, \(unreadable) unreadable"
        }
        if waiting > 0 {
            return "\(waiting) note\(waiting == 1 ? "" : "s") still coming from iCloud"
        }
        if unreadable > 0 {
            return "\(unreadable) note\(unreadable == 1 ? "" : "s") could not be read"
        }
        return nil
    }

    /// Asks iCloud again for whatever is missing and re-reads the vault. The button behind the
    /// warning, for when waiting has gone on long enough to want a nudge.
    func fetchMissingNotes() {
        fetchCloudFiles(force: true)
        reload()
    }

    /// The names of templates iCloud is still fetching, so the list can say so instead of
    /// looking as if they never arrived.
    var templatesFromCloud: [String] {
        guard let vault else { return [] }
        let prefix = "\(vault.config.templatesFolder)/"
        return cloudDownloads.compactMap { path in
            guard path.hasPrefix(prefix), path.hasSuffix(".md") else { return nil }
            return String(path.dropFirst(prefix.count).dropLast(3))
        }
    }

    /// Reloads when files changed on disk (iCloud, the iPhone, another editor), checking every
    /// few seconds. A dirty editor keeps its text; its save then meets the conflict check.
    func checkForExternalChanges() {
        guard vault != nil, !isSyncing else { return }
        fetchCloudFiles()
        // Notes still coming from iCloud need another look even though nothing on disk has
        // changed: materialising a file does not change its date, so the signature below would
        // never notice them arriving (build 102).
        if !notesWaitingForCloud.isEmpty {
            reload()
            return
        }
        let signature = currentVaultSignature()
        if vaultSignature == nil { vaultSignature = signature; return }
        guard signature != vaultSignature else { return }
        log("files changed outside the app; reloading")
        reload()
    }

    private func watchForExternalChanges() {
        externalChangeTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                self?.checkForExternalChanges()
            }
        }
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
            cloudWatcher.watch(vault.rootURL)
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
            unreadableNotes = vault.skippedFiles
            notesWaitingForCloud = vault.notesWaitingForCloud
            if !unreadableNotes.isEmpty { log("skipped unreadable files: \(unreadableNotes)") }
            if !notesWaitingForCloud.isEmpty { log("waiting for iCloud: \(notesWaitingForCloud.count) notes") }
        } catch {
            errorMessage = error.localizedDescription
        }
        vaultSignature = currentVaultSignature()
        refreshDeleted()
        refreshSnippets()
        refreshWorkNotes()
    }

    // MARK: Editing

    /// Saves a change made from the app (a task ticked, a status set). Returns false when the
    /// file changed on disk meanwhile: the notes are reloaded and the change has to be redone.
    @discardableResult
    func save(_ note: Note) -> Bool {
        guard let vault else { return false }
        do {
            let saved = try vault.save(note)
            if let i = notes.firstIndex(where: { $0.relativePath == note.relativePath }) {
                notes[i] = saved
            } else if let i = workNotes.firstIndex(where: { $0.relativePath == note.relativePath }) {
                workNotes[i] = saved
            } else {
                reload()
            }
            vaultSignature = currentVaultSignature()
            return true
        } catch VaultError.modifiedOnDisk {
            log("save refused, changed on disk: \(note.relativePath)")
            reload()
            errorMessage = "\"\(note.displayTitle)\" was changed outside the app, so it was reloaded. Please make your change again."
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Saves the editor's text. If the file changed on disk meanwhile, the editor's version is
    /// kept as a conflict copy next to it and the fresh file is shown, so nothing is lost.
    func saveText(_ text: String, forNoteAt path: String) {
        guard let vault, var note = note(at: path), note.text != text else { return }
        note.text = text
        note.modifiedAt = note.modifiedAt ?? Date()
        do {
            let saved = try vault.save(note)
            if let i = notes.firstIndex(where: { $0.relativePath == path }) {
                notes[i] = saved
            } else if let i = workNotes.firstIndex(where: { $0.relativePath == path }) {
                workNotes[i] = saved
            } else {
                reload()
            }
            vaultSignature = currentVaultSignature()
        } catch VaultError.modifiedOnDisk {
            do {
                let copy = try vault.saveConflictCopy(of: note)
                log("conflict copy written: \(copy.relativePath)")
                reload()
                errorMessage = "\"\(note.displayTitle)\" was changed outside the app while you were editing it. Your version is saved as \"\(copy.displayTitle)\" next to it; the note now shows the other version."
            } catch {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createNote(kind: ParaKind, title: String, extraFrontmatter: [(String, String)] = [],
                    template: String? = nil) {
        guard let vault else { return }
        do {
            let note = try vault.createNote(kind: kind, title: title, extraFrontmatter: extraFrontmatter,
                                            template: template)
            reload()
            show(section: .kind(kind), notePath: note.relativePath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Renames a note and follows every link to it: `goal:`, `area:`, `parent:`, `related:`
    /// and `[[wikilinks]]` elsewhere are pointed at the new title, so nothing comes loose.
    /// The Reminders list follows on the next sync, which matches lists by their link.
    func renameNote(_ note: Note, to title: String) {
        flushPendingEdits()
        guard let vault else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldTitle = note.displayTitle
        guard !clean.isEmpty, clean != oldTitle else { return }
        // A rename can touch every note in the vault, so there is a copy to fall back on.
        _ = backUp(reason: "rename")
        do {
            let result = try vault.rename(note, to: clean, updating: notes)
            reload()
            if selectedNotePath == note.relativePath { selectedNotePath = result.renamed.relativePath }
            if result.staleLinks.isEmpty {
                log("renamed \(note.relativePath) -> \(result.renamed.relativePath)")
            } else {
                // Saying nothing would leave links pointing at a title that no longer exists.
                log("renamed \(note.relativePath); still naming the old title: \(result.staleLinks)")
                errorMessage = staleLinkMessage(count: result.staleLinks.count, oldTitle: oldTitle, newTitle: clean)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Told to the user when a rename could not reach every note that named the old title.
    private func staleLinkMessage(count: Int, oldTitle: String, newTitle: String) -> String {
        let notes = count == 1 ? "One note" : "\(count) notes"
        return "\(notes) could not be written, so they still say \u{201C}\(oldTitle)\u{201D} instead of "
             + "\u{201C}\(newTitle)\u{201D}. Search for the old name to put them right."
    }

    func archive(_ note: Note) {
        flushPendingEdits()
        guard let vault else { return }
        do {
            let archived = try vault.archive(note)
            reload()
            if selectedNotePath == note.relativePath { selectedNotePath = archived.relativePath }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes a note: it moves to the vault's Deleted list, where it can be put back.
    /// The Inbox note stays; empty it instead.
    func trash(_ note: Note) {
        flushPendingEdits()
        guard let vault, note.kind != .inbox else { return }
        do {
            try vault.trash(note)
            log("deleted \(note.relativePath)")
            if selectedNotePath == note.relativePath { selectedNotePath = nil }
            reload()
            flash("\u{201C}\(note.displayTitle)\u{201D} is in Deleted")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Deleted notes

    /// What is in the Deleted list, most recently deleted first.
    @Published private(set) var deletedNotes: [DeletedNote] = []

    func refreshDeleted() {
        deletedNotes = vault?.deletedNotes() ?? []
    }

    /// Clears out what has been deleted for more than a month. Runs at launch and on open.
    func purgeOldDeleted() {
        vault?.purgeDeleted(olderThan: Self.deletedKeptForDays)
        refreshDeleted()
    }

    static let deletedKeptForDays = 30

    func putBack(_ deleted: DeletedNote) {
        guard let vault else { return }
        do {
            let restored = try vault.restore(deleted)
            reload()
            flash("\u{201C}\(restored.displayTitle)\u{201D} is back")
            show(restored)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteForGood(_ deleted: DeletedNote) {
        guard let vault else { return }
        do {
            try vault.purge(deleted)
            refreshDeleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func emptyDeleted() {
        guard let vault else { return }
        for deleted in deletedNotes { try? vault.purge(deleted) }
        refreshDeleted()
    }

    /// Notes that can be archived: the working PARA kinds and goals.
    func canArchive(_ note: Note) -> Bool {
        // Never a work note: archiving would move it into the Archive folder, which is part of
        // the vault everything else can see.
        guard !isWorkNote(note) else { return false }
        return [.project, .area, .resource, .goal].contains(note.kind)
    }

    /// True for a note living in the Work folder.
    func isWorkNote(_ note: Note) -> Bool {
        vault?.isWorkPath(note.relativePath) ?? false
    }

    func toggle(_ ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath) else { return }
        if ref.task.isDone {
            var task = ref.task
            task.markOpen()
            note.replace(task: task)
        } else if let next = note.complete(task: ref.task) {
            flash("Done. Next time: \(next.dueDate?.description ?? "")")
        }
        save(note)
    }

    /// Finds a dragged task again in its note (by line, then by title).
    func task(for transfer: TaskTransfer) -> TaskRef? {
        guard transfer.isNote != true, let note = note(at: transfer.notePath) else { return nil }
        let task = note.tasks.first { $0.lineIndex == transfer.lineIndex && $0.title == transfer.title }
            ?? note.tasks.first { $0.title == transfer.title }
        return task.map { TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: $0) }
    }

    func setDueDate(_ ref: TaskRef, _ date: DateOnly?) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath) else { return }
        var task = ref.task
        task.dueDate = date
        if date == nil { task.dueTime = nil }
        guard note.replace(task: task) else { return }
        save(note)
    }

    func setRepeat(_ ref: TaskRef, _ rule: RepeatRule?) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath) else { return }
        var task = ref.task
        task.repeatRule = rule
        guard note.replace(task: task) else { return }
        save(note)
    }

    func makeNextAction(_ ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath), note.setNextAction(ref.task) else { return }
        save(note)
    }

    func clearNextAction(_ ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath) else { return }
        var task = ref.task
        task.title = Note.removingTag(Note.nextActionTag, from: task.title)
        guard note.replace(task: task) else { return }
        save(note)
    }

    /// Moves a task (with its subtasks) to another note. Its id travels with it, so the
    /// reminder follows on the next sync.
    func moveTask(_ ref: TaskRef, to path: String) {
        guard path != ref.notePath else { return }
        flushPendingEdits()
        guard let vault, let source = note(at: ref.notePath), let target = note(at: path) else { return }
        do {
            // The target is written first, so a failure can leave the task in two places but
            // never in none. See Vault.move.
            let move = try vault.move(task: ref.task, from: source, to: target)
            reload()
            log("moved task \"\(ref.task.title)\" \(ref.notePath) -> \(path)")
            if move.leftInSource {
                errorMessage = "\u{201C}\(ref.task.title)\u{201D} was added to \(move.target.displayTitle), but "
                    + "\(source.displayTitle) changed at the same moment and still has it. Delete the one you do not want."
            } else {
                flash("Moved to \(move.target.displayTitle)")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Opens the Time Blocks section with a block prepared for this task.
    func blockTime(for ref: TaskRef) {
        let title = Note.removingTag(Note.nextActionTag, from: ref.task.title)
        var lines = ["From \(ref.noteTitle)"]
        if let encoded = ref.noteTitle.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
            lines.append("amspara://\(encoded)")
        }
        timeBlockDraft = TimeBlockDraft(title: title, notes: lines.joined(separator: "\n"))
        show(section: .timeBlocks, notePath: nil)
    }

    func addTask(_ title: String, to path: String) {
        flushPendingEdits()
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var note = note(at: path) else { return }
        note.append(task: TaskParser.normalized(TaskItem(title: trimmed)))
        save(note)
    }

    func addSubtask(_ title: String, to parent: TaskRef) {
        flushPendingEdits()
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var note = note(at: parent.notePath) else { return }
        note.appendSubtask(TaskParser.normalized(TaskItem(title: trimmed)), to: parent.task)
        save(note)
    }

    /// Renames a task in place, keeping its id, date, tags and subtasks.
    func renameTask(_ ref: TaskRef, to title: String) {
        flushPendingEdits()
        var trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // The #next marker lives in the title but is shown as a badge, so it is never in the
        // field being edited. Put it back rather than let a rename clear the next action.
        if ref.task.tags.contains(Note.nextActionTag),
           !trimmed.localizedCaseInsensitiveContains("#" + Note.nextActionTag) {
            trimmed += " #" + Note.nextActionTag
        }
        guard trimmed != ref.task.title, var note = note(at: ref.notePath) else { return }
        var task = ref.task
        task.title = trimmed
        guard note.replace(task: task) else { return }
        _ = save(note)
    }

    /// Removes a task and everything indented under it.
    func deleteTask(_ ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath), note.removeTaskBlock(for: ref.task) != nil else { return }
        if save(note) {
            log("deleted task \"\(ref.task.title)\" from \(ref.notePath)")
            flash("Deleted \u{201C}\(ref.task.title)\u{201D}")
        }
    }

    /// Turns a captured line into a note of its own and takes it out of the list it came from.
    func makeNote(from ref: TaskRef, kind: ParaKind) {
        flushPendingEdits()
        let title = Note.removingTag(Note.nextActionTag, from: ref.task.title)
        guard let vault, var source = note(at: ref.notePath) else { return }
        // The note is made first. If the title is already taken, or the write fails, the line
        // is still in the list it came from; the other order would lose it.
        let made: Note
        do {
            made = try vault.createNote(kind: kind, title: title)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        if source.removeTaskBlock(for: ref.task) != nil { _ = save(source) }
        reload()
        show(section: .kind(kind), notePath: made.relativePath)
    }

    /// Writes `order:` into the notes of one kind so the list keeps the arrangement.
    /// Numbered in tens, so a note dropped between two others still fits.
    func reorder(_ kind: ParaKind, from source: IndexSet, to destination: Int) {
        reorder(notes.filter { $0.kind == kind }, from: source, to: destination)
    }

    /// The same for one row of a nested list: sub-areas are numbered among themselves,
    /// so arranging a family never disturbs the areas around it.
    func reorder(_ listed: [Note], from source: IndexSet, to destination: Int) {
        flushPendingEdits()
        guard let vault else { return }
        var listed = listed
        listed.move(fromOffsets: source, toOffset: destination)
        var wanted: [String: Int] = [:]
        for (index, note) in listed.enumerated() where note.sortOrder != (index + 1) * 10 {
            wanted[note.relativePath] = (index + 1) * 10
        }
        let result = vault.saveEach(listed) { note in
            guard let order = wanted[note.relativePath] else { return nil }
            var updated = note
            updated.frontmatter.set("order", "\(order)")
            return updated
        }
        reload()
        // One message for the lot: a failed save used to raise its own, so a shaky folder
        // meant a stack of identical alerts.
        if !result.isComplete {
            log("could not renumber: \(result.failed)")
            errorMessage = result.failed.count == 1
                ? "One note could not be written, so the order is not quite as you left it."
                : "\(result.failed.count) notes could not be written, so the order is not quite as you left it."
        }
    }

    // MARK: Templates and snippets

    /// The blocks of task lines from `Templates/Snippets.md`.
    @Published private(set) var snippets: [Snippet] = []
    /// Which template the Templates section is showing, shared by its two columns.
    @Published var templateSelection: String?

    /// Every template file with the kind of note it makes.
    @Published private(set) var templates: [TemplateFile] = []

    var templateNames: [String] { templates.map(\.name) }

    /// The templates that make one kind of note, the default first.
    func templates(for kind: ParaKind) -> [TemplateFile] {
        vault?.templates(for: kind) ?? []
    }

    func createTemplate(named name: String, kind: ParaKind) {
        guard let vault else { return }
        do {
            let made = try vault.createTemplate(named: name, kind: kind)
            refreshSnippets()
            templateSelection = made.name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameTemplate(named name: String, to newName: String) {
        guard let vault else { return }
        do {
            try vault.renameTemplate(named: name, to: newName)
            refreshSnippets()
            if templateSelection == name {
                templateSelection = Vault.sanitizeFileName(newName.trimmingCharacters(in: .whitespaces))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTemplate(named name: String) {
        guard let vault else { return }
        do {
            try vault.deleteTemplate(named: name)
            refreshSnippets()
            if templateSelection == name { templateSelection = templates.first?.name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func templateText(named name: String) -> String {
        vault?.templateText(named: name) ?? ""
    }

    /// `announce` is off while typing is being saved in the background, so the message is
    /// kept for the times you asked for it.
    func saveTemplate(named name: String, text: String, announce: Bool = true) {
        guard let vault else { return }
        do {
            try vault.saveTemplate(named: name, text: text)
            refreshSnippets()
            if announce { flash("Saved the \(name) template") }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshSnippets() {
        snippets = vault?.snippets() ?? []
        templates = vault?.templates() ?? []
    }

    /// Drops a snippet's lines into a note's Tasks, dates and answers filled in.
    func insert(_ snippet: Snippet, answers: [String: String], into path: String) {
        flushPendingEdits()
        guard var note = note(at: path) else { return }
        let lines = Snippets.filled(snippet, answers: answers)
        guard !lines.isEmpty else { return }
        note.appendTaskBlock(lines)
        guard save(note) else { return }
        flash("Added \u{201C}\(snippet.name)\u{201D}")
    }

    // MARK: The map's hand-placed boxes

    /// Where boxes have been parked, by note path. Unzoomed points from the top left.
    var pinnedMapPositions: [String: CGPoint] {
        var pinned: [String: CGPoint] = [:]
        for note in notes {
            guard let point = note.mapPosition else { continue }
            pinned[note.relativePath] = CGPoint(x: point.x, y: point.y)
        }
        return pinned
    }

    /// Parks a box, or takes the `map:` line out so the app places it again.
    func setMapPosition(_ note: Note, to point: CGPoint?) {
        flushPendingEdits()
        guard var updated = self.note(at: note.relativePath) else { return }
        if let point {
            updated.frontmatter.set("map", "\(Int(point.x.rounded())),\(Int(point.y.rounded()))")
        } else {
            guard updated.mapPosition != nil else { return }
            updated.frontmatter.remove("map")
        }
        guard save(updated) else { return }
        reload()
    }

    /// Hands the whole map back to the automatic layout.
    func clearMapPositions() {
        flushPendingEdits()
        for note in notes where note.mapPosition != nil {
            guard var updated = self.note(at: note.relativePath) else { continue }
            updated.frontmatter.remove("map")
            _ = save(updated)
        }
        reload()
    }

    /// Points a note at the goal it serves (`goal:`), or clears the line.
    func setGoal(_ note: Note, to goal: Note?) {
        setLink("goal", on: note, to: goal)
    }

    /// Puts a project in an area (`area:`), or takes it out.
    func setArea(_ note: Note, to area: Note?) {
        setLink("area", on: note, to: area)
    }

    private func setLink(_ key: String, on note: Note, to target: Note?) {
        flushPendingEdits()
        guard var updated = self.note(at: note.relativePath),
              target?.relativePath != note.relativePath else { return }
        if let target {
            updated.frontmatter.set(key, target.displayTitle)
        } else {
            updated.frontmatter.remove(key)
        }
        guard save(updated) else { return }
        reload()
    }

    /// Puts an area under another one, or takes it back out with nil.
    /// Areas only, one level: the note that becomes a parent loses any parent of its own.
    func setParent(_ note: Note, to parent: Note?) {
        flushPendingEdits()
        guard note.kind == .area, var updated = self.note(at: note.relativePath) else { return }
        if let parent {
            guard parent.kind == .area, parent.relativePath != note.relativePath else { return }
            updated.frontmatter.set("parent", parent.displayTitle)
            if var lifted = self.note(at: parent.relativePath), lifted.parent != nil {
                lifted.frontmatter.remove("parent")
                _ = save(lifted)
            }
        } else {
            updated.frontmatter.remove("parent")
        }
        guard save(updated) else { return }
        reload()
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
        // Preview and the editor must answer a link the same way: follow it, or offer to
        // make the note. Until build 118 this branch made a Resource without asking.
        if let path = selectedNotePath {
            openWikiLink(reference, from: path)
        } else if let target = index.note(matching: reference) {
            show(target)
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
        flushPendingEdits()
        do {
            let note = try vault.capture(item)
            reload()
            lastCaptureMessage = "Saved to \(note.displayTitle)"
        } catch {
            // Keep it for later rather than lose it.
            try? CaptureOutbox(fileURL: Self.outboxURL).append(item)
            errorMessage = "Could not file the capture now (\(error.localizedDescription)). It is kept and will be filed later."
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
        let outbox = CaptureOutbox(fileURL: Self.outboxURL)
        let items = outbox.drain()
        guard !items.isEmpty else { return 0 }
        flushPendingEdits()
        var filed = 0
        var failed: [CaptureItem] = []
        for item in items {
            do {
                try vault.capture(item)
                filed += 1
            } catch {
                log("capture kept for later: \(error.localizedDescription)")
                failed.append(item)
            }
        }
        // Anything that could not be filed (folder not downloaded yet, no permission) goes back.
        outbox.requeue(failed)
        reload()
        lastCaptureMessage = failed.isEmpty
            ? "\(filed) captured item\(filed == 1 ? "" : "s") filed"
            : "\(filed) filed, \(failed.count) kept for later"
        return filed
    }

    /// Handles `amspara://capture?...` and `amspara://<note title>` links.
    func handle(url: URL) {
        if let item = CaptureItem(url: url) {
            capture(item)
            return
        }
        // `amspara://<note title>` opens an existing note; unknown titles go to search rather
        // than creating a note from a link someone else made.
        if url.scheme?.lowercased() == CaptureItem.urlScheme, let host = url.host?.removingPercentEncoding,
           !host.isEmpty, host.lowercased() != "capture", host.lowercased() != "timeblock" {
            if let target = index.note(matching: host) {
                show(target)
            } else {
                queryText = host
                show(section: .search, notePath: nil)
            }
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
        flushPendingEdits()
        var updated = note
        updated.frontmatter.set("status", status)
        save(updated)
    }

    func markReviewed(_ note: Note) {
        flushPendingEdits()
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

    // MARK: Backups

    func refreshBackups() {
        backups = vault?.backups() ?? []
    }

    /// Saves a copy unless the vault is unchanged since the last one. Returns what was saved.
    @discardableResult
    func backUp(reason: String) -> VaultBackup? {
        guard let vault else { return nil }
        flushPendingEdits()
        // A file iCloud has not sent is a file that cannot be copied, and a backup missing
        // notes without saying so is worse than none.
        fetchCloudFiles()
        do {
            let made = try vault.makeBackup(reason: reason)
            if let made { log("backup saved: \(made.folderName)") }
            refreshBackups()
            return made
        } catch {
            log("backup failed: \(error.localizedDescription)")
            errorMessage = "The backup could not be saved: \(error.localizedDescription)"
            return nil
        }
    }

    func backUpNow() {
        if let made = backUp(reason: "manual") {
            flash("Backup saved: \(made.noteCount) note\(made.noteCount == 1 ? "" : "s")")
        } else {
            flash("Nothing changed since the last backup")
        }
    }

    /// One copy a day, made at launch and when a vault is opened.
    private func backUpDaily() {
        guard vault != nil else { return }
        let today = DateOnly.today().description
        guard defaults.string(forKey: lastBackupDayKey) != today else {
            refreshBackups()
            return
        }
        backUp(reason: "daily")
        defaults.set(today, forKey: lastBackupDayKey)
    }

    func restore(_ backup: VaultBackup) {
        guard let vault else { return }
        flushPendingEdits()
        do {
            let result = try vault.restore(backup)
            log("restored \(backup.folderName): \(result.written) files, \(result.failed.count) not written")
            selectedNotePath = nil
            reload()
            refreshBackups()
            if result.isComplete {
                flash("Restored \(result.written) file\(result.written == 1 ? "" : "s") from \(backup.folderName)")
            } else {
                // The rest of the vault is restored; these files are still as they were.
                errorMessage = "Restored \(result.written) of \(result.written + result.failed.count) files. "
                    + "\(result.failed.count) could not be written and still hold what they held before: "
                    + result.failed.prefix(5).joined(separator: ", ")
            }
        } catch {
            errorMessage = "The backup could not be restored: \(error.localizedDescription)"
        }
    }

    func showBackupsInFinder() {
        #if os(macOS)
        guard let vault else { return }
        try? FileManager.default.createDirectory(at: vault.backupsURL, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([vault.backupsURL])
        #endif
    }

    // MARK: Sync

    /// Rehearses a sync on a copy of the vault and a copy of Reminders, so the report shows
    /// exactly what a real sync would do without changing anything.
    func previewSync() async {
        guard let vault, !isSyncing else { return }
        flushPendingEdits()
        isSyncing = true
        defer { isSyncing = false }
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("ams-para-preview-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        do {
            guard try await remindersStore.requestAccess() else {
                errorMessage = "AMS PARA needs full access to Reminders. You can grant it in System Settings › Privacy & Security › Reminders."
                return
            }
            try vault.copyContents(to: temporary)
            let rehearsal = try Vault(rootURL: temporary)
            let store = InMemoryRemindersStore()
            let lists = try await remindersStore.listNames()
            var records: [ReminderRecord] = []
            for list in lists { records += try await remindersStore.reminders(inList: list) }
            store.seed(lists: lists, records: records)
            let engine = SyncEngine(vault: rehearsal, store: store, deviceID: deviceID, config: vault.config)
            let report = try await engine.run()
            reportToShow = report
            reportIsPreview = true
            activeSheet = .syncReport
            log("sync preview: \(report.summary)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showLastReport() {
        guard let lastReport else { return }
        reportToShow = lastReport
        reportIsPreview = false
        activeSheet = .syncReport
    }

    func syncNow(force: Bool = false) async {
        guard let vault, !isSyncing else { return }
        // Never sync half a vault. A note that has not arrived from iCloud has no tasks as far
        // as this device can see, and while the engine is careful never to delete a reminder
        // whose note it could not read, a sync in that state is needless risk and produces a
        // report full of warnings. Wait until the vault is all here (build 106).
        if !force, !notesWaitingForCloud.isEmpty {
            let count = notesWaitingForCloud.count
            errorMessage = "\(count) note\(count == 1 ? " is" : "s are") still coming from iCloud, so the sync "
                + "was not started: it would only see part of your vault. Try again in a moment."
            log("sync refused: \(count) notes waiting for iCloud")
            return
        }
        flushPendingEdits()
        if backsUpBeforeSync { backUp(reason: "sync") }
        isSyncing = true
        defer { isSyncing = false }
        do {
            guard try await remindersStore.requestAccess() else {
                errorMessage = "AMS PARA needs full access to Reminders. You can grant it in System Settings › Privacy & Security › Reminders."
                return
            }
            let engine = SyncEngine(vault: vault, store: remindersStore, deviceID: deviceID)
            let report = try await engine.run()
            guard self.vault === vault else { return }
            lastReport = report
            for warning in report.warnings { log("sync: \(warning)") }
            reload()
        } catch {
            errorMessage = error.localizedDescription
            if self.vault === vault { reload() }
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
