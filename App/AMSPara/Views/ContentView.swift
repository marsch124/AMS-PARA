import SwiftUI
import UniformTypeIdentifiers
import AMSParaCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingImporter = false
    @State private var showingSettings = false

    var body: some View {
        Group {
            if model.vault == nil {
                WelcomeView(showingImporter: $showingImporter)
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
                        SyncButton()
                        #if !os(macOS)
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                        #endif
                    }
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                model.openVault(at: url)
            }
        }
        .sheet(isPresented: $model.showingNewNote) {
            NewNoteSheet()
                .environmentObject(model)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(model)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
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
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
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
        List(selection: $model.section) {
            Section("Actions") {
                row(.inbox)
                row(.today)
                row(.calendar)
                row(.review)
            }
            Section("PARA") {
                row(.kind(.project))
                row(.kind(.area))
                row(.kind(.resource))
                row(.kind(.archive))
            }
        }
        .navigationTitle("AMS PARA")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        #endif
    }

    private func row(_ section: SidebarSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .badge(model.count(for: section))
            .tag(section)
    }
}

struct NoteListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.section == .today {
                TodayView()
            } else if model.section == .calendar {
                CalendarView()
            } else if model.section == .review {
                ReviewView()
            } else {
                List(model.notes(in: model.section), selection: $model.selectedNotePath) { note in
                    NoteRow(note: note)
                        .tag(note.relativePath)
                }
                .searchable(text: $model.searchText, prompt: "Search notes")
            }
        }
        .navigationTitle(model.section?.title ?? "Notes")
        .toolbar {
            ToolbarItem {
                Button {
                    model.showingNewNote = true
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
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let status = note.status, status != "active" {
                    Text(status.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            HStack(spacing: 8) {
                let open = note.openTasks.count
                if open > 0 {
                    Label("\(open)", systemImage: "checklist")
                }
                if let due = note.dueDate {
                    Label(due.description, systemImage: "calendar")
                }
                if let area = note.area {
                    Label(area, systemImage: "circle.grid.2x2")
                }
                if note.kind == .resource, !note.related.isEmpty {
                    Label("\(note.related.count)", systemImage: "link")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
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
