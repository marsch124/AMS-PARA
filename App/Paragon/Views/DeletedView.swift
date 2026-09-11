import SwiftUI
import ParagonCore

/// The Deleted section: notes you removed, newest first, with a way back.
/// They sit in a hidden folder inside the vault, so this works the same on the Mac
/// and on the phone, and nothing here is synced to Reminders.
struct DeletedView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmEmpty = false

    private var listed: [DeletedNote] { model.deletedNotes }

    var body: some View {
        Group {
            if listed.isEmpty {
                EmptyStateView(title: "Nothing deleted",
                               systemImage: "trash",
                               message: "Notes you delete wait here for \(AppModel.deletedKeptForDays) days, so a mistake is never final. Tasks are not kept here — only whole notes.")
            } else {
                List {
                    Section {
                        ForEach(listed) { deleted in
                            DeletedRow(deleted: deleted)
                        }
                    } footer: {
                        Text("Kept for \(AppModel.deletedKeptForDays) days, then cleared out.")
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Deleted")
        .toolbar {
            if !listed.isEmpty {
                ToolbarItem {
                    Button("Empty") { confirmEmpty = true }
                        .help("Delete everything here for good")
                }
            }
        }
        .confirmationDialog("Delete all \(listed.count) for good?", isPresented: $confirmEmpty) {
            Button("Delete for good", role: .destructive) { model.emptyDeleted() }
        } message: {
            Text("This cannot be undone.")
        }
        .onAppear { model.refreshDeleted() }
    }
}

struct DeletedRow: View {
    @EnvironmentObject private var model: AppModel
    let deleted: DeletedNote

    private var when: String {
        guard deleted.deletedAt != .distantPast else { return "Deleted" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Deleted \(formatter.localizedString(for: deleted.deletedAt, relativeTo: Date()))"
    }

    var body: some View {
        HStack(spacing: 10) {
            TintStripe(color: deleted.kind.tint, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(deleted.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(deleted.kind.displayName) · \(when)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Button("Put back") { model.putBack(deleted) }
                .help("Return it to \(deleted.originalPath.isEmpty ? "its folder" : deleted.originalPath)")
            Button {
                model.deleteForGood(deleted)
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete this one for good")
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Put back") { model.putBack(deleted) }
            Button("Delete for good", role: .destructive) { model.deleteForGood(deleted) }
        }
    }
}
