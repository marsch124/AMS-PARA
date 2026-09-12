import SwiftUI
import UniformTypeIdentifiers
import ParagonCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var showingImporter = false

    /// iPhone (and a narrow iPad window): tabs instead of three columns.
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            if model.vault == nil {
                WelcomeView(showingImporter: $showingImporter)
                    // The folder picker lives on the welcome screen only, so it never
                    // competes with the sheet below for the same presentation slot.
                    .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.folder]) { result in
                        if case .success(let url) = result {
                            model.openVault(at: url)
                        }
                    }
            } else if isCompact {
                #if os(iOS)
                PhoneRootView()
                #endif
            } else {
                NavigationSplitView {
                    SidebarView()
                } content: {
                    NoteListView()
                } detail: {
                    DetailView()
                }
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            model.activeSheet = .quickCapture
                        } label: {
                            Label("Quick capture", systemImage: "tray.and.arrow.down")
                        }
                        .help("Capture a thought into the Inbox, today's note or a project (⇧⌘N)")
                        SyncButton()
                        #if !os(macOS)
                        Button {
                            model.activeSheet = .settings
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                        #endif
                    }
                }
            }
        }
        // One sheet modifier for the whole window: stacking several of them makes
        // SwiftUI present an empty sheet and leave the window modal.
        .sheet(item: model.sheetSelection) { sheet in
            switch sheet {
            case .newNote:
                NewNoteSheet()
                    .environmentObject(model)
            case .quickCapture:
                QuickCaptureView()
                    .environmentObject(model)
            case .syncReport:
                SyncReportView()
                    .environmentObject(model)
            case .noteFromLink:
                NoteFromLinkSheet()
                    .environmentObject(model)
            case .settings:
                NavigationStack {
                    SettingsView()
                        .environmentObject(model)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { model.activeSheet = nil }
                            }
                        }
                }
            }
        }
        .onOpenURL { url in
            model.handle(url: url)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.afterUpdate {
                    model.checkForExternalChanges()
                    model.drainOutbox()
                }
            case .inactive, .background:
                // Going to the background (or being quit on iOS): write what is being typed.
                model.flushPendingEdits()
            @unknown default:
                break
            }
        }
        .onAppear {
            model.afterUpdate { model.drainOutbox() }
            #if DEBUG
            // Lets a test open a note without hands: the phone layouts can only be checked
            // on a screen, and every route to one is a tap. Debug builds only.
            if let title = ProcessInfo.processInfo.environment["PARAGON_OPEN_NOTE"],
               let url = URL(string: "amspara://" + (title.addingPercentEncoding(
                   withAllowedCharacters: .urlHostAllowed) ?? title)) {
                model.afterUpdate { model.handle(url: url) }
            }
            #endif
        }
        .overlay(alignment: .bottom) {
            if let message = model.lastCaptureMessage {
                Text(message)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.5))
                        model.clearCaptureMessage()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.lastCaptureMessage)
        .alert("Something went wrong", isPresented: model.errorPresented) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct WelcomeView: View {
    @Binding var showingImporter: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                ForEach([ParaKind.project, .area, .resource, .archive], id: \.self) { kind in
                    RoundedRectangle(cornerRadius: 9)
                        .fill(kind.tint)
                        .frame(width: 38, height: 38)
                }
            }
            Text("PARAGON")
                .font(.largeTitle.bold())
            Text("Projects, Areas, Resources and Archive as plain markdown files, with tasks that stay in sync with Apple Reminders.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            Button("Choose a vault folder…") { showingImporter = true }
                .buttonStyle(.borderedProminent)
            Text("Pick an empty folder or an existing NotePlan style folder. The PARA folders, an Inbox note and templates are created if missing.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: model.sectionSelection) {
            Section("Actions") {
                row(.inbox)
                    .acceptsTaskDrop { ref in model.moveTask(ref, to: model.vault?.config.inboxFile ?? "Inbox.md") }
                row(.today)
                row(.allActions)
                row(.recent)
                row(.calendar)
                row(.timeBlocks)
                row(.done)
                row(.review)
                row(.map)
                row(.deleted)
                row(.templates)
                row(.search)
            }
            Section("Goals") {
                row(.kind(.goal))
            }
            Section {
                row(.kind(.project))
                row(.kind(.area))
                row(.kind(.resource))
                row(.kind(.archive))
            } header: {
                // The way in on the Mac: a long press on this heading. A Section header is not
                // a selectable row, so a gesture here takes nothing away from the list.
                Text("PARA")
                    .onLongPressGesture(minimumDuration: 1.2) { model.revealWork() }
            }
            if model.workRevealed {
                Section {
                    row(.work)
                }
            }
        }
        .navigationTitle("PARAGON")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                if let warning = model.vaultWarning {
                    VaultWarningBar(text: warning) { model.fetchMissingNotes() }
                }
                Text("Build \(BuildStamp.number)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        #endif
    }

    private func row(_ section: SidebarSection) -> some View {
        Label {
            Text(section.title)
        } icon: {
            Image(systemName: section.systemImage)
                .foregroundStyle(section.tint)
        }
        .badge(model.count(for: section))
        .tag(section)
    }
}

