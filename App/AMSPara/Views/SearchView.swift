import SwiftUI
import AMSParaCore

/// Content column for the Search section: a query field, filter chips, and ranked results.
struct SearchView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var focused: Bool

    private static let dueOptions: [(String, String)] = [
        ("Overdue", "due:overdue"), ("Today", "due:today"), ("This week", "due:week"), ("This month", "due:month"), ("No date", "due:none"),
    ]

    var body: some View {
        let query = model.searchQuery
        let hits = model.searchHits
        VStack(spacing: 0) {
            TextField("Search notes and tasks… e.g. website tag:web due:week is:open", text: $model.queryText)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .padding(10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Menu {
                        ForEach([ParaKind.goal, .project, .area, .resource, .archive, .daily, .inbox], id: \.self) { kind in
                            Button {
                                toggle("type:\(kind.rawValue)")
                            } label: {
                                Label(kind.displayName, systemImage: SidebarSection.kind(kind).systemImage)
                            }
                        }
                    } label: {
                        chipLabel("Type", active: !query.kinds.isEmpty)
                    }
                    Menu {
                        ForEach(["active", "on-hold", "done", "archived"], id: \.self) { status in
                            Button(status.capitalized) { toggle("status:\(status)") }
                        }
                    } label: {
                        chipLabel("Status", active: !query.statuses.isEmpty)
                    }
                    Menu {
                        let tags = model.index.allTags
                        if tags.isEmpty { Text("No tags yet") }
                        ForEach(tags, id: \.self) { tag in
                            Button("#\(tag)") { toggle("#\(tag)") }
                        }
                    } label: {
                        chipLabel("Tag", active: !query.tags.isEmpty)
                    }
                    Menu {
                        ForEach(Self.dueOptions, id: \.1) { option in
                            Button(option.0) { toggle(option.1) }
                        }
                    } label: {
                        chipLabel("Due", active: query.due != nil)
                    }
                    Button { toggle("is:open") } label: { chipLabel("Open tasks", active: query.taskFilter == .open) }
                    Button { toggle("is:done") } label: { chipLabel("Done", active: query.taskFilter == .done) }
                    if !model.queryText.isEmpty {
                        Button { model.queryText = "" } label: { chipLabel("Clear", active: false) }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            Divider()
            if query.isEmpty {
                SearchHelpView()
            } else if hits.isEmpty {
                ContentUnavailableView.search(text: model.queryText)
            } else {
                List(selection: model.noteSelection) {
                    if query.wantsTasks {
                        let refs = hits.flatMap { hit in hit.tasks.map { TaskRef(notePath: hit.note.relativePath, noteTitle: hit.note.displayTitle, task: $0) } }
                        Section("\(refs.count) task\(refs.count == 1 ? "" : "s")") {
                            ForEach(refs) { ref in
                                TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                                    .tag(ref.notePath)
                            }
                        }
                    } else {
                        Section("\(hits.count) note\(hits.count == 1 ? "" : "s")") {
                            ForEach(hits) { hit in
                                SearchHitRow(hit: hit)
                                    .tag(hit.note.relativePath)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { focused = true }
    }

    private func chipLabel(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(active ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12), in: Capsule())
    }

    /// Adds a filter token to the query, or removes it when already present.
    private func toggle(_ token: String) {
        var tokens = model.queryText.split(separator: " ").map(String.init)
        if let i = tokens.firstIndex(where: { $0.caseInsensitiveCompare(token) == .orderedSame }) {
            tokens.remove(at: i)
        } else {
            let key = token.split(separator: ":").first.map(String.init) ?? token
            if ["due", "is"].contains(key) {
                tokens.removeAll { $0.lowercased().hasPrefix(key + ":") }
            }
            tokens.append(token)
        }
        model.queryText = tokens.joined(separator: " ")
    }
}

struct SearchHitRow: View {
    let hit: SearchHit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                KindBadge(kind: hit.note.kind, size: 20)
                Text(hit.note.displayTitle)
                    .font(.headline)
                Spacer()
                if let status = hit.note.status, status != "active" {
                    Text(status.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(hit.note.tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(hit.note.tint)
                }
            }
            ForEach(hit.snippets.prefix(2), id: \.self) { snippet in
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if !hit.tasks.isEmpty && hit.snippets.isEmpty {
                Text("\(hit.tasks.count) matching task\(hit.tasks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SearchHelpView: View {
    @EnvironmentObject private var model: AppModel

    private let examples: [(String, String)] = [
        ("due:overdue is:open", "Everything overdue"),
        ("due:week is:open", "Due this week"),
        ("type:project status:active", "Active projects"),
        ("type:resource", "All reference material"),
        ("is:done due:any", "Completed tasks that had a date"),
    ]

    var body: some View {
        List {
            Section("Try") {
                ForEach(examples, id: \.0) { example in
                    Button {
                        model.queryText = example.0
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(example.0).font(.system(.body, design: .monospaced))
                            Text(example.1).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("Filters") {
                Text("type: project, area, resource, archive, daily, inbox\nstatus: active, on-hold, done, archived\ntag:web or #web · area:Health · in:Projects\ndue: overdue, today, week, month, none, any\nis: open, done · \"quoted phrase\" matches exactly")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
