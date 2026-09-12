import Foundation

/// How far the work under a goal has come.
///
/// Rolled up from the projects that serve the goal, and from the dated goals that serve it:
/// an aspiration is reached through its goals, and those through their projects.
public struct GoalProgress: Equatable, Sendable {
    /// Finished projects under this goal, and how many projects there are in all.
    public var projectsDone: Int
    public var projectsTotal: Int
    /// Top-level tasks in those projects, cancelled ones left out. These are the real counts:
    /// a finished project with three boxes still open contributes them as open, even though
    /// the project itself counts as a whole one done.
    public var tasksDone: Int
    public var tasksTotal: Int
    /// 0 to 1, or nil when there is nothing under this goal to measure.
    public var fraction: Double?

    public init(projectsDone: Int = 0, projectsTotal: Int = 0, tasksDone: Int = 0, tasksTotal: Int = 0, fraction: Double? = nil) {
        self.projectsDone = projectsDone
        self.projectsTotal = projectsTotal
        self.tasksDone = tasksDone
        self.tasksTotal = tasksTotal
        self.fraction = fraction
    }

    /// Nothing under this goal can be measured yet.
    public static let nothing = GoalProgress()

    /// Whole per cent, for the label beside the bar.
    public var percent: Int? {
        guard let fraction else { return nil }
        let rounded = Int((fraction * 100).rounded())
        // Never say 100 until it really is finished, and never say 0 once something has
        // moved. Both are read as an answer, not as a rounding.
        if rounded >= 100, fraction < 1 { return 99 }
        if rounded <= 0, fraction > 0 { return 1 }
        return rounded
    }
}

public extension Note {
    /// The kind this note says it is, which survives a move into the Archive folder.
    /// `kind` is the folder the file sits in, so an archived project comes back as `.archive`
    /// and would otherwise drop out of everything its goal counts.
    var declaredKind: ParaKind {
        frontmatter.string("type")
            .flatMap { ParaKind(rawValue: $0.trimmingCharacters(in: .whitespaces).lowercased()) } ?? kind
    }

    /// A project that is over. The status is what says so, not the boxes: he marks a project
    /// done from the review, and the last task is often one he decided not to do.
    var isFinishedProject: Bool {
        guard declaredKind == .project, let status else { return false }
        return status == "done" || status == "completed" || status == "achieved"
    }
}

public extension NoteIndex {
    /// Every note whose `goal:` resolves to this goal — archived and finished ones included.
    /// `serving(_:)` is the active subset of this. The roll-up needs the finished work too, or
    /// a goal whose projects are all done would read as having nothing under it at all.
    func linked(to goal: Note) -> [Note] {
        notes.filter { candidate in
            candidate.relativePath != goal.relativePath &&
            candidate.goal.map { self.goal(matching: $0)?.relativePath == goal.relativePath } == true
        }
    }

    /// How far this goal has come, rolled up from what serves it.
    func progress(of goal: Note) -> GoalProgress {
        progress(of: goal, visited: [])
    }

    private func progress(of goal: Note, visited: Set<String>) -> GoalProgress {
        // Two goals pointing at each other would otherwise never stop.
        guard !visited.contains(goal.relativePath) else { return .nothing }
        var seen = visited
        seen.insert(goal.relativePath)

        var out = GoalProgress.nothing
        // One share per project, whatever its size: a project with forty small tasks must not
        // drown one with three big ones. The goal's figure is the average of the shares.
        var shares: [Double] = []
        for note in linked(to: goal) {
            // An archived note that was never marked done was dropped, not left undone.
            // Leave it out rather than hold its goal at zero for ever. A finished one counts.
            if note.isArchived, !note.isFinishedProject { continue }
            switch note.declaredKind {
            case .project:
                out.projectsTotal += 1
                let counts = note.progress
                out.tasksDone += counts.done
                out.tasksTotal += counts.total
                if note.isFinishedProject {
                    out.projectsDone += 1
                    shares.append(1)
                } else {
                    shares.append(counts.total > 0 ? Double(counts.done) / Double(counts.total) : 0)
                }
            case .goal:
                let inner = progress(of: note, visited: seen)
                out.projectsDone += inner.projectsDone
                out.projectsTotal += inner.projectsTotal
                out.tasksDone += inner.tasksDone
                out.tasksTotal += inner.tasksTotal
                // A goal with nothing under it is left out rather than counted as zero:
                // there is nothing to measure, which is not the same as no progress.
                if let fraction = inner.fraction { shares.append(fraction) }
            default:
                // An area is deliberately left out. It is a standing responsibility with no
                // end, so it can never be finished, and counting one would hold its goal
                // below full for ever.
                break
            }
        }
        out.fraction = shares.isEmpty ? nil : shares.reduce(0, +) / Double(shares.count)
        return out
    }
}