struct NoteListView: View {
    @EnvironmentObject private var model: AppModel
    /// Kept in the view, not the model: the toolbar search field writes to it while redrawing.
    @State private var searchText = ""
    @State private var noteToTrash: Note?
    @State private var noteToRename: Note?
    @State private var renameDraft = ""
    /// Areas folded shut by their chevron, by relative path. Sub-areas are shown by default.
    @State private var foldedAreas: Set<String> = []
    @State private var makingWorkNote = false
    @State private var workNoteTitle = ""

    private var searching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Areas are a two-level list: each area followed by its sub-areas unless it is folded.
    /// While searching, and for every other section, the plain flat list.
    private var visibleNotes: [Note] {
        let listed = model.notes(in: model.section, matching: searchText)
        guard model.section == .kind(.area), !searching else { return listed }
        return model.index.areaTree().flatMap { branch in
            foldedAreas.contains(branch.area.relativePath) ? [branch.area] : branch.all
        }
    }

    /// The areas a given area is arranged among: the top-level areas, or its parent's children.
    private func siblings(of note: Note) -> [Note] {
        guard model.section == .kind(.area), !searching else { return visibleNotes }
        guard let parent = model.index.parentArea(of: note) else {
            return model.index.areaTree().map(\.area)
        }
        return model.index.subAreas(of: parent)
    }

    /// Maps a drag in the visible list onto the row's own family, so a sub-area is arranged
    /// among its siblings and a drop that would take it out of the family is left alone.
    private func move(_ listed: [Note], from source: IndexSet, to destination: Int) {
        guard model.section == .kind(.area), !searching else {
            guard case .kind(let kind) = model.section else { return }
            model.reorder(kind, from: source, to: destination)
            return
        }
        guard let from = source.first, listed.indices.contains(from) else { return }
        let family = siblings(of: listed[from])
        guard let index = family.firstIndex(of: listed[from]) else { return }
        // `toOffset` counts positions in the family before anything is removed, which is what
        // the number of family members above the drop point gives us.
        let to = listed[0..<min(destination, listed.count)].filter { member in
            family.contains { $0.relativePath == member.relativePath }
        }.count
        model.reorder(family, from: IndexSet(integer: index), to: to)
    }

    private func fold(_ note: Note) {
        if foldedAreas.contains(note.relativePath) {
            foldedAreas.remove(note.relativePath)
        } else {
            foldedAreas.insert(note.relativePath)
        }
    }

    /// True while the Areas list is showing its two levels and this area has sub-areas.
    private func foldable(_ note: Note) -> Bool {
        model.section == .kind(.area) && !searching && !model.index.subAreas(of: note).isEmpty
    }

