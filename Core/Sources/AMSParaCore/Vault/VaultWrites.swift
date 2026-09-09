import Foundation

/// What became of a change that had to write more than one file.
///
/// Nothing in a vault of plain files can be made truly atomic: each note is its own file and
/// the write of the fifth can fail after the first four are on disk. What can be done is to
/// choose the order so that a failure is harmless, to try again against what is really there,
/// and to say what did not happen instead of letting it pass. That is what this file is for.
public struct MultiSaveResult: Equatable, Sendable {
    /// The notes that were written, by relative path.
    public let saved: [String]
    /// The notes that could not be written and are therefore unchanged.
    public let failed: [String]

    public var isComplete: Bool { failed.isEmpty }

    public init(saved: [String], failed: [String]) {
        self.saved = saved
        self.failed = failed
    }
}

/// The outcome of moving a task from one note to another.
public struct TaskMove: Sendable {
    public let source: Note
    public let target: Note
    /// True when the task reached the target but could not be taken out of the source, so it
    /// is now in both places. It is never in neither: the target is written first.
    public let leftInSource: Bool
}

/// What became of a rename that had to follow the links to it.
public struct NoteRenameResult: Sendable {
    public let renamed: Note
    /// Notes that still name the old title because they could not be written.
    public let staleLinks: [String]
}

public extension Vault {
    /// Applies one change to a set of notes and writes each one. A note that was changed on
    /// disk in the meantime (the other device, another editor) is read again and the same
    /// change made to what is there now, so an outside edit costs nothing; only a note that
    /// still cannot be written is reported as failed. Returning nil from `change` skips the
    /// note without counting as a failure — that is how "this one did not need changing" is
    /// said.
    func saveEach(_ notes: [Note], change: (Note) -> Note?) -> MultiSaveResult {
        var saved: [String] = []
        var failed: [String] = []
        for note in notes {
            guard let updated = change(note) else { continue }
            do {
                _ = try save(updated)
                saved.append(note.relativePath)
            } catch {
                guard let fresh = try? loadNote(relativePath: note.relativePath),
                      let again = change(fresh), (try? save(again)) != nil else {
                    failed.append(note.relativePath)
                    continue
                }
                saved.append(note.relativePath)
            }
        }
        return MultiSaveResult(saved: saved, failed: failed)
    }

    /// Moves a task and its subtasks from one note to another.
    ///
    /// The target is written first on purpose. If that fails, nothing has changed anywhere and
    /// the caller can simply say so; if the source cannot be written afterwards the task is in
    /// both notes, which is visible and can be tidied up. The other order would lose it.
    func move(task: TaskItem, from source: Note, to target: Note) throws -> TaskMove {
        var source = source
        var target = target
        guard let block = source.removeTaskBlock(for: task) else {
            throw VaultError.taskNotFound(task.title)
        }
        target.appendTaskBlock(block)
        let savedTarget = try save(target)
        do {
            return TaskMove(source: try save(source), target: savedTarget, leftInSource: false)
        } catch {
            // The source changed under us. Take the task out of what is there now instead.
            if var fresh = try? loadNote(relativePath: source.relativePath),
               fresh.removeTaskBlock(for: task) != nil, let saved = try? save(fresh) {
                return TaskMove(source: saved, target: savedTarget, leftInSource: false)
            }
            return TaskMove(source: source, target: savedTarget, leftInSource: true)
        }
    }

    /// Renames a note and points every reference to it at the new title.
    ///
    /// The note itself is renamed first: if that fails, nothing else has been touched. The
    /// notes that link to it are then rewritten one by one, and any that could not be written
    /// come back in `staleLinks` — they still name the old title, and saying so is better than
    /// leaving the user to find out.
    func rename(_ note: Note, to newTitle: String, updating others: [Note]) throws -> NoteRenameResult {
        let old = note.displayTitle
        let renamed = try rename(note, to: newTitle)
        let new = renamed.displayTitle
        let elsewhere = others.filter { $0.relativePath != note.relativePath }
        let result = saveEach(elsewhere) { $0.retargeting(old, to: new) }
        return NoteRenameResult(renamed: renamed, staleLinks: result.failed)
    }
}
