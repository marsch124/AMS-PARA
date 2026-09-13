import SwiftUI
import ParagonCore

@main
struct ParagonApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true
    static let plannerWindowID = "planner"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .commands {
            // `replacing:`, not `after:`. A WindowGroup puts its own "New Window" in this
            // group with ⌘N already on it, and the system item wins: adding a second ⌘N
            // after it meant ⌘N opened an empty second window and never the sheet
            // (build 120). Replacing the group takes New Window out and gives ⌘N back.
            CommandGroup(replacing: .newItem) {
                Button("New Note…") { model.activeSheet = .newNote }
                    .keyboardShortcut("n", modifiers: [.command])
                    .disabled(model.vault == nil)
                Button("Quick Capture…") { model.activeSheet = .quickCapture }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Search Everywhere…") { model.section = .search }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .disabled(model.vault == nil)
                Button("Sync with Reminders") { Task { await model.syncNow() } }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(model.vault == nil || model.isSyncing)
                // The Work section's shortcut. Deliberately not ⌥⌘W, which macOS keeps for
                // closing every window, and deliberately not named in the manual.
                Button(model.workRevealed ? "Hide Work" : "Work") {
                    if model.workRevealed { model.hideWork() } else { model.revealWork() }
                }
                .keyboardShortcut("w", modifiers: [.command, .control])
                .disabled(model.vault == nil)
            }
            // Its own menu, so the shortcuts work wherever the focus happens to be — the
            // toolbar buttons only exist while a note is open.
            CommandMenu("Go") {
                #if os(macOS)
                // Its own window, because the planner wants the width of three columns and
                // the note screen is usually open beside it.
                PlannerMenuButton()
                    .disabled(model.vault == nil)
                Divider()
                #endif
                // Arrows, not the browsers' \u{2318}[ and \u{2318}]: on a Swedish keyboard those
                // brackets are \u{2325}8 and \u{2325}9, so the shortcut would be a three-finger
                // chord and the menu would advertise a key he does not have.
                Button("Back") { model.goBack() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .control])
                    .disabled(!model.canGoBack)
                Button("Forward") { model.goForward() }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .control])
                    .disabled(!model.canGoForward)
            }
            CommandGroup(replacing: .help) {
                #if os(macOS)
                HelpMenuButtons()
                #endif
                Button("Copy Diagnostics") { model.copyDiagnostics() }
                    // Not ⌥⌘D: that is macOS's own "hide the Dock" and never reaches the app.
                    .keyboardShortcut("d", modifiers: [.command, .control])
            }
        }
        #if os(macOS)
        // A window of its own, opened from Go \u{203a} Plan the Day and from the Time Blocks
        // section: the planner wants the width of three columns, and the note screen is
        // usually open beside it. The iPhone has no windows, so there it is a pushed screen.
        Window("Plan the day", id: ParagonApp.plannerWindowID) {
            PlannerView()
                .environmentObject(model)
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 900, height: 620)
        MenuBarExtra("PARAGON quick capture", systemImage: "tray.and.arrow.down", isInserted: $showMenuBarItem) {
            QuickCaptureView(compact: true)
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView()
                .environmentObject(model)
        }
        WindowGroup("PARAGON Help", id: "help", for: HelpView.Page.self) { page in
            HelpView(page: page.wrappedValue ?? .howItWorks)
        }
        .defaultSize(width: 720, height: 640)
        #endif
    }
}

#if os(macOS)
/// Help menu items that open the help window on the chosen page.
struct HelpMenuButtons: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("How PARAGON Works") { openWindow(id: "help", value: HelpView.Page.howItWorks) }
            .keyboardShortcut("?", modifiers: [.command])
        Button("Version History") { openWindow(id: "help", value: HelpView.Page.versionHistory) }
    }
}
#endif

#if os(macOS)
/// Opens the planner window from the Go menu. Its own view because `openWindow` is read from
/// the environment, which a `View` has and the `App` struct does not — the same shape as
/// `HelpMenuButtons`.
struct PlannerMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Plan the Day\u{2026}") { openWindow(id: ParagonApp.plannerWindowID) }
            .keyboardShortcut("p", modifiers: [.command, .shift])
    }
}
#endif
