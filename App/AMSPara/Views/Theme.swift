import SwiftUI
import AMSParaCore

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

/// The colour of the section you are in, laid over the detail column: a hairline at the top, a
/// wash below it, and the faintest tint over the whole column. Enough to say "you are in
/// Projects" out of the corner of your eye, and not enough to tire you out in a long note.
struct ModeAccent: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(alignment: .top) {
                ZStack(alignment: .top) {
                    // The whole column, just enough to colour the air in it.
                    tint.opacity(0.055)
                    // A little more at the top, gone before it reaches the text.
                    LinearGradient(colors: [tint.opacity(0.10), tint.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 180)
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(tint.opacity(0.6))
                    .frame(height: 2)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Marks a column with the colour of the section it belongs to.
    func modeAccent(_ tint: Color) -> some View { modifier(ModeAccent(tint: tint)) }
}
