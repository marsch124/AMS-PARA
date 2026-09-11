import SwiftUI
import ParagonCore

/// The few numbers and small pieces that keep every screen looking like one app.
enum Theme {
    /// Padding inside a row or a panel.
    static let gutter: CGFloat = 14
    /// Space between a heading and what belongs to it.
    static let tight: CGFloat = 4
    static let gap: CGFloat = 8
    static let radius: CGFloat = 8

    /// The reading font of the note editor: proportional, not code.
    static let editorFont: Font = .system(.body, design: .default)
    static let editorLineSpacing: CGFloat = 3
}

/// A quiet heading above a group, used instead of the default list section titles
/// where a list would be too heavy.
struct SectionLabel: View {
    let title: String
    var count: Int?
    var systemImage: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
            if let count, count > 0 {
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
    }
}

/// What a screen shows when there is nothing in it yet: an icon, a sentence that says
/// what belongs here, and the one button that fills it.
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String
    var tint: Color = .secondary
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(tint.opacity(0.8))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 2)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The line at the foot of the sidebar when the vault is not all readable: notes iCloud has
/// not sent, or files that could not be read at all. It is deliberately hard to miss — an
/// app that quietly draws an empty vault looks exactly like an app that has lost everything.
struct VaultWarningBar: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
            Button("Ask iCloud again", action: retry)
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radius))
        .padding(.horizontal, 8)
    }
}

/// The colour of the section you are in, laid evenly over the detail column. Enough to say
/// "you are in Projects" out of the corner of your eye, and not enough to tire you out in a
/// long note. The hairline along the top went in build 113: it read as a border round the
/// panel rather than as part of it.
struct ModeAccent: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background {
                // One even tint over the whole column, at the strength he picked from the
                // preview. The gradient at the top went out in build 110: he wanted the colour
                // to sit evenly rather than pool under the toolbar.
                tint.opacity(0.085).allowsHitTesting(false)
            }
    }
}

extension View {
    /// Marks a column with the colour of the section it belongs to.
    func modeAccent(_ tint: Color) -> some View { modifier(ModeAccent(tint: tint)) }
}

/// The one way to choose a date in PARAGON: write it, or pick it.
///
/// Both are always offered because the dates this app deals in run from tomorrow to a goal
/// five years out, and a calendar you have to press forty times is no way to reach 2031 —
/// which is exactly what he counted when asked to try the "due after its goal" check
/// (build 136). The field is what **Set** reads; the calendar only writes into it.
///
/// Used by the project deadline in the note header and by a task's date. The New Note sheet's
/// target date is deliberately left as a plain field: that screen was designed with him and
/// takes one short line per row.
struct DateChoiceView: View {
    /// The date already set, if any. It is what the field and the calendar open on.
    let current: DateOnly?
    /// Shown on the clearing button. Leave it nil for no such button.
    var clearTitle: String? = nil
    /// Shown as **Cancel** when given. A sheet needs it; a popover can also be dismissed by
    /// clicking away, but the button does no harm there.
    var cancel: (() -> Void)? = nil
    /// The chosen date, or nil when the clearing button was pressed.
    let choose: (DateOnly?) -> Void

    @State private var typed = ""
    @State private var date = Date()

    private var parsed: DateOnly? { DateOnly(typed.trimmingCharacters(in: .whitespaces)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("2031-12-01", text: $typed)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospacedDigit())
                .onSubmit(set)
            Text(parsed == nil ? "Write the date as 2031-12-01." : "Or pick it below.")
                .font(.caption)
                .foregroundStyle(parsed == nil ? Color.red : Color.secondary)
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .onChange(of: date) { _, picked in typed = DateOnly(picked).description }
            HStack {
                if let clearTitle {
                    Button(clearTitle, role: .destructive) { choose(nil) }
                }
                Spacer()
                if let cancel {
                    Button("Cancel", action: cancel)
                }
                Button("Set", action: set)
                    .keyboardShortcut(.defaultAction)
                    .disabled(parsed == nil)
            }
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            let start = current ?? DateOnly(Date())
            typed = start.description
            date = start.date() ?? Date()
        }
    }

    private func set() {
        guard let parsed else { return }
        choose(parsed)
    }
}
