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
    case search
    case kind(ParaKind)

    var id: String { title }

    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .calendar: return "Calendar"
        case .review: return "Weekly review"
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

    static let all: [SidebarSection] = [.inbox, .today, .calendar, .review, .search, .kind(.goal), .kind(.project), .kind(.area), .kind(.resource), .kind(.archive)]
}

/// The sheets the main window can present.
enum AppSheet: String, Identifiable {
    case newNote
    case quickCapture
    case settings

    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var vault: Vault?
    @Published private(set) var notes: [Note] = [] {
        didSet { index = NoteIndex(notes: notes) }
    }
    /// Rebuilt whenever `notes` changes, so views never build it during a redraw.
    @Published private(set) var index = NoteIndex(notes: [])
    @Published var section: SidebarSection? = .inbox
    @Published var selectedNotePath: String?
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

    private let defaults = UserDefaults.standard
    private let bookmarkKey = "vaultBookmark"
    private let deviceIDKey = "deviceID"
    private let autoSyncKey = "autoSyncMinutes"
    private var securityScopedURL: URL?
    private var autoSyncTask: Task<Void, Never>?

    private var publishWatch: AnyCancellable?

    init() {
        restoreVault()
        #if DEBUG
        // Reports our own frames whenever a change is published while SwiftUI is mid-update,
        // which is what "Publishing changes from within view updates" complains about.
        publishWatch = objectWillChange.sink { _ in
            let frames = Thread.callStackSymbols
            guard frames.contains(where: { $0.contains("AG::") || $0.contains("AttributeGraph") || $0.contains("ViewGraph") }) else { return }
            let ours = frames.filter { $0.contains("AMSPara") }.prefix(8)
            print("AMSPARA-PUBLISH during view update:\n" + ours.joined(separator: "\n"))
        }
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
        case .today?, .review?, .search?, nil: base = notes
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) }
    }

    func count(for section: SidebarSection) -> Int {
        switch section {
        case .inbox: return note(at: vault?.config.inboxFile)?.openTasks.count ?? 0
        case .today: return index.openTasks(dueOnOrBefore: .today()).count + (todayNote?.openTasks.count ?? 0)
        case .calendar, .search: return 0
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
        let goals = notes.filter { $0.kind == .goal }
        let match = Self.goal(matching: reference, in: goals)
        #if DEBUG && os(macOS)
        reportLayout("before goal link", after: 0)
        #endif
        if let match {
            show(match)
        } else {
            show(section: .kind(.goal), notePath: nil)
            flash("No goal is called \"\(reference)\". Check the goal: line, or create it with New \u{203A} Goal.")
        }
        #if DEBUG && os(macOS)
        reportLayout("after goal link", after: 1)
        #endif
    }

    /// Finds the goal a `goal:` line points at: exact title or file name first, then
    /// either one containing the other, ignoring case and punctuation.
    static func goal(matching reference: String, in goals: [Note]) -> Note? {
        func fold(_ s: String) -> String {
            s.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " }
                .split(separator: " ").joined(separator: " ")
        }
        let wanted = fold(reference)
        guard !wanted.isEmpty else { return nil }
        let names: [(Note, [String])] = goals.map { ($0, [fold($0.title), fold($0.displayTitle), fold($0.fileName)]) }
        if let exact = names.first(where: { $0.1.contains(wanted) }) { return exact.0 }
        return names.first { $0.1.contains { !$0.isEmpty && ($0.contains(wanted) || wanted.contains($0)) } }?.0
    }

    #if DEBUG && os(macOS)
    /// Prints the window's view tree a moment later, so a layout that went wrong can be
    /// read from the console: which scroll view moved, and whether the content overflows.
    func reportLayout(_ label: String, after seconds: Double) {
        Task { @MainActor in
            if seconds > 0 { try? await Task.sleep(for: .seconds(seconds)) }
            guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
                  let content = window.contentView else { return }
            var lines = ["AMSPARA-LAYOUT \(label): window \(window.frame.size) content \(content.bounds.size) safeArea \(content.safeAreaInsets)"]
            func walk(_ view: NSView, depth: Int) {
                if depth <= 2 || view is NSScrollView {
                    var line = String(repeating: "  ", count: depth) + "\(type(of: view)) frame=\(view.frame)"
                    if let scroll = view as? NSScrollView {
                        line += " visibleOrigin=\(scroll.documentVisibleRect.origin) insets=\(scroll.contentInsets) doc=\(scroll.documentView?.frame.size ?? .zero)"
                    }
                    lines.append(line)
                }
                for sub in view.subviews { walk(sub, depth: depth + 1) }
            }
            walk(content, depth: 0)
            print(lines.joined(separator: "\n"))
        }
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
