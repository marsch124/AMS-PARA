import SwiftUI
import AMSParaCore

/// Making a note is nearly always "type a name and press Return", so that is what the sheet
/// is: a name field with the cursor in it, the four kinds in their own colours, one line
/// saying what the chosen kind is for, and everything else — templates, horizons, what it
/// sits under — folded away behind **More**, shut every time it opens (build 119). Nothing
/// was taken away; the nine things it used to ask are just no longer in the way of the one
/// thing it always needs.
struct NewNoteSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ParaKind = .project
    @State private var title = ""
    @State private var horizon: GoalHorizon = .year
    @State private var target = ""
    /// The goal this note serves: a life goal for a dated goal, any goal for a project.
    @State private var servesGoal = ""
    @State private var parentArea = ""
    @State private var template = ""
    @State private var showMore = false
    @FocusState private var nameFocused: Bool

    private static let offered: [ParaKind] = [.goal, .project, .area, .resource]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New \(kind.singularName)")
                .font(.title2.bold())
                .foregroundStyle(kind.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("What is it called?", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit(create)
            }

            HStack(spacing: 6) {
                ForEach(Self.offered, id: \.self) { choice in
                    KindChoice(kind: choice, chosen: kind == choice) { pick(choice) }
                }
            }

            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Only when there is something in it. A vault with no goals and one project
            // template has nothing to fold away, and an empty box is worse than no button.
            if hasMoreToOffer {
                Button {
                    showMore.toggle()
                } label: {
                    Label(moreLabel, systemImage: showMore ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help("Templates, and what this note sits under")
            }

            if showMore, hasMoreToOffer {
                moreFields
            }

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
            if case .kind(let current)? = model.section, Self.offered.contains(current) {
                kind = current
            }
            template = choices.first?.name ?? ""
            // The sheet exists to be typed into. Focus does not always take in the same turn
            // the view appears, so it is asked for again on the next one.
            DispatchQueue.main.async { nameFocused = true }
        }
        // Each kind has its own templates, so the choice starts again at its default.
        .onChange(of: kind) { _, _ in template = choices.first?.name ?? "" }
    }

    /// Everything the common case does not need. Whether it is open is never remembered:
    /// on the day you want one of these you know you want it, and every other day it is noise.
    @ViewBuilder
    private var moreFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            if kind == .goal {
                Picker("Horizon", selection: $horizon) {
                    ForEach(GoalHorizon.allCases, id: \.self) { h in
                        Text(h.label).tag(h)
                    }
                }
                if horizon != .life {
                    TextField("Target date, e.g. 2028-06-30", text: $target)
                        .textFieldStyle(.roundedBorder)
                    if !lifeGoals.isEmpty {
                        Picker("Serves life goal", selection: $servesGoal) {
                            Text("None").tag("")
                            ForEach(lifeGoals) { goal in Text(goal.title).tag(goal.title) }
                        }
                    }
                }
            }
            if kind == .project, !allGoals.isEmpty {
                Picker("Serves goal", selection: $servesGoal) {
                    Text("None").tag("")
                    ForEach(allGoals) { goal in Text(goal.title).tag(goal.title) }
                }
            }
            if kind == .area, !possibleParents.isEmpty {
                Picker("Part of", selection: $parentArea) {
                    Text("Nothing \u{2014} an area of its own").tag("")
                    ForEach(possibleParents) { area in Text(area.displayTitle).tag(area.displayTitle) }
                }
            }
            if choices.count > 1 {
                Picker("Start from", selection: $template) {
                    ForEach(choices) { file in
                        Text(file.isDefault ? "\(file.name) (default)" : file.name).tag(file.name)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    /// Switching kind starts the extras again: a goal picked for a project must not follow
    /// you to an area, and the dashed panel would otherwise show a choice you never made.
    private func pick(_ choice: ParaKind) {
        guard choice != kind else { return }
        kind = choice
        servesGoal = ""
        parentArea = ""
        target = ""
        nameFocused = true
    }

    /// The templates that make this kind of note. More than one and you get to choose.
    private var choices: [TemplateFile] { model.templates(for: kind) }

    private var lifeGoals: [Note] { model.notes.filter { $0.kind == .goal && $0.horizon == .life } }
    private var allGoals: [Note] { model.notes.filter { $0.kind == .goal && !$0.isArchived } }

    /// Areas a new one can be made under. One level, so only the areas that are not
    /// already sub-areas themselves.
    private var possibleParents: [Note] {
        model.index.areaTree().map(\.area).filter { !$0.isArchived }
    }

    /// Whether More has anything in it at all, so it never opens onto an empty box.
    private var hasMoreToOffer: Bool {
        if choices.count > 1 { return true }
        switch kind {
        case .goal: return true
        case .project: return !allGoals.isEmpty
        case .area: return !possibleParents.isEmpty
        default: return false
        }
    }

    /// One sentence. The full description of each kind lives in the manual, which is
    /// searchable; a paragraph here was read once and skipped ever after.
    private var hint: String {
        switch kind {
        case .project: return "An outcome with an end. Its tasks are mirrored to a Reminders list of the same name."
        case .area: return "An ongoing responsibility with a standard to keep. Its tasks go to Reminders too."
        case .goal: return horizon == .life
            ? "A direction, not a task list. Never synced to Reminders; the work lives in projects that point at it."
            : "A goal with a date and a measure. Not synced to Reminders; its work lives in projects."
        default: return "Reference material. No dates, no Reminders \u{2014} link it from wherever it is useful with [[brackets]]."
        }
    }

    /// Naming what is inside is what makes a folded section worth opening.
    private var moreLabel: String {
        switch kind {
        case .goal: return "More \u{2014} horizon, target date, life goal\u{2026}"
        case .project: return "More \u{2014} template, goal it serves\u{2026}"
        case .area: return "More \u{2014} part of, template\u{2026}"
        default: return "More \u{2014} template\u{2026}"
        }
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var extra: [(String, String)] = []
        if kind == .area, !parentArea.isEmpty {
            extra.append(("parent", parentArea))
        }
        if kind == .project, !servesGoal.isEmpty {
            extra.append(("goal", servesGoal))
        }
        if kind == .goal {
            extra.append(("horizon", horizon.rawValue))
            let t = target.trimmingCharacters(in: .whitespaces)
            if horizon != .life, DateOnly(t) != nil { extra.append(("target", t)) }
            if horizon != .life, !servesGoal.isEmpty { extra.append(("goal", servesGoal)) }
        }
        let chosen = choices.contains { $0.name == template } ? template : nil
        model.createNote(kind: kind, title: trimmed, extraFrontmatter: extra, template: chosen)
        dismiss()
    }
}

/// One of the four kinds, in its own colour. A row of these rather than a segmented picker:
/// the colours are the same ones the sidebar and the map use, so the choice is recognised
/// rather than read.
private struct KindChoice: View {
    let kind: ParaKind
    let chosen: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            VStack(spacing: 5) {
                KindBadge(kind: kind, size: 16)
                    .opacity(chosen ? 1 : 0.45)
                Text(kind.singularName.capitalized)
                    .font(.caption)
                    .fontWeight(chosen ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(chosen ? kind.tint : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(chosen ? kind.tint : Color.secondary.opacity(0.3), lineWidth: chosen ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("Make a \(kind.singularName)")
    }
}

extension ParaKind {
    /// "project", not "Projects". `displayName` names the list a note lands in, which is the
    /// wrong word for the single note you are about to make.
    var singularName: String {
        switch self {
        case .inbox: return "inbox note"
        case .project: return "project"
        case .area: return "area"
        case .resource: return "resource"
        case .archive: return "archived note"
        case .daily: return "daily note"
        case .goal: return "goal"
        }
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
