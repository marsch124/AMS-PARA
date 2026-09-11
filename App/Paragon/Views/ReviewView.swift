import SwiftUI
import ParagonCore

/// The weekly review: inbox, overdue work, and a health check of every active project and area.
struct ReviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let report = model.index.review(config: model.config)
        List(selection: model.noteSelection) {
            Section("This week") {
                LabeledContent("Completed in the last 7 days", value: "\(report.completedLast7Days)")
                LabeledContent("Overdue tasks", value: "\(report.overdueTasks.count)")
                LabeledContent("Projects needing attention", value: "\(report.projectsNeedingAttention.count)")
                if !report.goals.isEmpty {
                    LabeledContent("Goals needing attention", value: "\(report.goalsNeedingAttention.count)")
                }
                if !report.projectsWithoutGoal.isEmpty {
                    LabeledContent("Projects not serving a goal", value: "\(report.projectsWithoutGoal.count)")
                }
            }

            if !report.projectsWithoutGoal.isEmpty {
                Section {
                    // Buttons, not tagged HealthRows: these projects are listed again under
                    // "3. Projects", and two rows carrying the same selection tag is exactly
                    // what made the Inbox unselectable in builds 71 to 74.
                    ForEach(report.projectsWithoutGoal) { health in
                        Button {
                            // Stay in Weekly review. On the Mac the note opens in the third
                            // column with this list still beside it, so the review can be
                            // worked straight down; on the phone it pushes one screen and the
                            // back arrow returns here. Jumping to the Projects section instead
                            // threw the review away and gave Back nowhere sensible to return to.
                            model.show(section: .review, notePath: health.note.relativePath)
                        } label: {
                            Label(health.note.displayTitle, systemImage: "questionmark.circle")
                        }
                    }
                } header: {
                    Text("Hobby or homeless?")
                } footer: {
                    Text("Work with nothing above it. Give one a goal, decide it is a standing part of an area \u{2014} or leave it be. None of these counts as needing attention.")
                }
            }

            Section("1. Empty the inbox") {
                if report.inboxOpenTasks == 0 {
                    Label("Inbox is empty", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        model.show(section: .inbox, notePath: model.vault?.config.inboxFile)
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
                    .lineLimit(2)
                Spacer(minLength: 6)
                Group {
                    if let days = health.daysSinceReview {
                        Text("reviewed \(days == 0 ? "today" : "\(days)d ago")")
                    } else {
                        Text("never reviewed")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            }
            WrappingHStack(spacing: 8, lineSpacing: 3) {
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
            .lineLimit(1)
            if !health.flags.isEmpty {
                WrappingHStack(spacing: 6, lineSpacing: 3) {
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
                    .lineLimit(2)
                if let horizon = health.note.horizon {
                    Text(horizon.label)
                        .font(.caption2)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(health.note.tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(health.note.tint)
                }
                Spacer(minLength: 6)
                if let days = health.daysSinceActivity {
                    Text(days == 0 ? "moved today" : "moved \(days)d ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            WrappingHStack(spacing: 8, lineSpacing: 3) {
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
            .lineLimit(1)
            if !health.flags.isEmpty {
                WrappingHStack(spacing: 6, lineSpacing: 3) {
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
