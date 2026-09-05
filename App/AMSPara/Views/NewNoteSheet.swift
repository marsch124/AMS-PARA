import SwiftUI
import AMSParaCore

struct NewNoteSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ParaKind = .project
    @State private var title = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New note")
                .font(.title2.bold())
                .foregroundStyle(kind.tint)
            Picker("Type", selection: $kind) {
                Text("Project").tag(ParaKind.project)
                Text("Area").tag(ParaKind.area)
                Text("Resource").tag(ParaKind.resource)
            }
            .pickerStyle(.segmented)
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
            if case .kind(let current)? = model.section, current == .area || current == .resource {
                kind = current
            }
        }
    }

    private var hint: String {
        switch kind {
        case .project: return "A project has an outcome and an end date. Its tasks are mirrored to a Reminders list with the same name."
        case .area: return "An area is an ongoing responsibility with a standard to maintain. Its tasks are mirrored to Reminders too."
        default: return "A resource is reference material: notes, links, summaries. Link it to projects and areas with [[wikilinks]] or the related: key."
        }
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        model.createNote(kind: kind, title: trimmed)
        dismiss()
    }
}
