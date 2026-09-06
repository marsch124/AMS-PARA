import SwiftUI
import AMSParaCore

@main
struct AMSParaApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .commands {
            CommandGroup(after: .newItem) {
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
            }
            CommandGroup(replacing: .help) {
                #if os(macOS)
                HelpMenuButtons()
                #endif
                Button("Copy Diagnostics") { model.copyDiagnostics() }
                    .keyboardShortcut("d", modifiers: [.command, .option])
            }
        }
        #if os(macOS)
        MenuBarExtra("AMS PARA quick capture", systemImage: "tray.and.arrow.down", isInserted: $showMenuBarItem) {
            QuickCaptureView(compact: true)
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView()
                .environmentObject(model)
        }
        WindowGroup("AMS PARA Help", id: "help", for: HelpView.Page.self) { page in
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
        Button("How AMS PARA Works") { openWindow(id: "help", value: HelpView.Page.howItWorks) }
            .keyboardShortcut("?", modifiers: [.command])
        Button("Version History") { openWindow(id: "help", value: HelpView.Page.versionHistory) }
    }
}
#endif
