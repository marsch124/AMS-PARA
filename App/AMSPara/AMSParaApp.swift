import SwiftUI
import AMSParaCore

@main
struct AMSParaApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Note…") { model.showingNewNote = true }
                    .keyboardShortcut("n", modifiers: [.command])
                    .disabled(model.vault == nil)
                Button("Sync with Reminders") { Task { await model.syncNow() } }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(model.vault == nil || model.isSyncing)
            }
        }
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(model)
        }
        #endif
    }
}
