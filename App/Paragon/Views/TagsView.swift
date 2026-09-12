import SwiftUI
import ParagonCore

/// Every tag in the vault, and what carries it.
///
/// Until build 143 a tag could only be reached through the **Tag** chip in Search, which
/// listed the names and nothing else — no counts, no way to see what a tag was actually on.
/// His own description of what a tag is decided the shape of this screen: "ett system för att
/// filtrera eller gruppera".
///
/// One screen, not a two-column one. A tag opens in place, so the Mac and the phone show the
/// same thing and there is no second route to keep working.
struct TagsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter = ""
    /// Tags folded shut, by their lower-case name. Everything starts folded: the list is the
    /// point, and forty open tags is not a list.
    @State private var opened: Set<String> = []

    private var uses: [TagUse] {
        let all = model.index.tagUses()
        let needle = NoteIndex.normalized(filter)
        guard !needle.isEmpty else { return all }
        return all.filter { $0.tag.lowercased().contains(needle) }
    }

    var body: some View {
        Group {
            if model.index.allTags.isEmpty {
                EmptyStateView(title: "No tags yet",
                               systemImage: SidebarSection.tags.systemImage,
                               message: "Write #travel, #waiting or any other word with a # in front of it, in a note or in a task. Every tag you use turns up here.",
                               tint: SidebarSection.tags.tint)
            } else {
                // A plain List, and every row a Button. Nothing is tagged for selection: one
                // note can carry two tags and would then appear twice, and two rows with the
                // same selection tag is what left the Inbox unclickable in builds 71 to 74.
                List {
                    ForEach(uses) { use in
                        Section {
                            if opened.contains(use.tag.lowercased()) {
                                contents(of: use.tag)
                            }
                        } header: {
                            header(for: use)
                        }
                    }
                }
                .searchable(text: $filter, prompt: "Find a tag")
            }
        }
        .navigationTitle("Tags")
    }

    private func header(for use: TagUse) -> some View {
        let isOpen = opened.contains(use.tag.lowercased())
        return Button {
            toggle(use.tag)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Text("#\(use.tag)")
                    .font(.headline)
                    .foregroundStyle(SidebarSection.tags.tint)
                Spacer(minLength: 6)
                Text(summary(of: use))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .contextMenu {
            Button("Search for #\(use.tag)") {
                model.queryText = "#\(use.tag)"
                model.show(section: .search, notePath: nil)
            }
        }
    }

    /// Built outside the ViewBuilder, where a `var` is allowed.
    private func summary(of use: TagUse) -> String {
        var parts: [String] = []
        if use.noteCount > 0 { parts.append("\(use.noteCount) \(use.noteCount == 1 ? "note" : "notes")") }
        if use.openTaskCount > 0 { parts.append("\(use.openTaskCount) open") }
        if use.finishedTaskCount > 0 { parts.append("\(use.finishedTaskCount) done") }
        return parts.joined(separator: " \u{00b7} ")
    }

    @ViewBuilder
    private func contents(of tag: String) -> some View {
        let notes = model.index.notesTagged(tag)
        let tasks = model.index.tasksTagged(tag)
        if notes.isEmpty && tasks.isEmpty {
            Text("Nothing carries this tag any more.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        ForEach(notes) { note in
            Button {
                // Stay in Tags: on the Mac the note opens in the third column with this list
                // still beside it, on the phone the back arrow comes straight back here.
                model.show(section: .tags, notePath: note.relativePath)
            } label: {
                HStack(spacing: 8) {
                    KindBadge(kind: note.declaredKind, size: 18)
                    Text(note.displayTitle)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        ForEach(tasks) { ref in
            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
        }
    }

    private func toggle(_ tag: String) {
        let key = tag.lowercased()
        if opened.contains(key) {
            opened.remove(key)
        } else {
            opened.insert(key)
        }
    }
}

/// The blocks of tasks kept in Templates/Snippets.md.
///
/// They had no row of their own before build 143: they were one line inside the Templates
/// list, and he asked twice where snippets are edited. The list says what is in the file; the
/// file itself is edited beside it on the Mac, and one tap away on the phone.
struct SnippetsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.snippets.isEmpty {
                EmptyStateView(title: "No snippets yet",
                               systemImage: SidebarSection.snippets.systemImage,
                               message: "A snippet is a block of tasks you use again and again \u{2014} packing for a trip, closing a project. They live in one file, Templates \u{203a} Snippets, with a ## heading above each block.",
                               tint: SidebarSection.snippets.tint)
            } else {
                List {
                    Section {
                        ForEach(model.snippets) { snippet in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(snippet.name)
                                    .font(.headline)
                                Text(firstLines(of: snippet))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    } footer: {
                        Text("Add one from the Snippet button beside Add a task in any note. To change them, edit the file itself \u{2014} each ## heading starts a new block.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    #if os(iOS)
                    Section {
                        NavigationLink("Edit the Snippets file", value: PhoneRoute.template(Snippets.fileName))
                    }
                    #endif
                }
            }
        }
        .navigationTitle("Snippets")
    }

    /// What the block contains, as one line of prose. Built outside the ViewBuilder.
    private func firstLines(of snippet: Snippet) -> String {
        let written = snippet.lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return written.isEmpty ? "Empty" : written.joined(separator: " \u{00b7} ")
    }
}
