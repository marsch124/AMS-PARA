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
        }
    }

    private var hint: String {
        switch kind {
        case .project: return "A project has an outcome and an end date. Its tasks are mirrored to a Reminders list with the same name."
        case .area: return "An area is an ongoing responsibility with a standard to maintain. Its tasks are mirrored to Reminders too."
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
        if kind == .goal {
            extra.append(("horizon", horizon.rawValue))
            let t = target.trimmingCharacters(in: .whitespaces)
            if horizon != .life, DateOnly(t) != nil { extra.append(("target", t)) }
            if horizon != .life, !parentGoal.isEmpty { extra.append(("goal", parentGoal)) }
        }
        model.createNote(kind: kind, title: trimmed, extraFrontmatter: extra)
        dismiss()
    }
}
