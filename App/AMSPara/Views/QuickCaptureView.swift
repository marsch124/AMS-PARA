import SwiftUI
import AMSParaCore

/// The capture panel used by the menu bar item, the in-app sheet (⇧⌘N) and the share extension.
struct QuickCaptureView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var compact = false
    var onSaved: (() -> Void)? = nil

    @State private var text = ""
    @State private var target: CaptureTarget = .inbox
    @State private var asNote = false
    @State private var confirmation: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Quick capture", systemImage: "tray.and.arrow.down")
                    .font(.headline)
                Spacer()
                if let confirmation {
                    Text(confirmation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            TextField("What's on your mind? Use >2026-09-10, !! and #tags as in a note.", text: $text, axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(save)
            HStack {
                Picker("Save to", selection: $target) {
                    ForEach(model.captureTargets, id: \.self) { t in
                        Text(model.captureTargetLabel(t)).tag(t)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                Toggle("As note, not task", isOn: $asNote)
                    .font(.caption)
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
                Spacer()
                if !compact {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if model.vault == nil {
                Text("No vault is open. Captures are kept and filed the next time the app opens a vault.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 12 : 20)
        .frame(width: compact ? 380 : 460)
        .onAppear { focused = true }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.capture(text: trimmed, target: target, asTask: !asNote)
        text = ""
        withAnimation { confirmation = model.lastCaptureMessage ?? "Saved" }
        onSaved?()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation { confirmation = nil }
            if !compact { dismiss() }
        }
    }
}
