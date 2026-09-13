import SwiftUI
import ParagonCore

#if os(iOS)
/// The iPhone layout: tabs for Today, Inbox, Browse and Capture, each tab a stack that
/// pushes the note editor. Used when the window is compact; iPad and Mac keep the columns.
struct PhoneRootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: Tab = .today

    enum Tab: Hashable {
        case today, inbox, browse, capture
    }

    var body: some View {
        TabView(selection: $tab) {
            PhoneStack(section: .today, isActive: tab == .today) {
                TodayView()
                    .navigationTitle("Today")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { PhoneSyncButton() } }
            }
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(Tab.today)

            PhoneStack(section: .inbox, isActive: tab == .inbox) {
                NoteListView()
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { PhoneSyncButton() } }
            }
            .tabItem { Label("Inbox", systemImage: "tray") }
            .badge(model.count(for: .inbox))
            .tag(Tab.inbox)

            PhoneStack(section: nil, isActive: tab == .browse) {
                PhoneBrowseView()
            }
            .tabItem { Label("Browse", systemImage: "square.grid.2x2") }
            .tag(Tab.browse)

            Color.clear
                .tabItem { Label("Capture", systemImage: "tray.and.arrow.down") }
                .tag(Tab.capture)
        }
        .onChange(of: tab) { old, new in
            // The Capture tab is a button: open the capture sheet and stay on the previous tab.
            if new == .capture {
                model.activeSheet = .quickCapture
                tab = old
            }
        }
    }
}

/// Sync with Reminders from the phone. The Mac has this in the window toolbar; without it
/// here the phone could only wait for auto sync, and iOS never asked for Reminders access.
struct PhoneSyncButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            Task { await model.syncNow() }
        } label: {
            if model.isSyncing {
                ProgressView()
            } else {
                Label("Sync with Reminders", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .disabled(model.isSyncing || model.vault == nil)
    }
}

/// One tab's navigation stack. Selecting a note anywhere in the model pushes the editor
/// on the active tab; going back clears the selection.
struct PhoneStack<Content: View>: View {
    @EnvironmentObject private var model: AppModel
    let section: SidebarSection?
    let isActive: Bool
    @ViewBuilder let content: () -> Content
    @State private var path: [PhoneRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            content()
                .navigationDestination(for: PhoneRoute.self) { route in
                    switch route {
                    case .note(let notePath):
                        NoteEditorView(path: notePath)
                            .id(notePath)
                            .navigationBarTitleDisplayMode(.inline)
                    case .section(let section):
                        PhoneSectionScreen(section: section)
                    case .template(let name):
                        TemplateEditorView(name: name)
                            .id(name)
                            .navigationBarTitleDisplayMode(.inline)
                    case .planner:
                        PlannerView()
                            .navigationBarTitleDisplayMode(.inline)
                    case .settings:
                        SettingsView()
                            .navigationTitle("Settings")
                    }
                }
        }
        .onAppear {
            if isActive, let section, model.section != section { model.section = section }
        }
        .onChange(of: isActive) { _, active in
            if active, let section, model.section != section { model.section = section }
            if active, let selected = model.selectedNotePath, path.last != .note(selected) { path.append(.note(selected)) }
        }
        // A template opens the same way a note does: the middle column picks one, this pushes it.
        .onChange(of: model.templateSelection) { _, selected in
            guard isActive, model.section == .templates else { return }
            if let selected {
                if path.last != .template(selected) { path.append(.template(selected)) }
            } else if case .template = path.last {
                path.removeLast()
            }
        }
        // Revealing Work has to open it here as well: the Mac's columns watch the section,
        // but on the phone a screen exists only once it has been pushed (build 117). The
        // Browse tab is the one with no section of its own.
        //
        // Driven by the *count* of requests, not by `workRevealed`: that flag changes on the
        // first long press and never again, so the second one went nowhere (build 122).
        .onChange(of: model.workRequests) { _, _ in
            guard isActive, section == nil else { return }
            if path.last != .section(.work) { path.append(.section(.work)) }
        }
        // Hiding is still a change of the flag, and only ever in one direction.
        .onChange(of: model.workRevealed) { _, revealed in
            guard isActive, section == nil, !revealed else { return }
            if path.last == .section(.work) { path.removeLast() }
        }
        .onChange(of: model.selectedNotePath) { _, selected in
            guard isActive else { return }
            if let selected {
                if path.last != .note(selected) { path.append(.note(selected)) }
            } else if case .note = path.last {
                path.removeLast()
            }
        }
        .onChange(of: path) { _, newPath in
            guard isActive else { return }
            let showsNote = newPath.contains { if case .note = $0 { return true } else { return false } }
            if !showsNote, model.selectedNotePath != nil { model.selectedNotePath = nil }
            let showsTemplate = newPath.contains { if case .template = $0 { return true } else { return false } }
            if !showsTemplate, model.templateSelection != nil { model.templateSelection = nil }
            if case .section(let section)? = newPath.last, model.section != section { model.section = section }
        }
    }
}

enum PhoneRoute: Hashable {
    case note(String)
    case template(String)
    case section(SidebarSection)
    case planner
    case settings
}

/// The Browse tab: every section as a row, plus Settings.
struct PhoneBrowseView: View {
    @EnvironmentObject private var model: AppModel

    private let groups: [(String, [SidebarSection])] = [
        ("Goals and PARA", [.kind(.goal), .kind(.project), .kind(.area), .kind(.resource), .kind(.archive)]),
        ("Plan", [.allActions, .recent, .calendar, .timeBlocks, .done, .review, .map, .deleted, .search]),
        ("Tools", SidebarSection.tools),
    ]

    var body: some View {
        List {
            ForEach(groups, id: \.0) { group in
                Section(group.0) {
                    ForEach(group.1) { section in
                        NavigationLink(value: PhoneRoute.section(section)) {
                            Label {
                                HStack {
                                    Text(section.title)
                                    Spacer()
                                    let count = model.count(for: section)
                                    if count > 0 {
                                        Text("\(count)").foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: section.systemImage)
                                    .foregroundStyle(section.tint)
                            }
                        }
                    }
                }
            }
            Section {
                NavigationLink(value: PhoneRoute.settings) {
                    Label("Settings and Help", systemImage: "gear")
                }
            }
            Section {
                // The other way in, and the one that can actually be found: a long press here.
                // The title in the navigation bar is small and easy to miss (build 117).
                Text("Build \(BuildStamp.number)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1.2) { model.revealWork() }
            }
            // Only there once it has been asked for; see the long press below.
            if model.workRevealed {
                Section {
                    NavigationLink(value: PhoneRoute.section(.work)) {
                        Label {
                            HStack {
                                Text(SidebarSection.work.title)
                                Spacer()
                                Text("\(model.workNotes.count)").foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: SidebarSection.work.systemImage)
                                .foregroundStyle(SidebarSection.work.tint)
                        }
                    }
                }
            }
        }
        .navigationTitle("Browse")
        // Inline, or iOS draws its own large title below the bar and the principal item is
        // never the thing being pressed — which is why build 112's long press did nothing.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The way in: a long press on the title. A plain navigation title cannot take a
            // gesture, so the title is drawn here instead (build 112).
            ToolbarItem(placement: .principal) {
                Text("Browse")
                    .font(.headline)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1.2) { model.revealWork() }
            }
        }
    }
}

/// A section opened from Browse: the same list as the middle column on the Mac.
struct PhoneSectionScreen: View {
    @EnvironmentObject private var model: AppModel
    let section: SidebarSection

    var body: some View {
        NoteListView()
            .onAppear { if model.section != section { model.section = section } }
    }
}
#endif
