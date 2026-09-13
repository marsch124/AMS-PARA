import Foundation

/// One block of the day's plan: a stretch of time with a name on it.
///
/// A block is deliberately **not** a calendar event and **not** a task. It says where you mean
/// to be, or what you mean to be working on, and nothing outside PARAGON ever sees it. That is
/// the whole difference from the Time Blocks of build 35, which are real events in Apple
/// Calendar.
///
/// They live in the daily note under `## Plan`, as plain markdown you can read and correct by
/// hand in any editor:
///
///     ## Plan
///
///     TB: 09:30-11:00 Deep work on the IM plan
///     TB: 13:00-14:00 Pack for Granden
public struct PlanBlock: Identifiable, Equatable, Sendable {
    /// Minutes since midnight.
    public var start: Int
    public var end: Int
    public var title: String
    /// Where it sits in the day's plan, so a list can address one while it is being edited.
    /// Blocks are always held in order, so this is stable for as long as the plan is.
    public var index: Int

    public init(start: Int, end: Int, title: String, index: Int = 0) {
        self.start = start
        self.end = end
        self.title = title
        self.index = index
    }

    public var id: Int { index }
    /// How long it runs. Never negative: a block that ends before it starts is one minute.
    public var minutes: Int { max(1, end - start) }

    public var startText: String { PlanBlock.clock(start) }
    public var endText: String { PlanBlock.clock(end) }
    /// "09:30 – 11:00"
    public var timeText: String { "\(startText) \u{2013} \(endText)" }

    /// Minutes since midnight as "09:30". Anything past midnight is clamped to the day.
    public static func clock(_ minutes: Int) -> String {
        let m = min(max(minutes, 0), 24 * 60)
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    /// "9:30" or "09:30" as minutes since midnight, or nil.
    public static func minutes(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    /// The line as it is written into the note.
    ///
    /// **`TB:`, not a bullet.** He asked for it in build 152: a `- ` made the plan render as a
    /// bulleted list, which says nothing about what the line is. `TB:` says "time block" and
    /// reads as itself in any editor. Bulleted lines written before that still read — the
    /// parser stayed liberal.
    public var line: String { "\(PlanBlock.prefix) \(startText)-\(endText) \(title)" }

    /// What a written plan line starts with.
    public static let prefix = "TB:"

}

/// Reading and writing the `## Plan` section of a daily note.
///
/// Everything that decides the shape of the stored text is here, in Core, so it can be tested
/// — the lesson of build 146, where `cleanTag` sat in the app and nothing could catch it.
public enum DayPlan {
    public static let heading = "## Plan"

    /// `TB: 09:30-11:00 Title`. Liberal in what it reads: with or without the `TB:`, with or
    /// without a `-` or `*` bullet in front of it (which is how every line written before
    /// build 152 looks), any kind of dash between the times, spaces around it or not, and a
    /// one-digit hour. Strict in what it writes, which is `PlanBlock.line`.
    static let lineRegex = try! NSRegularExpression(
        // The dashes are written out as themselves: a Swift raw string passes a backslash-u
        // escape through as plain characters, so escaping here would quietly break the class.
        pattern: #"^\s*(?:[-*]\s*)?(?:[Tt][Bb]:\s*)?(\d{1,2}:\d{2})\s*[-–—]\s*(\d{1,2}:\d{2})\s+(\S.*)$"#)

    /// The blocks in a note, earliest first.
    public static func blocks(in note: Note) -> [PlanBlock] {
        var found: [PlanBlock] = []
        for line in section(of: note.body).lines {
            let ns = line as NSString
            guard let match = lineRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
                  let start = PlanBlock.minutes(from: ns.substring(with: match.range(at: 1))),
                  let end = PlanBlock.minutes(from: ns.substring(with: match.range(at: 2)))
            else { continue }
            let title = ns.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
            found.append(PlanBlock(start: start, end: max(end, start), title: title))
        }
        return numbered(found)
    }

    /// The note with its plan replaced. The section is made when it is missing, above
    /// `## Tasks` so the day reads as plan-then-work; everything else in the note is untouched.
    public static func note(_ note: Note, settingBlocks blocks: [PlanBlock]) -> Note {
        var updated = note
        let written = numbered(blocks).map(\.line)
        var lines = note.body.components(separatedBy: "\n")
        let found = section(of: note.body)

        if let range = found.range {
            var replacement = written
            // Keep a blank line under the heading and one after the last block, so the
            // section still reads as markdown when nothing is in it.
            replacement.insert("", at: 0)
            replacement.append("")
            lines.replaceSubrange(range, with: replacement)
        } else {
            var block = [heading, ""]
            block.append(contentsOf: written)
            block.append("")
            let at = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("## ") } ?? lines.count
            lines.insert(contentsOf: block, at: at)
        }
        updated.body = lines.joined(separator: "\n")
        return updated
    }

    /// The lines inside `## Plan`, and where they sit in the body.
    private static func section(of body: String) -> (lines: [String], range: Range<Int>?) {
        let lines = body.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).lowercased() == heading.lowercased() })
        else { return ([], nil) }
        var end = start + 1
        while end < lines.count, !lines[end].trimmingCharacters(in: .whitespaces).hasPrefix("## ") {
            end += 1
        }
        let inside = (start + 1)..<end
        return (Array(lines[inside]), inside)
    }

    /// Sorted by start and renumbered, which is the only order a plan is ever held in.
    private static func numbered(_ blocks: [PlanBlock]) -> [PlanBlock] {
        blocks.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
            .enumerated()
            .map { index, block in
                var copy = block
                copy.index = index
                return copy
            }
    }
}

