import Foundation
import SwiftUI
import Combine
import AMSParaCore

enum SidebarSection: Hashable, Identifiable {
    case inbox
    case today
    case kind(ParaKind)

    var id: String { title }

    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .kind(let kind): return kind.displayName
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: return "tray"
        case .today: return "sun.max"
        case .kind(.project): return "flag"
        case .kind(.area): return "circle.grid.2x2"
        case .kind(.resource): return "books.vertical"
        case .kind(.archive): return "archivebox"
        case .kind(.inbox): return "tray"
        }
    }

    static let all: [SidebarSection] = [.inbox, .today, .kind(.project), .kind(.area), .kind(.resource), .kind(.archive)]
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var vault: Vault?
    @Published private(set) var notes: [Note] = []
    @Published var section: SidebarSection? = .inbox
    @Published var selectedNotePath: String?
    @Published var searchText = ""
    @Published private(set) var isSyncing = false
    @Published private(set) var lastReport: SyncReport?
    @Published var errorMessage: String?
    @Published var showingNewNote = false

    let remindersStore = EventKitRemindersStore()

    private let defaults = UserDefaults.standard
    private let bookmarkKey = "vaultBookmark"
    private let deviceIDKey = "deviceID"
    private let autoSyncKey = "autoSyncMinutes"
    private var securityScopedURL: URL?
    private var autoSyncTask: Task<Void, Never>?

    init() {
        restoreVault()
    }

    // MARK: Derived state

    var index: NoteIndex { NoteIndex(notes: notes) }

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

    func notes(in section: SidebarSection?) -> [Note] {
        let base: [Note]
        switch section {
        case .inbox?: base = notes.filter { $0.kind == .inbox }
        case .kind(let kind)?: base = notes.filter { $0.kind == kind }
        case .today?, nil: base = notes
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) }
    }

    func count(for section: SidebarSection) -> Int {
        switch section {
        case .inbox: return note(at: vault?.config.inboxFile)?.openTasks.count ?? 0
        case .today: return index.openTasks(dueOnOrBefore: .today()).count
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

    func createNote(kind: ParaKind, title: String) {
        guard let vault else { return }
        do {
            let note = try vault.createNote(kind: kind, title: title)
            reload()
            section = .kind(kind)
            selectedNotePath = note.relativePath
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

    func select(_ ref: TaskRef) {
        selectedNotePath = ref.notePath
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
