import SwiftUI
import UniformTypeIdentifiers
import AMSParaCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingImporter = false

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
            if phase == .active { model.afterUpdate { model.drainOutbox() } }
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
                row(.today)
                row(.calendar)
                row(.review)
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

    var body: some View {
        Group {
            if model.section == .today {
                TodayView()
            } else if model.section == .calendar {
                CalendarView()
            } else if model.section == .review {
                ReviewView()
            } else if model.section == .search {
                SearchView()
            } else {
                List(model.notes(in: model.section, matching: searchText), selection: model.noteSelection) { note in
                    NoteRow(note: note)
                        .tag(note.relativePath)
                }
                .searchable(text: $searchText, prompt: "Search notes")
                .onChange(of: model.section) { _, _ in searchText = "" }
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
        .navigationSplitViewColumnWidth(min: 220, ideal: 280)
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
                    let open = note.openTasks.count
                    if open > 0 {
                        Label("\(open)", systemImage: "checklist")
                            .foregroundStyle(note.tint)
                    }
                    if let due = note.dueDate {
                        Label(due.description, systemImage: "calendar")
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
        case .review: return Color("ReviewTint")
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
