import Foundation

/// Two-way sync between task lines in PARA notes and Apple Reminders lists.
///
/// Mapping: `Inbox.md` <-> the configured inbox list; every Project (and Area) note <-> a list named
/// after the note (or its `reminders-list` frontmatter key). Each task line gets a stable `^tXXXXXX` id;
/// the mirrored reminder carries `ams-para:^tXXXXXX` in its notes so links survive across devices.
public final class SyncEngine {
    public static let markerPrefix = "ams-para:"
    static let markerRegex = try! NSRegularExpression(pattern: #"ams-para:\s*\^?(t[0-9a-f]{4,12})"#)

    public let vault: Vault
    public let store: RemindersStore
    public let deviceID: String
    public var config: VaultConfig
    public var now: () -> Date = { Date() }

    public init(vault: Vault, store: RemindersStore, deviceID: String, config: VaultConfig? = nil) {
        self.vault = vault
        self.store = store
        self.deviceID = deviceID
        self.config = config ?? vault.config
    }

    // MARK: Public API

    /// Notes whose tasks are mirrored to Reminders.
    public func syncableNotes(from notes: [Note]) -> [Note] {
        notes.filter { note in
            guard note.kind.isTaskKind, note.isSyncEnabled, !note.isArchived else { return false }
            if note.kind == .area && !config.syncAreas { return false }
            if note.kind == .daily && !config.syncDailyNotes { return false }
            return true
        }
    }

    public func listName(for note: Note) -> String {
        switch note.kind {
        case .inbox: return note.frontmatter.string("reminders-list") ?? config.inboxListName
        case .daily: return note.frontmatter.string("reminders-list") ?? config.dailyNotesListName
        default: return note.remindersListName
        }
    }

    @discardableResult
    public func run() async throws -> SyncReport {
        var report = SyncReport(startedAt: now())
        var state = vault.loadSyncState(deviceID: deviceID)

        // 1. Load notes, assign ids to tasks that have none.
        let allNotes = try vault.allNotes()
        var allTaskIDs = Set(allNotes.flatMap { $0.tasks.compactMap(\.id) })
        var notesByPath: [String: Note] = [:]
        var dirtyPaths = Set<String>()
        var listForPath: [String: String] = [:]
        /// The note that receives reminders created in a list. All daily notes share one list; today's note receives.
        var pathForList: [String: String] = [:]
        let todayPath = vault.dailyNotePath(for: DateOnly(now()))

        for var note in syncableNotes(from: allNotes) {
            for var task in note.tasks where task.id == nil {
                var id = TaskItem.makeID()
                while allTaskIDs.contains(id) { id = TaskItem.makeID() }
                allTaskIDs.insert(id)
                task.id = id
                note.replace(task: task)
                report.idsAssigned += 1
                dirtyPaths.insert(note.relativePath)
            }
            let list = listName(for: note)
            if note.kind == .daily {
                if pathForList[list] == nil || note.relativePath == todayPath { pathForList[list] = note.relativePath }
            } else if let existing = pathForList[list] {
                report.warnings.append("\(note.relativePath) and \(existing) both map to the list \"\(list)\"; only \(existing) is synced.")
                continue
            } else {
                pathForList[list] = note.relativePath
            }
            listForPath[note.relativePath] = list
            notesByPath[note.relativePath] = note
        }
        if config.syncDailyNotes, pathForList[config.dailyNotesListName] == nil {
            pathForList[config.dailyNotesListName] = todayPath // fetched even before the first daily note exists
        }
        report.notesSynced = notesByPath.count

        // 2. Fetch reminders for every mapped list.
        let listNames = try await store.listNames()
        let existingLists = Set(listNames)
        var remindersByID: [String: ReminderRecord] = [:]
        var remindersByMarker: [String: ReminderRecord] = [:]
        for list in pathForList.keys.sorted() {
            if !existingLists.contains(list) {
                if config.createMissingLists {
                    try await store.ensureList(named: list)
                } else {
                    continue
                }
            }
            for record in try await store.reminders(inList: list) {
                remindersByID[record.identifier] = record
                if let marker = Self.markerTaskID(in: record.notes), remindersByMarker[marker] == nil {
                    remindersByMarker[marker] = record
                }
            }
        }

        // Index tasks by id (rebuilt after reconciliation so later steps see the current lines).
        var taskLocations: [String: (path: String, task: TaskItem)] = [:]
        func indexTasks() {
            taskLocations = [:]
            for (path, note) in notesByPath {
                for task in note.tasks {
                    if let id = task.id { taskLocations[id] = (path, task) }
                }
            }
        }
        indexTasks()

        func updateNote(_ path: String, _ mutate: (inout Note) -> Void) {
            guard var note = notesByPath[path] else { return }
            mutate(&note)
            notesByPath[path] = note
            dirtyPaths.insert(path)
        }

        var handledReminderIDs = Set<String>()

        // 3. Reconcile existing links.
        for (taskID, link) in state.links.sorted(by: { $0.key < $1.key }) {
            let location = taskLocations[taskID]
            let reminder = remindersByID[link.reminderID] ?? remindersByMarker[taskID]

            switch (location, reminder) {
            case let (location?, reminder?):
                handledReminderIDs.insert(reminder.identifier)
                let listName = listForPath[location.path] ?? link.listName
                let outcome = try await reconcile(task: location.task, at: location.path, listName: listName,
                                                  reminder: reminder, link: link, report: &report, updateNote: updateNote)
                state.links[taskID] = outcome
            case let (location?, nil):
                // Reminder deleted in Apple Reminders: cancel the task instead of deleting the user's text.
                if !location.task.isDone {
                    updateNote(location.path) { note in
                        var t = location.task
                        t.markCancelled()
                        note.replace(task: t)
                    }
                    report.tasksCancelled += 1
                }
                state.links[taskID] = nil
            case let (nil, reminder?):
                handledReminderIDs.insert(reminder.identifier)
                if allTaskIDs.contains(taskID) {
                    // The task moved to a note that is not synced (archived, sync: false). Leave the reminder alone.
                    state.links[taskID] = nil
                } else {
                    try await store.delete(identifier: reminder.identifier)
                    report.remindersDeleted += 1
                    state.links[taskID] = nil
                }
            case (nil, nil):
                state.links[taskID] = nil
            }
        }

        indexTasks()

        // 4. Tasks without a link: match by marker, else create a reminder for open tasks.
        for (taskID, location) in taskLocations.sorted(by: { $0.key < $1.key }) where state.links[taskID] == nil {
            let listName = listForPath[location.path] ?? ""
            if let reminder = remindersByMarker[taskID], !handledReminderIDs.contains(reminder.identifier) {
                handledReminderIDs.insert(reminder.identifier)
                let provisional = TaskLink(taskID: taskID, reminderID: reminder.identifier, notePath: location.path, listName: listName,
                                           lastTaskFingerprint: "", lastReminderFingerprint: "", lastSyncedAt: now())
                state.links[taskID] = try await reconcile(task: location.task, at: location.path, listName: listName,
                                                          reminder: reminder, link: provisional, report: &report, updateNote: updateNote)
                continue
            }
            guard !location.task.isDone else { continue }
            var draft = ReminderRecord(listName: listName, title: location.task.title)
            apply(task: location.task, to: &draft, listName: listName)
            let created = try await store.create(draft)
            handledReminderIDs.insert(created.identifier)
            report.remindersCreated += 1
            state.links[taskID] = TaskLink(taskID: taskID, reminderID: created.identifier, notePath: location.path, listName: listName,
                                           lastTaskFingerprint: Self.fingerprint(location.task),
                                           lastReminderFingerprint: Self.fingerprint(created), lastSyncedAt: now())
        }

        // 5. Reminders without a link: import into the note that owns the list.
        for reminder in remindersByID.values.sorted(by: { $0.identifier < $1.identifier }) where !handledReminderIDs.contains(reminder.identifier) {
            guard var path = pathForList[reminder.listName] else { continue }
            if let marker = Self.markerTaskID(in: reminder.notes) {
                if allTaskIDs.contains(marker) {
                    continue // belongs to a task in a note that is not synced right now
                }
                try await store.delete(identifier: reminder.identifier)
                report.remindersDeleted += 1
                continue
            }
            if reminder.isCompleted && !config.importCompletedReminders { continue }

            if config.syncDailyNotes, reminder.listName == config.dailyNotesListName {
                // Reminders added to the daily list belong in today's note, created on demand.
                if notesByPath[todayPath] == nil {
                    notesByPath[todayPath] = try vault.dailyNote(for: DateOnly(now()))
                    listForPath[todayPath] = reminder.listName
                }
                pathForList[reminder.listName] = todayPath
                path = todayPath
            }

            var id = TaskItem.makeID()
            while allTaskIDs.contains(id) { id = TaskItem.makeID() }
            allTaskIDs.insert(id)

            var task = TaskItem(title: Self.singleLine(reminder.title), id: id)
            apply(reminder: reminder, to: &task)
            task = TaskParser.normalized(task)
            var appended = task
            updateNote(path) { note in
                appended = note.append(task: task)
            }
            report.tasksCreated += 1

            var updated = reminder
            updated.notes = Self.notes(reminder.notes, withMarkerFor: id)
            try await store.update(updated)

            state.links[id] = TaskLink(taskID: id, reminderID: reminder.identifier, notePath: path, listName: reminder.listName,
                                       lastTaskFingerprint: Self.fingerprint(appended),
                                       lastReminderFingerprint: Self.fingerprint(updated), lastSyncedAt: now())
        }

        // 6. Persist.
        for path in dirtyPaths.sorted() {
            if let note = notesByPath[path] { try vault.save(note) }
        }
        state.lastRun = now()
        try vault.save(syncState: state, deviceID: deviceID)
        report.finishedAt = now()
        return report
    }

    // MARK: Reconciliation

    private func reconcile(task: TaskItem, at path: String, listName: String, reminder: ReminderRecord, link: TaskLink,
                           report: inout SyncReport, updateNote: (String, (inout Note) -> Void) -> Void) async throws -> TaskLink {
        let taskFP = Self.fingerprint(task)
        let reminderFP = Self.fingerprint(reminder)
        let taskChanged = taskFP != link.lastTaskFingerprint
        let reminderChanged = reminderFP != link.lastReminderFingerprint
        let listChanged = reminder.listName != listName
        var newLink = link
        newLink.notePath = path
        newLink.listName = listName
        newLink.lastSyncedAt = now()

        if !taskChanged && !reminderChanged && !listChanged && Self.markerTaskID(in: reminder.notes) == task.id {
            return newLink
        }

        let noteWins: Bool
        if taskChanged && reminderChanged && taskFP != reminderFP {
            noteWins = config.conflictPolicy == .noteWins
            report.conflicts.append("\(path): \"\(task.title)\" changed in both places; kept the \(noteWins ? "note" : "reminder") version.")
        } else if taskFP == reminderFP {
            noteWins = true // same content on both sides, only refresh the marker / list
        } else {
            noteWins = taskChanged || (!reminderChanged && listChanged)
        }

        if noteWins {
            var updated = reminder
            apply(task: task, to: &updated, listName: listName)
            if updated != reminder {
                try await store.update(updated)
                report.remindersUpdated += 1
            }
            newLink.lastTaskFingerprint = taskFP
            newLink.lastReminderFingerprint = Self.fingerprint(updated)
        } else {
            var t = task
            apply(reminder: reminder, to: &t)
            t = TaskParser.normalized(t)
            updateNote(path) { note in note.replace(task: t) }
            report.tasksUpdated += 1
            var updated = reminder
            if Self.markerTaskID(in: updated.notes) != task.id || listChanged {
                updated.notes = Self.notes(updated.notes, withMarkerFor: task.id ?? "")
                updated.listName = listName
                try await store.update(updated)
            }
            newLink.lastTaskFingerprint = Self.fingerprint(t)
            newLink.lastReminderFingerprint = Self.fingerprint(updated)
        }
        return newLink
    }

    // MARK: Field mapping

    func apply(task: TaskItem, to reminder: inout ReminderRecord, listName: String) {
        reminder.listName = listName
        reminder.title = task.title.isEmpty ? "Untitled task" : task.title
        reminder.dueDate = task.dueDate
        reminder.priority = task.priority
        if task.isDone {
            if !reminder.isCompleted {
                reminder.completedAt = task.doneDate ?? now()
            }
            reminder.isCompleted = true
        } else {
            reminder.isCompleted = false
            reminder.completedAt = nil
        }
        if let id = task.id {
            reminder.notes = Self.notes(reminder.notes, withMarkerFor: id)
        }
    }

    func apply(reminder: ReminderRecord, to task: inout TaskItem) {
        task.title = Self.singleLine(reminder.title)
        task.dueDate = reminder.dueDate
        task.priority = reminder.priority
        if reminder.isCompleted && !task.isDone {
            task.markDone(at: reminder.completedAt ?? now())
        } else if !reminder.isCompleted && task.isDone {
            task.markOpen()
        }
    }

    static func singleLine(_ text: String) -> String {
        TaskParser.collapseWhitespace(text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " "))
    }