    private func noteRow(_ note: Note) -> some View {
        HStack(spacing: 4) {
            if foldable(note) {
                Button {
                    fold(note)
                } label: {
                    Image(systemName: foldedAreas.contains(note.relativePath) ? "chevron.right" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
                .help(foldedAreas.contains(note.relativePath) ? "Show the sub-areas" : "Hide the sub-areas")
            } else if model.section == .kind(.area), !searching {
                Spacer().frame(width: 14)
            }
            NoteRow(note: note, goalProgress: note.kind == .goal ? model.index.progress(of: note) : nil)
        }
        .padding(.leading, model.index.parentArea(of: note) == nil ? 0 : 18)
        .tag(note.relativePath)
        .acceptsTaskDrop { ref in model.moveTask(ref, to: note.relativePath) }
        .contextMenu {
            if note.kind != .inbox, note.kind != .daily {
                Button("Rename…") { startRenaming(note) }
            }
            if note.kind == .area {
                AreaParentMenu(model: model, note: note)
            }
            if note.kind == .area || note.kind == .project {
                NoteGoalMenu(model: model, note: note)
            }
            if model.canArchive(note) {
                Button("Archive") { model.archive(note) }
            }
            if note.kind != .inbox {
                Button("Move to Trash…", role: .destructive) { noteToTrash = note }
            }
        }
    }

    var body: some View {
        Group {
            if model.section == .inbox {
                // One inbox note means a list of notes would be a list of one; sort the
                // captured lines here instead.
                InboxTriageView()
            } else if model.section == .today {
                TodayView()
            } else if model.section == .calendar {
                CalendarView()
            } else if model.section == .review {
                ReviewView()
            } else if model.section == .map {
                MapView()
            } else if model.section == .timeBlocks {
                TimeBlocksView()
            } else if model.section == .done {
                DoneView()
            } else if model.section == .allActions {
                AllActionsView()
            } else if model.section == .deleted {
                DeletedView()
            } else if model.section == .templates {
                TemplatesView()
            } else if model.section == .search {
                SearchView()
            } else {
                let listed = visibleNotes
                if listed.isEmpty {
                    emptyList(searching: !searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .searchable(text: $searchText, prompt: "Search notes")
                } else {
                List(selection: model.noteSelection) {
                    ForEach(listed) { note in
                        noteRow(note)
                    }
                    // Drag a note up or down to arrange the list; the position is written into
                    // the note as `order:` so both devices agree.
                    .onMove { source, destination in
                        move(listed, from: source, to: destination)
                    }
                }
                .searchable(text: $searchText, prompt: "Search notes")
                .onChange(of: model.section) { _, _ in searchText = "" }
                .confirmationDialog("Delete \u{201C}\(noteToTrash?.displayTitle ?? "")\u{201D}?",
                                    isPresented: Binding(get: { noteToTrash != nil }, set: { if !$0 { noteToTrash = nil } }),
                                    presenting: noteToTrash) { note in
                    Button("Delete", role: .destructive) { model.trash(note) }
                } message: { _ in
                    Text("It goes to the Deleted list, where you can put it back.")
                }
                }
            }
        }
        .navigationTitle(model.section?.title ?? "Notes")
        .toolbar {
            if model.section == .recent {
                ToolbarItem {
                    Button("Clear") { model.clearRecentNotes() }
                        .help("Empty the Recent list")
                }
            }
            // Over the list it adds to, rather than away at the right by the search field.
            ToolbarItem(placement: .navigation) {
                Button {
                    if model.section == .work { makingWorkNote = true } else { model.activeSheet = .newNote }
                } label: {
                    Label("New note", systemImage: "square.and.pencil")
                }
                .help("New note in this section (⌘N)")
            }
            if model.section == .work {
                ToolbarItem {
                    Button("Hide") { model.hideWork() }
                        .help("Put the Work section away until you ask for it again")
                }
            }
        }
        .alert("New work note", isPresented: $makingWorkNote) {
            TextField("Title", text: $workNoteTitle)
            Button("Cancel", role: .cancel) { workNoteTitle = "" }
            Button("Create") {
                let title = workNoteTitle
                workNoteTitle = ""
                model.createWorkNote(title: title)
            }
        } message: {
            Text("It is kept in the vault's Work folder, out of the rest of the app.")
        }
        .alert("Rename \u{201C}\(noteToRename?.displayTitle ?? "")\u{201D}",
               isPresented: Binding(get: { noteToRename != nil }, set: { if !$0 { noteToRename = nil } })) {
            TextField("Title", text: $renameDraft)
            Button("Cancel", role: .cancel) { noteToRename = nil }
            Button("Rename") { commitRename() }
        } message: {
            Text("The file is renamed too, and every note that links to it is pointed at the new name.")
        }
        #if os(macOS)
        // The map wants room for its diagram; every other section is a list.
        .navigationSplitViewColumnWidth(min: model.section == .map ? 420 : 220, ideal: model.section == .map ? 720 : 280)
        #endif
    }

    private func startRenaming(_ note: Note) {
        renameDraft = note.displayTitle
        noteToRename = note
    }

    private func commitRename() {
        guard let note = noteToRename else { return }
        noteToRename = nil
        model.renameNote(note, to: renameDraft)
    }

    @ViewBuilder
    private func emptyList(searching: Bool) -> some View {
        if !searching, let warning = model.vaultWarning {
            // "No projects yet" in front of a vault the app cannot read is a lie, and a
            // frightening one: it looks exactly like losing everything (build 100).
            EmptyStateView(title: "Not everything is here yet",
                           systemImage: "icloud.and.arrow.down",
                           message: "\(warning). Your notes are in the vault folder; this Mac has "
                                  + "their names but not their contents yet. They appear as they arrive.",
                           tint: .orange,
                           actionTitle: "Ask iCloud again") { model.fetchMissingNotes() }
        } else if searching {
            EmptyStateView(title: "Nothing found",
                           systemImage: "magnifyingglass",
                           message: "No note in this section matches what you typed. Search Everywhere (⇧⌘F) looks inside every note and task.")
        } else {
            switch model.section {
            case .kind(.project)?:
                EmptyStateView(title: "No projects yet", systemImage: "flag",
                               message: "A project is something with an end: a race, a move, a report. Give it an outcome and a first task.",
                               tint: ParaKind.project.tint, actionTitle: "New project…") { model.activeSheet = .newNote }
            case .kind(.area)?:
                EmptyStateView(title: "No areas yet", systemImage: "circle.grid.2x2",
                               message: "An area is something you keep up over time: health, home, a client. It has no finish line.",
                               tint: ParaKind.area.tint, actionTitle: "New area…") { model.activeSheet = .newNote }
            case .kind(.resource)?:
                EmptyStateView(title: "No resources yet", systemImage: "books.vertical",
                               message: "Resources are reference material: an article, a checklist, an idea you want to keep.",
                               tint: ParaKind.resource.tint, actionTitle: "New resource…") { model.activeSheet = .newNote }
            case .kind(.goal)?:
                EmptyStateView(title: "No goals yet", systemImage: "star",
                               message: "Goals sit above everything else. Write what you want, then point projects and areas at it with a goal: line.",
                               tint: ParaKind.goal.tint, actionTitle: "New goal…") { model.activeSheet = .newNote }
            case .kind(.archive)?:
                EmptyStateView(title: "The archive is empty", systemImage: "archivebox",
                               message: "Finished projects and closed areas land here. They stay searchable and stop syncing to Reminders.",
                               tint: ParaKind.archive.tint)
            case .work?:
                EmptyStateView(title: "No work notes yet", systemImage: SidebarSection.work.systemImage,
                               message: "A separate set of notes, kept out of Today, the map, the weekly review, the main search and Reminders. Nothing here is planned or synced.",
                               tint: SidebarSection.work.tint, actionTitle: "New work note…") { makingWorkNote = true }
            case .recent?:
                EmptyStateView(title: "Nothing opened yet", systemImage: "clock.arrow.circlepath",
                               message: "The notes you open show up here, newest first, so you can get back to what you were on.")
            default:
                EmptyStateView(title: "Nothing here yet", systemImage: "doc.text",
                               message: "Notes you add to this section show up in this list.")
            }
        }
    }
}

/// The places an area can sit: nothing, or another area. Shared by the menu on a row
/// and the chip at the top of the note, so both offer exactly the same choices.
struct AreaParentOptions: View {
    /// Passed in rather than read from the environment: these choices are shown inside a
    /// context menu, whose content is built outside the row's own view hierarchy.
    @ObservedObject var model: AppModel
    let note: Note

    private var parent: Note? { model.index.parentArea(of: note) }
    private var children: [Note] { model.index.subAreas(of: note) }

    /// Every other area, its own sub-areas apart: they cannot hold their own parent.
    /// Picking one that is itself a sub-area lifts it out first, which is what asking for
    /// "Yoga under Mobility" means when Mobility sits under Health.
    private var candidates: [Note] {
        model.index.areasInFamilyOrder().filter { area in
            area.relativePath != note.relativePath &&
            !children.contains { $0.relativePath == area.relativePath }
        }
    }

    private func label(for area: Note) -> String {
        let name = model.index.parentArea(of: area).map { "\($0.displayTitle) \u{203A} \(area.displayTitle)" } ?? area.displayTitle
        return parent?.relativePath == area.relativePath ? "\u{2713} \(name)" : name
    }

    var body: some View {
        if let parent {
            Button("Open \(parent.displayTitle)") { model.show(parent) }
            Divider()
        }
        Button(parent == nil ? "\u{2713} Not part of another area" : "Not part of another area") {
            model.setParent(note, to: nil)
        }
        if !candidates.isEmpty {
            Divider()
            ForEach(candidates) { area in
                Button(label(for: area)) { model.setParent(note, to: area) }
            }
        }
    }
}

/// Which aspiration an area serves, written as `goal:`. The app has always read that line —
/// the review's "No project or area serves this" counts areas — but until build 134 the only
/// thing that could write one was dragging the area's box onto a goal on the Map. Build 74's
/// lesson: an action reachable only by an obscure gesture is an action nobody finds.
struct NoteGoalOptions: View {
    /// Passed in rather than read from the environment: context-menu content is built
    /// outside the row's own view hierarchy.
    @ObservedObject var model: AppModel
    let note: Note

    private var current: Note? { note.goal.flatMap { model.index.goal(matching: $0) } }

    private var aspirations: [Note] {
        model.notes.filter { $0.kind == .goal && $0.horizon == .life }
    }
    private var datedGoals: [Note] {
        model.notes.filter { $0.kind == .goal && $0.horizon != .life }
    }

    /// A project delivers a dated goal, so those come first for one. An area holds an
    /// aspiration, so those come first for an area. Both lists are always offered: the
    /// review already knows what to say about a dated goal only an area serves.
    private var first: [Note] { note.kind == .project ? datedGoals : aspirations }
    private var second: [Note] { note.kind == .project ? aspirations : datedGoals }

    private func label(for goal: Note) -> String {
        current?.relativePath == goal.relativePath ? "\u{2713} \(goal.displayTitle)" : goal.displayTitle
    }

    var body: some View {
        if let current {
            Button("Open \(current.displayTitle)") { model.show(current) }
            Divider()
        }
        Button(current == nil ? "\u{2713} Serves nothing" : "Serves nothing") {
            model.setGoal(note, to: nil)
        }
        if !first.isEmpty {
            Divider()
            ForEach(first) { goal in
                Button(label(for: goal)) { model.setGoal(note, to: goal) }
            }
        }
        if !second.isEmpty {
            Divider()
            ForEach(second) { goal in
                Button(label(for: goal)) { model.setGoal(note, to: goal) }
            }
        }
    }
}

/// Right-click an area in the list: which aspiration does it serve?
struct NoteGoalMenu: View {
    @ObservedObject var model: AppModel
    let note: Note

    var body: some View {
        Menu("Serves") {
            NoteGoalOptions(model: model, note: note)
        }
    }
}

/// The same choices at the top of an area note, beside "Part of\u{2026}".
struct NoteGoalChip: View {
    @ObservedObject var model: AppModel
    let note: Note

    private var title: String {
        note.goal.flatMap { model.index.goal(matching: $0) }
            .map { "Serves \($0.displayTitle)" } ?? "Serves\u{2026}"
    }

    var body: some View {
        Menu {
            NoteGoalOptions(model: model, note: note)
        } label: {
            Label(title, systemImage: "star")
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(note.goal == nil ? Color.secondary : ParaKind.goal.tint)
        .help(note.kind == .project
              ? "Which goal this project delivers"
              : "Which aspiration this part of your life serves")
    }
}

/// Right-click an area in the list: where does it belong?
struct AreaParentMenu: View {
    @ObservedObject var model: AppModel
    let note: Note

    var body: some View {
        Menu("Part of") {
            AreaParentOptions(model: model, note: note)
        }
    }
}

/// The same choices at the top of an area note, where they can actually be found.
struct AreaParentChip: View {
    @ObservedObject var model: AppModel
    let note: Note

    private var title: String {
        model.index.parentArea(of: note).map { "Part of \($0.displayTitle)" } ?? "Part of\u{2026}"
    }

    var body: some View {
        Menu {
            AreaParentOptions(model: model, note: note)
        } label: {
            Label(title, systemImage: "arrow.turn.left.up")
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(ParaKind.area.tint)
        .help("Put this area under another area, or take it back out")
    }
}

struct NoteRow: View {
    let note: Note
    /// Filled in for goals only: how far the work under this goal has come. The row cannot
    /// work it out itself — it holds one note, and the roll-up needs the whole index.
    var goalProgress: GoalProgress? = nil

    var body: some View {
        HStack(spacing: 10) {
            TintStripe(color: note.tint, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if let status = note.status, status != "active" {
                        Text(status.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(note.tint.opacity(0.18), in: Capsule())
                            .foregroundStyle(note.tint)
                    }
                }
                HStack(spacing: 8) {
                    let progress = note.progress
                    if note.kind == .project, progress.total > 0 {
                        ProgressView(value: Double(progress.done), total: Double(progress.total))
                            .tint(note.tint)
                            .frame(width: 56)
                        Text("\(progress.done) of \(progress.total)")
                            .foregroundStyle(note.tint)
                    } else if let roll = goalProgress, roll.fraction != nil {
                        GoalProgressBar(progress: roll, width: 56, showsCounts: false)
                    } else if note.openTasks.count > 0 {
                        Label("\(note.openTasks.count)", systemImage: "checklist")
                            .foregroundStyle(note.tint)
                    }
                    if let due = note.dueDate {
                        let days = due.days(since: .today())
                        Label(days == 0 ? "Due today" : (days > 0 ? "Due in \(days) d" : "\(-days) d overdue"), systemImage: "calendar")
                            .foregroundStyle(days < 0 ? Color.red : Color.secondary)
                    }
                    if let horizon = note.horizon {
                        Label(horizon.label, systemImage: "scope")
                            .foregroundStyle(note.tint)
                    }
                    if let target = note.targetDate {
                        Label(target.description, systemImage: "flag.checkered")
                    }
                    if let goal = note.goal, note.kind != .goal {
                        Label(goal, systemImage: "star")
                            .foregroundStyle(ParaKind.goal.tint)
                    }
                    if let area = note.area {
                        Label(area, systemImage: "circle.grid.2x2")
                            .foregroundStyle(ParaKind.area.tint)
                    }
                    if note.kind == .resource, !note.related.isEmpty {
                        Label("\(note.related.count)", systemImage: "link")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct DetailView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        // The colour follows the section, not the note: it is there to say which mode you are
        // in, and it stays put while you click from note to note.
        detail.modeAccent(model.section?.tint ?? .secondary)
    }

    @ViewBuilder
    private var detail: some View {
        if model.section == .calendar {
            // The Calendar section gets the day's schedule here, with the note one click away.
            CalendarDetailView()
        } else if model.section == .templates {
            if let name = model.templateSelection {
                TemplateEditorView(name: name).id(name)
            } else {
                EmptyStateView(title: "Pick a template",
                               systemImage: SidebarSection.templates.systemImage,
                               message: "On the left are the files a new note starts from, and the snippets you can drop into one. Choose one to edit it.",
                               tint: SidebarSection.templates.tint)
            }
        } else if model.section == .inbox, !model.inboxShowsNote {
            // Sorting happens in the middle column; this is where the lines can go.
            InboxFileItView()
        } else if let path = model.selectedNotePath, model.note(at: path) != nil {
            NoteEditorView(path: path)
                .id(path)
        } else if model.section == .timeBlocks {
            EmptyStateView(title: "Time blocks live in Apple Calendar",
                           systemImage: "calendar.badge.clock",
                           message: "Add a block on the left. It becomes an event in the calendar you chose and shows up on all your devices. Click a block to edit it, right-click to open it in Calendar or delete it.",
                           tint: SidebarSection.timeBlocks.tint)
        } else if model.section == .done {
            EmptyStateView(title: "What you finished",
                           systemImage: "checkmark.circle",
                           message: "Pick a day on the left to see the tasks you ticked off, and the note each one came from.",
                           tint: SidebarSection.done.tint)
        } else {
            EmptyStateView(title: "No note open",
                           systemImage: "doc.text",
                           message: "Choose a note in the middle column, or make a new one.",
                           actionTitle: "New note…",
                           action: { model.activeSheet = .newNote })
        }
    }
}

struct SyncButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Menu {
            Button("Sync now") { Task { await model.syncNow() } }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Show me what would change…") { Task { await model.previewSync() } }
            if model.lastReport != nil {
                Divider()
                Button("Last sync report…") { model.showLastReport() }
            }
        } label: {
            if model.isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Sync with Reminders", systemImage: "arrow.triangle.2.circlepath")
            }
        } primaryAction: {
            Task { await model.syncNow() }
        }
        .disabled(model.isSyncing)
        .help(model.lastReport.map { "Last sync: \($0.summary)" } ?? "Sync tasks with Apple Reminders (⇧⌘R)")
    }
}

// MARK: - Colour

/// One colour per PARA bucket, carried through every screen: Projects green,
/// Areas pink, Resources blue, Archive grey, plus a hue for each action list.
/// Each name resolves to a colour set with a light and a dark variant.
extension ParaKind {
    var tint: Color {
        switch self {
        case .project: return Color("ProjectTint")
        case .area: return Color("AreaTint")
        case .resource: return Color("ResourceTint")
        case .archive: return Color("ArchiveTint")
        case .goal: return Color("GoalTint")
        case .inbox: return Color("InboxTint")
        case .daily: return Color("CalendarTint")
        }
    }
}

extension SidebarSection {
    var tint: Color {
        switch self {
        case .inbox: return Color("InboxTint")
        case .today: return Color("CalendarTint")
        case .calendar: return Color("CalendarTint")
        case .timeBlocks: return Color("CalendarTint")
        case .done: return Color("ReviewTint")
        case .allActions: return Color("ProjectTint")
        case .recent: return Color("ResourceTint")
        case .deleted: return Color("ArchiveTint")
        case .templates: return Color("ResourceTint")
        case .review: return Color("ReviewTint")
        case .map: return Color("GoalTint")
        case .search: return Color("ResourceTint")
        // Its own colour, belonging to none of the PARA buckets — it is not one of them.
        case .work: return Color("ArchiveTint")
        case .kind(let kind): return kind.tint
        }
    }
}

extension Note {
    var tint: Color { kind.tint }
}

/// A small filled circle carrying a bucket's colour and symbol.
struct KindBadge: View {
    let kind: ParaKind
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: SidebarSection.kind(kind).systemImage)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(kind.tint, in: Circle())
            .accessibilityLabel(kind.displayName)
    }
}

/// The coloured stripe down the leading edge of a row.
struct TintStripe: View {
    let color: Color
    var height: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 3, height: height)
    }
}
