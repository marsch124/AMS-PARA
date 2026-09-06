import SwiftUI
import AMSParaCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingImporter = false
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true

    var body: some View {
        Form {
            Section("Vault") {
                LabeledContent("Folder") {
                    Text(model.vaultPath ?? "No vault selected")
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                HStack {
                    Button("Choose folder…") { showingImporter = true }
                    if model.vault != nil {
                        Button("Close vault", role: .destructive) { model.closeVault() }
                    }
                }
            }

            Section("Reminders sync") {
                Picker("Sync automatically", selection: Binding(
                    get: { model.autoSyncMinutes },
                    set: { model.autoSyncMinutes = $0 }
                )) {
                    Text("Off").tag(0)
                    Text("Every 5 minutes").tag(5)
                    Text("Every 15 minutes").tag(15)
                    Text("Every 30 minutes").tag(30)
                    Text("Every hour").tag(60)
                }
                Picker("When both sides changed", selection: Binding(
                    get: { model.config.conflictPolicy },
                    set: { var c = model.config; c.conflictPolicy = $0; model.config = c }
                )) {
                    Text("The note wins").tag(ConflictPolicy.noteWins)
                    Text("The reminder wins").tag(ConflictPolicy.reminderWins)
                }
                Toggle("Sync tasks in Area notes", isOn: Binding(
                    get: { model.config.syncAreas },
                    set: { var c = model.config; c.syncAreas = $0; model.config = c }
                ))
                Toggle("Create missing Reminders lists", isOn: Binding(
                    get: { model.config.createMissingLists },
                    set: { var c = model.config; c.createMissingLists = $0; model.config = c }
                ))
                Toggle("Import reminders that are already completed", isOn: Binding(
                    get: { model.config.importCompletedReminders },
                    set: { var c = model.config; c.importCompletedReminders = $0; model.config = c }
                ))
                Toggle("Sync tasks in daily notes", isOn: Binding(
                    get: { model.config.syncDailyNotes },
                    set: { var c = model.config; c.syncDailyNotes = $0; model.config = c }
                ))
                LabeledContent("Inbox list") {
                    Text(model.config.inboxListName).foregroundStyle(.secondary)
                }
                LabeledContent("Daily notes list") {
                    Text(model.config.dailyNotesListName).foregroundStyle(.secondary)
                }
            }
            .disabled(model.vault == nil)

            Section("Apple Calendar") {
                Toggle("Show the day's events in Today and in daily notes", isOn: Binding(
                    get: { model.showsCalendarEvents },
                    set: { model.showsCalendarEvents = $0 }
                ))
                if model.calendarAccessGranted == false {
                    Text("Calendar access is off. Allow it in System Settings › Privacy & Security › Calendars.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text("Events are read from Apple Calendar only. Nothing is written to your calendars.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Quick capture") {
                #if os(macOS)
                Toggle("Show capture panel in the menu bar", isOn: $showMenuBarItem)
                #endif
                Text("⇧⌘N opens the capture panel in the app. Other apps can add to the Inbox with a link like amspara://capture?text=Call%20the%20bank&target=inbox (Shortcuts: Open URL). On iOS, use Share › AMS PARA.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Weekly review") {
                Stepper("Flag projects unchanged for \(model.config.staleProjectDays) days", value: Binding(
                    get: { model.config.staleProjectDays },
                    set: { var c = model.config; c.staleProjectDays = $0; model.config = c }
                ), in: 3...90)
                Stepper("Review projects every \(model.config.reviewIntervalDays) days", value: Binding(
                    get: { model.config.reviewIntervalDays },
                    set: { var c = model.config; c.reviewIntervalDays = $0; model.config = c }
                ), in: 1...60)
            }
            .disabled(model.vault == nil)

            Section("Last sync") {
                if let report = model.lastReport {
                    Text(report.summary)
                    ForEach(report.conflicts, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                    ForEach(report.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text("Not synced yet in this session.").foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Device id", value: model.deviceID)
                Text("Sync state is stored per device in the vault's .ams-para folder. Task ids (^t…) in your notes and the ams-para marker in reminder notes are what keep both sides linked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        #if os(macOS)
        .frame(width: 520, height: 560)
        #endif
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                model.openVault(at: url)
            }
        }
    }
}
