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

    /// The planner's own blocks: orange, at his request in build 152. They used to borrow the
    /// review's teal, which put them in the same family as the Calendar column beside them —
    /// the whole point of the two lanes is that they are different things. One place, so the
    /// lane, the card, the "make a block" buttons and the sheet cannot drift apart.
    static let planBlockTint = Color("PlanTint")
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

/// Lays its children out along a row and starts a new line when the next one will not fit.
///
/// SwiftUI has no flow layout of its own, and an `HStack` in a column too narrow for it does
/// not overflow — it squeezes every child until the text inside wraps. That is how the weekly
/// review came to draw "2031-08-01" over three lines and the word "projects" as "project s"
/// (build 138). Children are measured unconstrained, so each one keeps its natural width and
/// only whole items move down a line.
struct WrappingHStack: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .infinity
        let rows = rows(of: subviews, within: limit)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: limit == .infinity ? widest : min(widest, limit), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(of: subviews, within: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(of subviews: Subviews, within limit: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let wanted = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty, wanted > limit {
                rows.append(row)
                row = Row(indices: [index], width: size.width, height: size.height)
            } else {
                row.indices.append(index)
                row.width = wanted
                row.height = max(row.height, size.height)
            }
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

/// How far the work under a goal has come, drawn the same way everywhere it appears: the
/// weekly review's row, the Goals list, and the goal's own dashboard.
///
/// Nothing is drawn when there is nothing to measure. A goal with no projects under it yet is
/// not at zero per cent — there is no figure at all, and an empty bar would say the opposite.
struct GoalProgressBar: View {
    let progress: GoalProgress
    var width: CGFloat? = nil
    var showsCounts = true

    var body: some View {
        if let fraction = progress.fraction, let percent = progress.percent {
            HStack(spacing: 6) {
                ProgressView(value: fraction)
                    .tint(ParaKind.goal.tint)
                    .frame(width: width)
                Text("\(percent)%")
                    .foregroundStyle(ParaKind.goal.tint)
                if showsCounts {
                    Text(counts)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .lineLimit(1)
        }
    }

    /// Built outside the ViewBuilder, where a `var` is allowed.
    private var counts: String {
        var parts = ["\(progress.projectsDone) of \(progress.projectsTotal) projects done"]
        if progress.tasksTotal > 0 {
            parts.append("\(progress.tasksDone) of \(progress.tasksTotal) tasks")
        }
        return parts.joined(separator: " \u{00b7} ")
    }
}

/// One symbol in two states.
///
/// The mode button used to swap the symbol itself — an eye for Read, a pencil for Edit — and
/// there is no way to read that: an eye means both "you are reading" and "press to read". One
/// symbol that is either lit or not has a single reading, and it is the reading everything
/// else in the app already uses: a tinted fill is "on", grey is "off". The dashed border says
/// the same thing a second way, which is what the Map's dashed boxes have always meant here.
/// The Archive button's symbol: a small arrow coming down into the box, because the button
/// **moves** the note rather than showing an archive. His idea, build 154 — "is it possible to
/// make a small down arrow so that it shows the movement somehow?"
///
/// Drawn here rather than named, because SF Symbols has no archivebox carrying an arrow. A
/// `VStack`, not a `ZStack` with offsets: the two pieces then cannot drift over each other at
/// another text size.
struct MoveToArchiveIcon: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrow.down")
                .font(.system(size: 7, weight: .bold))
            Image(systemName: "archivebox")
                .font(.system(size: 12))
        }
        .frame(height: 21)
        .accessibilityLabel("Move to the Archive")
    }
}

struct StateToggle: View {
    let systemImage: String
    /// What the symbol stands for, e.g. "Edit". Read aloud and shown as the tooltip.
    let title: String
    let isOn: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 26)
                .foregroundStyle(isOn ? tint : Color.primary.opacity(0.62))
                .background { fill }
                .overlay { border }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "\(title), on" : "\(title), off")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .help(isOn ? "\(title) is on. Press to turn it off." : "\(title) is off. Press to turn it on.")
    }

    @ViewBuilder
    private var fill: some View {
        if isOn {
            RoundedRectangle(cornerRadius: 6).fill(tint.opacity(0.24))
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 6)
            // Build 154: both states were too faint to read in a macOS toolbar, which draws
            // everything at low emphasis to begin with. Same two-state language he chose in
            // build 142 — tinted and solid for on, grey and dashed for off — only stronger.
            .strokeBorder(isOn ? tint.opacity(0.7) : Color.primary.opacity(0.3),
                          style: StrokeStyle(lineWidth: isOn ? 1.4 : 1.2, dash: isOn ? [] : [3.5, 2.5]))
    }
}
