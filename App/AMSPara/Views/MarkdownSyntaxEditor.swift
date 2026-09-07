import SwiftUI
import AMSParaCore

#if os(macOS)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
#endif

/// The note editor: an ordinary text view that draws markdown as you type. Headings grow,
/// tasks get a coloured box, finished ones are struck through, and the syntax characters
/// fade into the background. The text itself is never changed, only how it looks.
struct MarkdownSyntaxEditor: View {
    @Binding var text: String
    var tint: Color = .accentColor

    var body: some View {
        MarkdownTextViewRepresentable(text: $text, tint: tint)
    }
}

/// Turns the spans from the Core highlighter into text attributes.
enum MarkdownAttributes {
    static let baseSize: CGFloat = 14
    static let lineSpacing: CGFloat = 3.5

    static var baseFont: PlatformFont { .systemFont(ofSize: baseSize) }
    static var monospaceFont: PlatformFont { .monospacedSystemFont(ofSize: baseSize - 1, weight: .regular) }

    static func headingFont(level: Int) -> PlatformFont {
        let sizes: [CGFloat] = [baseSize + 9, baseSize + 6, baseSize + 3, baseSize + 1, baseSize, baseSize]
        let size = sizes[min(max(level, 1), 6) - 1]
        return .systemFont(ofSize: size, weight: level <= 2 ? .bold : .semibold)
    }

    static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = 2
        return style
    }

    /// The attributes every character starts with.
    static func base(color: PlatformColor) -> [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: color, .paragraphStyle: paragraphStyle]
    }

    /// Applies the highlighting for `text` to a text storage that already holds it.
    static func apply(to storage: NSTextStorage, text: String, tint: PlatformColor,
                      primary: PlatformColor, secondary: PlatformColor, faint: PlatformColor) {
        let whole = NSRange(location: 0, length: (text as NSString).length)
        storage.beginEditing()
        storage.setAttributes(base(color: primary), range: whole)
        // Very long notes are left plain: highlighting every keystroke would drag.
        if whole.length <= 200_000 {
            for span in MarkdownHighlight.spans(in: text) {
                guard span.range.location >= 0, NSMaxRange(span.range) <= whole.length, span.range.length > 0 else { continue }
                storage.addAttributes(attributes(for: span.style, tint: tint, secondary: secondary, faint: faint), range: span.range)
            }
        }
        storage.endEditing()
    }

    private static func attributes(for style: MarkdownStyle, tint: PlatformColor,
                                   secondary: PlatformColor, faint: PlatformColor) -> [NSAttributedString.Key: Any] {
        switch style {
        case .heading(let level):
            return [.font: headingFont(level: level)]
        case .marker:
            return [.foregroundColor: faint]
        case .bold:
            return [.font: PlatformFont.systemFont(ofSize: baseSize, weight: .semibold)]
        case .italic:
            return [.obliqueness: 0.18]
        case .code, .frontmatter:
            return [.font: monospaceFont, .foregroundColor: secondary]
        case .link:
            return [.foregroundColor: tint]
        case .finished:
            return [.foregroundColor: secondary,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: secondary]
        case .dueDate:
            return [.foregroundColor: tint, .font: PlatformFont.monospacedDigitSystemFont(ofSize: baseSize - 1, weight: .regular)]
        case .priority:
            return [.foregroundColor: PlatformColor.systemOrange,
                    .font: PlatformFont.systemFont(ofSize: baseSize, weight: .bold)]
        case .tag:
            return [.foregroundColor: tint]
        case .quote:
            return [.foregroundColor: secondary, .obliqueness: 0.12]
        case .rule:
            return [.foregroundColor: faint]
        }
    }
}

// MARK: - The platform text view

#if os(macOS)
struct MarkdownTextViewRepresentable: NSViewRepresentable {
    @Binding var text: String
    var tint: Color

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.drawsBackground = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.highlight(tint: NSColor(tint))
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        // Only when the text really came from somewhere else, so typing is never interrupted.
        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selected.location, length), length: 0))
        }
        context.coordinator.highlight(tint: NSColor(tint))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            if text.wrappedValue != textView.string { text.wrappedValue = textView.string }
            highlight(tint: nil)
        }

        private var lastTint: NSColor = .controlAccentColor

        func highlight(tint: NSColor?) {
            guard let textView, let storage = textView.textStorage else { return }
            if let tint { lastTint = tint }
            MarkdownAttributes.apply(to: storage, text: textView.string, tint: lastTint,
                                     primary: .labelColor, secondary: .secondaryLabelColor, faint: .tertiaryLabelColor)
            textView.typingAttributes = MarkdownAttributes.base(color: .labelColor)
        }
    }
}
#else
struct MarkdownTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    var tint: Color

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.alwaysBounceVertical = true
        textView.text = text
        context.coordinator.textView = textView
        context.coordinator.highlight(tint: UIColor(tint))
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.text = $text
        if textView.text != text {
            let selected = textView.selectedRange
            textView.text = text
            let length = (text as NSString).length
            textView.selectedRange = NSRange(location: min(selected.location, length), length: 0)
        }
        context.coordinator.highlight(tint: UIColor(tint))
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        weak var textView: UITextView?
        private var lastTint: UIColor = .tintColor

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            if text.wrappedValue != textView.text { text.wrappedValue = textView.text }
            highlight(tint: nil)
        }

        func highlight(tint: UIColor?) {
            guard let textView else { return }
            if let tint { lastTint = tint }
            let selected = textView.selectedRange
            MarkdownAttributes.apply(to: textView.textStorage, text: textView.text, tint: lastTint,
                                     primary: .label, secondary: .secondaryLabel, faint: .tertiaryLabel)
            textView.typingAttributes = MarkdownAttributes.base(color: .label)
            textView.selectedRange = selected
        }
    }
}
#endif
