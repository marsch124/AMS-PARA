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
            CommandGroup(after: .help) {
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
        #endif
    }
}
