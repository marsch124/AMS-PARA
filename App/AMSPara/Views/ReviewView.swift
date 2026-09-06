import SwiftUI
import AMSParaCore

/// The weekly review: inbox, overdue work, and a health check of every active project and area.
struct ReviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let report = model.index.review(config: model.config)
        List(selection: $model.selectedNotePath) {
            Section("This week") {
                LabeledContent("Completed in the last 7 days", value: "\(report.completedLast7Days)")
                LabeledContent("Overdue tasks", value: "\(report.overdueTasks.count)")
                LabeledContent("Projects needing attention", value: "\(report.projectsNeedingAttention.count)")
                if !report.goals.isEmpty {
                    LabeledContent("Goals needing attention", value: "\(report.goalsNeedingAttention.count)")
                }
            }

            Section("1. Empty the inbox") {
                if report.inboxOpenTasks == 0 {
                    Label("Inbox is empty", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        model.section = .inbox
                        model.selectedNotePath = model.vault?.config.inboxFile
                    } label: {
                        Label("\(report.inboxOpenTasks) open items to file into projects or areas", systemImage: "tray")
                    }
                }
            }

            if !report.overdueTasks.isEmpty {
                Section("2. Reschedule or drop overdue tasks") {
                    ForEach(report.overdueTasks) { ref in
                        TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                            .tag(ref.notePath)
                    }
                }
            }

            if !report.goals.isEmpty {
                Section("Goals") {
                    ForEach(report.goals) { health in
                        GoalHealthRow(health: health)
                            .tag(health.note.relativePath)
                    }
                }
            }

            Section {
                ForEach(report.projects) { health in
                    HealthRow(health: health)
                        .tag(health.note.relativePath)
                }
            } header: {
                HStack {
                    Text("3. Projects")
                    Spacer()
                    Button("Mark all reviewed") { model.markAllReviewed() }
                        .font(.caption)
                }
            }

            if !report.areas.isEmpty {
                Section("4. Areas") {
                    ForEach(report.areas) { health in
                        HealthRow(health: health)
                            .tag(health.note.relativePath)
                    }
                }
            }
        }
    }
}

struct HealthRow: View {
    @EnvironmentObject private var model: AppModel
    let health: ProjectHealth

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                KindBadge(kind: health.note.kind, size: 20)
                Image(systemName: health.needsAttention ? "exclamationmark.triangle.fill" : "checkmark.circle")
                    .foregroundStyle(health.needsAttention ? Color.orange : health.note.tint)
                Text(health.note.title)
                    .font(.headline)
                Spacer()
                if let days = health.daysSinceReview {
                    Text("reviewed \(days == 0 ? "today" : "\(days)d ago")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("never reviewed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Label("\(health.openTaskCount) open", systemImage: "checklist")
                if health.overdueTaskCount > 0 {
                    Label("\(health.overdueTaskCount) overdue", systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(.red)
                }
                Label("\(health.completedLast7Days) done this week", systemImage: "checkmark")
                if let due = health.note.dueDate {
                    Label(due.description, systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !health.flags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(health.flags, id: \.self) { flag in
                        Text(flag.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(flag == .onHold ? Color.secondary.opacity(0.15) : Color.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(flag == .onHold ? Color.secondary : Color.orange)
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button("Mark reviewed") { model.markReviewed(health.note) }
            if health.note.kind == .project {
                if health.flags.contains(.onHold) {
                    Button("Set active") { model.setStatus("active", for: health.note) }
                } else {
                    Button("Put on hold") { model.setStatus("on-hold", for: health.note) }
                }
                Button("Mark done") { model.setStatus("done", for: health.note) }
                Button("Archive") { model.archive(health.note) }
            }
        }
    }
}

struct GoalHealthRow: View {
    let health: GoalHealth

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                KindBadge(kind: .goal, size: 20)
                Text(health.note.title)
                    .font(.headline)
                if let horizon = health.note.horizon {
                    Text(horizon.label)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(health.note.tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(health.note.tint)
                }
                Spacer()
                if let days = health.daysSinceActivity {
                    Text(days == 0 ? "moved today" : "moved \(days)d ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Label("\(health.projects.count) projects", systemImage: "flag")
                Label("\(health.areas.count) areas", systemImage: "circle.grid.2x2")
                Label("\(health.openTaskCount) open", systemImage: "checklist")
                Label("\(health.completedLast30Days) done in 30d", systemImage: "checkmark")
                if let target = health.note.targetDate {
                    Label(target.description, systemImage: "flag.checkered")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !health.flags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(health.flags, id: \.self) { flag in
                        Text(flag.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(flag == .achieved ? health.note.tint.opacity(0.18) : Color.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(flag == .achieved ? health.note.tint : Color.orange)
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }
}
