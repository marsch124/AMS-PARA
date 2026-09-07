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
