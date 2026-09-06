import SwiftUI
import AMSParaCore

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
            }
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(Tab.today)

            PhoneStack(section: .inbox, isActive: tab == .inbox) {
                NoteListView()
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
            if case .section(let section)? = newPath.last, model.section != section { model.section = section }
        }
    }
}

enum PhoneRoute: Hashable {
    case note(String)
    case section(SidebarSection)
    case settings
}

/// The Browse tab: every section as a row, plus Settings.
struct PhoneBrowseView: View {
    @EnvironmentObject private var model: AppModel

    private let groups: [(String, [SidebarSection])] = [
        ("Goals and PARA", [.kind(.goal), .kind(.project), .kind(.area), .kind(.resource), .kind(.archive)]),
        ("Plan", [.calendar, .timeBlocks, .done, .review, .map, .search]),
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
                Text("Build \(BuildStamp.number)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("Browse")
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