public extension Note {
    /// The day's plan, earliest first. Empty for any note without a `## Plan` section.
    var planBlocks: [PlanBlock] { DayPlan.blocks(in: self) }

    /// This note with its plan replaced.
    func settingPlanBlocks(_ blocks: [PlanBlock]) -> Note { DayPlan.note(self, settingBlocks: blocks) }

    /// This note with one more block in its plan.
    func addingPlanBlock(_ block: PlanBlock) -> Note { settingPlanBlocks(planBlocks + [block]) }

    /// This note with the block at `index` taken out.
    func removingPlanBlock(at index: Int) -> Note {
        var blocks = planBlocks
        guard blocks.indices.contains(index) else { return self }
        blocks.remove(at: index)
        return settingPlanBlocks(blocks)
    }
}

/// The tie between a plan block and an event in Apple Calendar.
///
/// A plan block normally never leaves PARAGON, and that is still the default. This is the one
/// way out, taken one block at a time and only when he asks for it: the event carries a line in
/// its own notes naming the day, the start and the title it was made from, and that line is the
/// whole of what is stored. Nothing is written into the daily note.
///
/// **The key is the block's own identity, not a minted id.** There is nowhere on a plain
/// `- 09:30-11:00 Title` line to keep an id without changing what the file looks like, and the
/// file staying plain is the point of the whole feature. Every change made through the app
/// rewrites the line and the event's key in the same step, so the two keep up with each other.
/// A line edited **by hand** in the note loses the tie; the event is then left where it is in
/// Apple Calendar rather than deleted, and the planner says so instead of going quiet.
public enum PlanBlockLink {
    public static let marker = "ams-para:planblock"

    /// What is written into the event's notes to say which block it came from.
    public static func key(for block: PlanBlock, on day: DateOnly) -> String {
        "\(marker) \(day) \(block.startText) \(block.title)"
    }

    /// The key held in an event's notes, or nil when it holds none.
    public static func key(inNotes notes: String) -> String? {
        notes.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix(marker + " ") }
    }

    /// The whole notes body for such an event: a sentence for anyone who opens it in Calendar,
    /// then the key.
    public static func notes(for block: PlanBlock, on day: DateOnly) -> String {
        "From the plan in your PARAGON daily note.\n\(key(for: block, on: day))"
    }

    /// True when the event's notes name this block.
    public static func belongs(_ notes: String, to block: PlanBlock, on day: DateOnly) -> Bool {
        key(inNotes: notes) == key(for: block, on: day)
    }
}
