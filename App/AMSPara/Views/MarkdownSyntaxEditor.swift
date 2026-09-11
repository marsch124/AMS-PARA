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
    /// Where a half-typed `[[link]]` is, and where on screen it is being typed, so the note
    /// screen can put the list of titles under the cursor. Nil when nothing is being typed.
    @Binding var linkDraft: LinkDraftOnScreen?
    /// Set by the note screen to put a chosen title in and move the cursor past it.
    @Binding var completion: LinkCompletion?
    /// A ⌘-click (a tap on the phone) on a finished `[[link]]`.
    var openLink: (String) -> Void = { _ in }
    /// The keys the list of titles wants while it is up. True means it was used.
    var onLinkKey: (LinkKey) -> Bool = { _ in false }
    /// Whether the text scrolls inside itself. False makes it ask for its full height and
    /// leaves the scrolling to whatever it is placed in — what the phone wants, so a tap is
    /// a tap rather than an argument between two scroll views. macOS ignores it: there the
    /// text view lives in its own NSScrollView, which builds 30/34 require.
    var scrolls: Bool = true

    init(text: Binding<String>,
         tint: Color = .accentColor,
         linkDraft: Binding<LinkDraftOnScreen?> = .constant(nil),
         completion: Binding<LinkCompletion?> = .constant(nil),
         openLink: @escaping (String) -> Void = { _ in },
         onLinkKey: @escaping (LinkKey) -> Bool = { _ in false },
         scrolls: Bool = true) {
        _text = text
        self.tint = tint
        _linkDraft = linkDraft
        _completion = completion
        self.openLink = openLink
        self.onLinkKey = onLinkKey
        self.scrolls = scrolls
    }

    var body: some View {
        MarkdownTextViewRepresentable(text: $text, tint: tint, linkDraft: $linkDraft,
                                      completion: $completion, openLink: openLink,
                                      onLinkKey: onLinkKey, scrolls: scrolls)
    }
}

/// The keys the list of titles answers to.
enum LinkKey { case up, down, enter, escape }

/// A `[[` being typed, and the caret's place in the editor's own coordinates.
struct LinkDraftOnScreen: Equatable {
    let draft: WikiLinks.Draft
    /// The caret, from the top left of the editor.
    let caret: CGPoint
    /// How tall the line is, so the list can sit just below it.
    let lineHeight: CGFloat
}

/// A title the note screen wants written into the text.
struct LinkCompletion: Equatable {
    let draft: WikiLinks.Draft
    let title: String
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
/// An NSTextView that reports a ⌘-click. Plain clicks are left alone: they place the cursor,
/// which is what a text view is for — a link opens on ⌘-click and never by accident.
final class LinkingTextView: NSTextView {
    var onCommandClick: ((Int) -> Void)?

    static func scrollable() -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let old = scrollView.documentView as? NSTextView,
              let container = old.textContainer, let layout = container.layoutManager,
              let storage = layout.textStorage else { return scrollView }
        let textView = LinkingTextView(frame: old.frame, textContainer: container)
        textView.autoresizingMask = old.autoresizingMask
        textView.minSize = old.minSize
        textView.maxSize = old.maxSize
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        _ = storage
        scrollView.documentView = textView
        return scrollView
    }

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let offset = characterIndexForInsertion(at: point)
        onCommandClick?(offset)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        // A pointing hand over every link, so it is plain they can be opened.
        guard let layout = layoutManager, let container = textContainer else { return }
        for match in WikiLinks.matches(in: string) {
            let glyphs = layout.glyphRange(forCharacterRange: match.range, actualCharacterRange: nil)
            var rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
            rect.origin.x += textContainerInset.width
            rect.origin.y += textContainerInset.height
            addCursorRect(rect, cursor: .pointingHand)
        }
    }
}

