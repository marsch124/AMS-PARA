import Foundation

/// Hides the `^tXXXXXX` sync markers while a note is being edited, and puts them back
/// afterwards. The markers stay in the file, so NotePlan and the Reminders sync keep
/// working, but they cannot be selected or deleted by accident.
///
/// Restoring works on the text the editor started from: unchanged task lines keep their
/// marker by matching their text, and a task whose text was edited keeps it through its
/// position between the unchanged ones. A task that was added gets no marker (the sync
/// assigns one); a task that was deleted takes its marker with it.
public enum TaskIDMasking {
    /// The text as shown in the editor.
    public static func hidden(in text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard lines.contains(where: { stripped($0) != nil }) else { return text }
        return lines.map { stripped($0) ?? $0 }.joined(separator: "\n")
    }

    /// The text to write to disk, given what the editor shows and what it started from.
    public static func restored(_ edited: String, from original: String) -> String {
        var editedLines = edited.components(separatedBy: "\n")
        let originalLines = original.components(separatedBy: "\n")

        /// Task lines that carried a marker, in order.
        var carriers: [(line: String, id: String)] = []
        for line in originalLines {
            guard let id = TaskParser.parse(line: line)?.id, let bare = stripped(line) else { continue }
            carriers.append((bare, id))
        }
        guard !carriers.isEmpty else { return edited }

        /// Task lines in the editor that have no marker: candidates to receive one.
        var candidates: [Int] = []
        for (i, line) in editedLines.enumerated() {
            guard let task = TaskParser.parse(line: line), task.id == nil else { continue }
            candidates.append(i)
        }
        guard !candidates.isEmpty else { return edited }

        // Anchors: carriers whose text is unchanged, matched to candidates in order so the
        // sequence never crosses itself.
        var anchors: [(carrier: Int, candidate: Int)] = []
        var nextCandidate = 0
        for (c, carrier) in carriers.enumerated() {
            var k = nextCandidate
            while k < candidates.count {
                if editedLines[candidates[k]] == carrier.line {
                    anchors.append((c, k))
                    nextCandidate = k + 1
                    break
                }
                k += 1
            }
        }

        var assignment: [Int: String] = [:]   // line in the edited text -> marker
        for anchor in anchors {
            assignment[candidates[anchor.candidate]] = carriers[anchor.carrier].id
        }

        // Between two anchors, pair what is left over in order: those are edited task lines.
        var carrierCursor = 0
        var candidateCursor = 0
        for boundary in anchors + [(carriers.count, candidates.count)] {
            var c = carrierCursor
            var k = candidateCursor
            while c < boundary.carrier && k < boundary.candidate {
                assignment[candidates[k]] = carriers[c].id
                c += 1
                k += 1
            }
            carrierCursor = boundary.carrier + 1
            candidateCursor = boundary.candidate + 1
        }

        for (line, id) in assignment {
            editedLines[line] = editedLines[line] + " ^" + id
        }
        return editedLines.joined(separator: "\n")
    }

    /// The line without its marker, or nil when it is not a task line carrying one.
    static func stripped(_ line: String) -> String? {
        guard TaskParser.parse(line: line)?.id != nil else { return nil }
        let ns = line as NSString
        let bare = TaskParser.idRegex.stringByReplacingMatches(in: line, range: NSRange(location: 0, length: ns.length), withTemplate: "")
        var out = bare
        while out.hasSuffix(" ") || out.hasSuffix("\t") { out.removeLast() }
        return out
    }
}