    /// The part of a task or reminder that both sides share.
    public static func fingerprint(_ task: TaskItem) -> String {
        fingerprint(title: task.title, done: task.isDone, due: task.dueDate, priority: task.priority)
    }

    public static func fingerprint(_ reminder: ReminderRecord) -> String {
        fingerprint(title: singleLine(reminder.title),
                    done: reminder.isCompleted, due: reminder.dueDate, priority: reminder.priority)
    }

    private static func fingerprint(title: String, done: Bool, due: DateOnly?, priority: Int) -> String {
        "\(TaskParser.collapseWhitespace(title))|\(done ? 1 : 0)|\(due?.description ?? "")|\(priority)"
    }

    // MARK: Marker in the reminder notes

    public static func markerTaskID(in notes: String?) -> String? {
        guard let notes else { return nil }
        let ns = notes as NSString
        guard let m = markerRegex.firstMatch(in: notes, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    public static func marker(for taskID: String) -> String {
        "\(markerPrefix)^\(taskID)"
    }

    /// Keeps the user's own notes text and makes sure exactly one marker line for `taskID` is present.
    public static func notes(_ existing: String?, withMarkerFor taskID: String) -> String {
        let keep = (existing ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.contains(markerPrefix) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return keep.isEmpty ? marker(for: taskID) : keep + "\n\n" + marker(for: taskID)
    }
}
