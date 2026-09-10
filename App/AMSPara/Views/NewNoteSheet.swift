import SwiftUI
import AMSParaCore

struct NewNoteSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ParaKind = .project
    @State private var title = ""
    @State private var horizon: GoalHorizon = .year
    @State private var target = ""
    @State private var parentGoal = ""
    @State private var parentArea = ""
    @State private var template = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New note")
                .font(.title2.bold())
                .foregroundStyle(kind.tint)
            Picker("Type", selection: $kind) {
                Text("Goal").tag(ParaKind.goal)
                Text("Project").tag(ParaKind.project)
                Text("Area").tag(ParaKind.area)
                Text("Resource").tag(ParaKind.resource)
            }
            .pickerStyle(.segmented)
            if kind == .goal {
                Picker("Horizon", selection: $horizon) {
                    ForEach(GoalHorizon.allCases, id: \.self) { h in
                        Text(h.label).tag(h)
                    }
                }
                .pickerStyle(.segmented)
                if horizon != .life {
                    TextField("Target date, e.g. 2028-06-30 (optional)", text: $target)
                        .textFieldStyle(.roundedBorder)
                    let lifeGoals = model.notes.filter { $0.kind == .goal && $0.horizon == .life }
                    if !lifeGoals.isEmpty {
                        Picker("Serves life goal", selection: $parentGoal) {
                            Text("None").tag("")
                            ForEach(lifeGoals) { g in Text(g.title).tag(g.title) }
                        }
                    }
                }
            }
            if choices.count > 1 {
                Picker("Start from", selection: $template) {
                    ForEach(choices) { file in
                        Text(file.isDefault ? "\(file.name) (default)" : file.name).tag(file.name)
                    }
                }
            }
            if kind == .area, !possibleParents.isEmpty {
                Picker("Part of", selection: $parentArea) {
                    Text("Nothing \u{2014} an area of its own").tag("")
                    ForEach(possibleParents) { area in Text(area.displayTitle).tag(area.displayTitle) }
                }
            }
            HStack(spacing: 8) {
                KindBadge(kind: kind, size: 22)
                Text(kind.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(kind.tint)
            }
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit(create)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
        .onAppear {
            if case .kind(let current)? = model.section, current == .area || current == .resource || current == .goal {
                kind = current
            }
            template = choices.first?.name ?? ""
        }
        // Each kind has its own templates, so the choice starts again at its default.
        .onChange(of: kind) { _, _ in template = choices.first?.name ?? "" }
    }

    /// The templates that make this kind of note. More than one and you get to choose.
    private var choices: [TemplateFile] { model.templates(for: kind) }

    /// Areas a new one can be made under. One level, so only the areas that are not
    /// already sub-areas themselves.
    private var possibleParents: [Note] {
        model.index.areaTree().map(\.area).filter { !$0.isArchived }
    }

    private var hint: String {
        switch kind {
        case .project: return "A project has an outcome and an end date. Its tasks are mirrored to a Reminders list with the same name."
        case .area: return "An area is an ongoing responsibility with a standard to maintain. Its tasks are mirrored to Reminders too. Put it under another area to make it a sub-area, like Yoga under Mobility."
        case .goal: return horizon == .life
            ? "A life goal has no date. It gives direction; projects and areas serve it and link back with goal: in their frontmatter."
            : "A dated goal has a target and a measure, and can point at a life goal. Not synced to Reminders; its work lives in projects."
        default: return "A resource is reference material: notes, links, summaries. Link it to projects and areas with [[wikilinks]] or the related: key."
        }
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var extra: [(String, String)] = []
        if kind == .area, !parentArea.isEmpty {
            extra.append(("parent", parentArea))
        }
        if kind == .goal {
            extra.append(("horizon", horizon.rawValue))
            let t = target.trimmingCharacters(in: .whitespaces)
            if horizon != .life, DateOnly(t) != nil { extra.append(("target", t)) }
            if horizon != .life, !parentGoal.isEmpty { extra.append(("goal", parentGoal)) }
        }
        let chosen = choices.contains { $0.name == template } ? template : nil
        model.createNote(kind: kind, title: trimmed, extraFrontmatter: extra, template: chosen)
        dismiss()
    }
}

/// What a `[[link]]` to a note that does not exist yet offers: make that note.
///
/// The title is the link's own words and cannot be changed here — changing it would leave
/// the link pointing at nothing, which is the very thing this sheet is for. All that is left
/// to decide is what kind of note it should be. A link inside a work note makes a work note,
/// so the two sets stay apart without the sheet having to ask.
struct NoteFromLinkSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ParaKind = .resource

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Make this note")
                .font(.title2.bold())
                .foregroundStyle(model.linkToCreate?.isWork == true ? SidebarSection.work.tint : kind.tint)
            Text(linkTitle)
                .font(.title3.weight(.semibold))
                .textSelection(.enabled)
            if model.linkToCreate?.isWork == true {
                Text("A work note, kept with the rest of your work notes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Type", selection: $kind) {
                    Text("Goal").tag(ParaKind.goal)
                    Text("Project").tag(ParaKind.project)
                    Text("Area").tag(ParaKind.area)
                    Text("Resource").tag(ParaKind.resource)
                }
                .pickerStyle(.segmented)
            }
            Text("The link becomes a real link as soon as the note is there.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Create", action: create)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
    }

    private var linkTitle: String { model.linkToCreate?.title ?? "" }

    private func create() {
        model.createNoteFromLink(kind: kind)
        dismiss()
    }

    private func cancel() {
        model.linkToCreate = nil
        dismiss()
    }
}
