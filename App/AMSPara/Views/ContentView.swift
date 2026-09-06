import SwiftUI
import UniformTypeIdentifiers
import AMSParaCore

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
        .onAppear { model.afterUpdate { model.drainOutbox() } }
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
            Text("AMS PARA")
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
                row(.calendar)
                row(.timeBlocks)
                row(.done)
                row(.review)
                row(.map)
                row(.search)
            }
            Section("Goals") {
                row(.kind(.goal))
            }
            Section("PARA") {
                row(.kind(.project))
                row(.kind(.area))
                row(.kind(.resource))
                row(.kind(.archive))
            }
        }
        .navigationTitle("AMS PARA")
        .safeAreaInset(edge: .bottom) {
            Text("Build \(BuildStamp.number)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
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

    var body: some View {
        Group {
            if model.section == .today {
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
            } else if model.section == .search {
                SearchView()
            } else {
                List(model.notes(in: model.section, matching: searchText), selection: model.noteSelection) { note in
                    NoteRow(note: note)
                        .tag(note.relativePath)
                        .acceptsTaskDrop { ref in model.moveTask(ref, to: note.relativePath) }
                        .contextMenu {
                            if model.canArchive(note) {
                                Button("Archive") { model.archive(note) }
                            }
                            if note.kind != .inbox {
                                Button("Move to Trash…", role: .destructive) { noteToTrash = note }
                            }
                        }
                }
                .searchable(text: $searchText, prompt: "Search notes")
                .onChange(of: model.section) { _, _ in searchText = "" }
                .confirmationDialog("Move \u{201C}\(noteToTrash?.displayTitle ?? "")\u{201D} to the Trash?",
                                    isPresented: Binding(get: { noteToTrash != nil }, set: { if !$0 { noteToTrash = nil } }),
                                    presenting: noteToTrash) { note in
                    Button("Move to Trash", role: .destructive) { model.trash(note) }
                } message: { _ in
                    Text("You can put it back from the Trash in Finder.")
                }
            }
        }
        .navigationTitle(model.section?.title ?? "Notes")
        .toolbar {
            ToolbarItem {
                Button {
                    model.activeSheet = .newNote
                } label: {
                    Label("New note", systemImage: "square.and.pencil")
                }
            }
        }
        #if os(macOS)
        // The map wants room for its diagram; every other section is a list.
        .navigationSplitViewColumnWidth(min: model.section == .map ? 420 : 220, ideal: model.section == .map ? 720 : 280)
        #endif
    }
}

struct NoteRow: View {
    let note: Note

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
        if let path = model.selectedNotePath, model.note(at: path) != nil {
            NoteEditorView(path: path)
                .id(path)
        } else if model.section == .timeBlocks {
            ContentUnavailableView("Time blocks live in Apple Calendar", systemImage: "calendar.badge.clock",
                                   description: Text("Add a block on the left. It becomes an event in the calendar you chose and shows up on all your devices. Click a block to edit it, right-click to open it in Calendar or delete it."))
        } else {
            ContentUnavailableView("No note selected", systemImage: "doc.text",
                                   description: Text("Choose a note on the left, or press ⌘N to create one."))
        }
    }
}

struct SyncButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            Task { await model.syncNow() }
        } label: {
            if model.isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Sync with Reminders", systemImage: "arrow.triangle.2.circlepath")
            }
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
        case .review: return Color("ReviewTint")
        case .map: return Color("GoalTint")
        case .search: return Color("ResourceTint")
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
