import SwiftUI
import ParagonCore

/// What a sync did, or what one would do. The same sheet serves both.
struct SyncReportView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let report = model.reportToShow
        let preview = model.reportIsPreview
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(preview ? "If you sync now" : "Last sync", systemImage: preview ? "eye" : "arrow.triangle.2.circlepath")
                    .font(.headline)
                Spacer()
                if let finished = report?.finishedAt {
                    Text(finished.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let report {
                        if report.changeCount == 0 {
                            Label("Nothing to change. Notes and Reminders already match.", systemImage: "checkmark.circle")
                                .foregroundStyle(.secondary)
                        } else {
                            rows(report)
                        }
                        if !report.conflicts.isEmpty {
                            section("Changed in both places", report.conflicts, icon: "exclamationmark.triangle", tint: .orange)
                        }
                        if !report.warnings.isEmpty {
                            section("Worth knowing", report.warnings, icon: "info.circle", tint: .secondary)
                        }
                        Text("\(report.notesSynced) note\(report.notesSynced == 1 ? "" : "s") take part in the sync. Goals and archived notes never do.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("No sync has run yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
            }
            Divider()
            HStack {
                if preview {
                    Text("Nothing was changed. This was a rehearsal on a copy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if preview {
                    Button("Sync now") {
                        dismiss()
                        Task { await model.syncNow() }
                    }
                    .keyboardShortcut(.defaultAction)
                }
                Button(preview ? "Not yet" : "Done") { dismiss() }
                    .keyboardShortcut(preview ? .cancelAction : .defaultAction)
            }
            .padding(14)
        }
        .frame(minWidth: 420, minHeight: 320)
    }

    @ViewBuilder
    private func rows(_ report: SyncReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Reminders created", report.remindersCreated, "plus.circle", .green)
            row("Reminders updated", report.remindersUpdated, "pencil.circle", .blue)
            row("Reminders deleted", report.remindersDeleted, "minus.circle", .red)
            row("Tasks added to notes", report.tasksCreated, "text.badge.plus", .green)
            row("Tasks updated in notes", report.tasksUpdated, "text.badge.checkmark", .blue)
            row("Tasks cancelled in notes", report.tasksCancelled, "xmark.circle", .orange)
            row("Task markers assigned", report.idsAssigned, "tag", .secondary)
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ count: Int, _ icon: String, _ tint: Color) -> some View {
        if count > 0 {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title)
                Spacer()
                Text("\(count)").monospacedDigit().fontWeight(.medium)
            }
        }
    }

    private func section(_ title: String, _ lines: [String], icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