struct MarkdownTextViewRepresentable: NSViewRepresentable {
    @Binding var text: String
    var tint: Color
    @Binding var linkDraft: LinkDraftOnScreen?
    @Binding var completion: LinkCompletion?
    var openLink: (String) -> Void
    var onLinkKey: (LinkKey) -> Bool
    /// Taken so both platforms have the same shape; the Mac's editor always scrolls.
    var scrolls: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, linkDraft: $linkDraft, openLink: openLink, onLinkKey: onLinkKey)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = LinkingTextView.scrollable()
        guard let textView = scrollView.documentView as? LinkingTextView else { return scrollView }
        textView.onCommandClick = { [weak coordinator = context.coordinator] offset in
            coordinator?.commandClicked(at: offset)
        }
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
        context.coordinator.linkDraft = $linkDraft
        context.coordinator.openLink = openLink
        context.coordinator.onLinkKey = onLinkKey
        // A title picked from the list: written in here, where the text view is, so undo and
        // the cursor behave as they would for typing.
        if let completion, !context.coordinator.applying {
            // Writing the text sends the delegate off through its callbacks, and anything that
            // published state from there would be publishing inside a SwiftUI update — which
            // is a spin, not a crash, and looks like a beachball (build 116). The flag keeps
            // the coordinator quiet until this pass is over.
            context.coordinator.applying = true
            let done = WikiLinks.completing(textView.string, draft: completion.draft, with: completion.title)
            textView.string = done.text
            textView.setSelectedRange(NSRange(location: min(done.cursor, (done.text as NSString).length), length: 0))
            context.coordinator.highlight(tint: NSColor(tint))
            let finished = done.text
            DispatchQueue.main.async {
                self.text = finished
                self.completion = nil
                self.linkDraft = nil
                context.coordinator.applying = false
            }
            return
        }
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
        var linkDraft: Binding<LinkDraftOnScreen?>
        var openLink: (String) -> Void
        var onLinkKey: (LinkKey) -> Bool
        /// True while a chosen title is being written in: nothing is reported meanwhile.
        var applying = false
        weak var textView: NSTextView?

        init(text: Binding<String>, linkDraft: Binding<LinkDraftOnScreen?>,
             openLink: @escaping (String) -> Void, onLinkKey: @escaping (LinkKey) -> Bool) {
            self.text = text
            self.linkDraft = linkDraft
            self.openLink = openLink
            self.onLinkKey = onLinkKey
        }

        /// While the list of titles is up it gets the arrow keys, Return and Escape. Anything
        /// else, and anything it does not use, goes on to do its ordinary job.
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard linkDraft.wrappedValue != nil else { return false }
            switch selector {
            case #selector(NSResponder.moveDown(_:)): return onLinkKey(.down)
            case #selector(NSResponder.moveUp(_:)): return onLinkKey(.up)
            case #selector(NSResponder.insertNewline(_:)): return onLinkKey(.enter)
            case #selector(NSResponder.cancelOperation(_:)): return onLinkKey(.escape)
            default: return false
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            if text.wrappedValue != textView.string { text.wrappedValue = textView.string }
            highlight(tint: nil)
            reportDraft()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            reportDraft()
        }

        func commandClicked(at offset: Int) {
            guard let textView, let title = WikiLinks.link(at: offset, in: textView.string) else { return }
            openLink(title)
        }

        /// Tells the note screen what is being typed and where the caret is. Reading only:
        /// nothing here changes the text, so typing is never interrupted.
        private func reportDraft() {
            guard !applying, let textView, let layout = textView.layoutManager,
                  let container = textView.textContainer else { return }
            let selected = textView.selectedRange()
            guard selected.length == 0,
                  let draft = WikiLinks.draft(in: textView.string, cursor: selected.location) else {
                publish(nil)
                return
            }
            let glyph = layout.glyphRange(forCharacterRange: NSRange(location: selected.location, length: 0),
                                          actualCharacterRange: nil)
            var rect = layout.boundingRect(forGlyphRange: glyph, in: container)
            rect.origin.x += textView.textContainerInset.width
            rect.origin.y += textView.textContainerInset.height
            // Minus how far the view is scrolled: the list is placed over the editor, not over
            // the document.
            let scrolled = textView.enclosingScrollView?.contentView.bounds.origin.y ?? 0
            let onScreen = LinkDraftOnScreen(draft: draft,
                                             caret: CGPoint(x: rect.minX, y: rect.minY - scrolled),
                                             lineHeight: max(rect.height, 16))
            publish(onScreen)
        }

        /// Never straight away: a delegate callback can happen inside a SwiftUI update, and
        /// state written there sends the two of them round in circles.
        private func publish(_ value: LinkDraftOnScreen?) {
            guard linkDraft.wrappedValue != value else { return }
            DispatchQueue.main.async { [self] in
                if linkDraft.wrappedValue != value { linkDraft.wrappedValue = value }
            }
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
    @Binding var linkDraft: LinkDraftOnScreen?
    @Binding var completion: LinkCompletion?
    var openLink: (String) -> Void
    var onLinkKey: (LinkKey) -> Bool
    var scrolls: Bool = true

    /// The floor under everything below. Build 123 let the text view ask for its own height
    /// and it asked for none, so a note could not be edited at all: SwiftUI does not lay a
    /// `UIViewRepresentable` out from `intrinsicContentSize`, and nothing else claimed a
    /// height either. Whatever the measuring does now, it can never come out shorter than
    /// the box the editor has always had.
    static let leastHeight: CGFloat = 320

    /// Asked by SwiftUI how tall this wants to be. Only answered when the text does not
    /// scroll itself; a scrolling text view takes whatever it is given, as it always has.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard !scrolls else { return nil }
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, Self.leastHeight))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, linkDraft: $linkDraft, openLink: openLink)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        // A tap on a link opens it; anywhere else the tap belongs to the text view, so the
        // recogniser gives way rather than competing with it.
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        textView.addGestureRecognizer(tap)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.isScrollEnabled = scrolls
        textView.alwaysBounceVertical = scrolls
        textView.text = text
        context.coordinator.textView = textView
        context.coordinator.highlight(tint: UIColor(tint))
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.isScrollEnabled != scrolls { textView.isScrollEnabled = scrolls }
        context.coordinator.text = $text
        context.coordinator.linkDraft = $linkDraft
        context.coordinator.openLink = openLink
        if let completion, !context.coordinator.applying {
            context.coordinator.applying = true
            let done = WikiLinks.completing(textView.text, draft: completion.draft, with: completion.title)
            textView.text = done.text
            textView.selectedRange = NSRange(location: min(done.cursor, (done.text as NSString).length), length: 0)
            context.coordinator.highlight(tint: UIColor(tint))
            let finished = done.text
            DispatchQueue.main.async {
                self.text = finished
                self.completion = nil
                self.linkDraft = nil
                context.coordinator.applying = false
            }
            return
        }
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
        var linkDraft: Binding<LinkDraftOnScreen?>
        var openLink: (String) -> Void
        /// True while a chosen title is being written in: nothing is reported meanwhile.
        var applying = false
        weak var textView: UITextView?
        private var lastTint: UIColor = .tintColor

        init(text: Binding<String>, linkDraft: Binding<LinkDraftOnScreen?>, openLink: @escaping (String) -> Void) {
            self.text = text
            self.linkDraft = linkDraft
            self.openLink = openLink
        }

        func textViewDidChange(_ textView: UITextView) {
            if text.wrappedValue != textView.text { text.wrappedValue = textView.text }
            highlight(tint: nil)
            reportDraft()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            reportDraft()
        }

        @objc func handleTap(_ recogniser: UITapGestureRecognizer) {
            guard let textView else { return }
            let point = recogniser.location(in: textView)
            guard let position = textView.closestPosition(to: point) else { return }
            let offset = textView.offset(from: textView.beginningOfDocument, to: position)
            guard let title = WikiLinks.link(at: offset, in: textView.text) else { return }
            openLink(title)
        }

        /// Reading only: what is being typed and where the caret is.
        private func reportDraft() {
            guard !applying, let textView else { return }
            let selected = textView.selectedRange
            guard selected.length == 0,
                  let draft = WikiLinks.draft(in: textView.text, cursor: selected.location),
                  let position = textView.position(from: textView.beginningOfDocument, offset: selected.location) else {
                publish(nil)
                return
            }
            let caret = textView.caretRect(for: position)
            let onScreen = LinkDraftOnScreen(draft: draft,
                                             caret: CGPoint(x: caret.minX, y: caret.minY - textView.contentOffset.y),
                                             lineHeight: max(caret.height, 16))
            publish(onScreen)
        }

        /// Never straight away: see the macOS side. A delegate callback can land inside a
        /// SwiftUI update, and state written there sends the two round in circles.
        private func publish(_ value: LinkDraftOnScreen?) {
            guard linkDraft.wrappedValue != value else { return }
            DispatchQueue.main.async { [self] in
                if linkDraft.wrappedValue != value { linkDraft.wrappedValue = value }
            }
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
