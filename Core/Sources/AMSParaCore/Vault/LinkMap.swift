import Foundation

/// One box in the link map: a note, an open task, a "+n more" marker, or a group that
/// gathers notes with nothing above them (unlinked notes, loose resources, the archive).
public struct MapNode: Identifiable, Equatable, Sendable {
    public enum Group: String, CaseIterable, Sendable {
        case unlinked
        case resources
        case archive

        public var title: String {
            switch self {
            case .unlinked: return "Not linked to a goal"
            case .resources: return "Resources not linked to anything"
            case .archive: return "Archive and done"
            }
        }
    }

    public enum Content: Equatable, Sendable {
        case note(Note)
        /// An open task and the kind of note it lives in (for its colour).
        case task(TaskRef, noteKind: ParaKind)
        /// Tasks beyond the ones shown, all in the note at this path.
        case more(count: Int, notePath: String)
        case group(Group)
    }

    public var id: String
    public var content: Content
    /// What sits below this node: notes it gathers, then its open tasks and resources.
    public var children: [MapNode]

    public init(id: String, content: Content, children: [MapNode] = []) {
        self.id = id
        self.content = content
        self.children = children
    }

    public var title: String {
        switch content {
        case .note(let note): return note.displayTitle
        case .task(let ref, _): return ref.task.title
        case .more(let count, _): return "+\(count) more"
        case .group(let group): return group.title
        }
    }

    /// The note this node opens: its own, or the one a task or marker belongs to.
    public var notePath: String? {
        switch content {
        case .note(let note): return note.relativePath
        case .task(let ref, _): return ref.notePath
        case .more(_, let path): return path
        case .group: return nil
        }
    }

    public var note: Note? {
        if case .note(let note) = content { return note }
        return nil
    }

    /// Tasks, "+n more" markers and resources are drawn as small chips stacked under their
    /// parent; everything else is a card with its own branch.
    public var isChip: Bool {
        switch content {
        case .task, .more: return true
        case .note(let note): return note.kind == .resource && !note.isArchived
        case .group: return false
        }
    }

    /// The nodes in this subtree, this one first, parents before children.
    public var flattened: [MapNode] {
        [self] + children.flatMap(\.flattened)
    }
}

/// A link that the tree cannot show as a parent: `from` also serves `to`.
public struct MapLink: Hashable, Sendable {
    public var from: String
    public var to: String

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}

/// Everything in the vault arranged top down by what serves what: goals, the subgoals,
/// areas and projects that serve them, the open tasks and resources under those, then the
/// notes that link to nothing and the archive. Built by `NoteIndex.linkMap()`.
public struct LinkMap: Equatable, Sendable {
    public var roots: [MapNode]
    /// Second links that would make the tree a graph: a project under its area that also names
    /// a goal, a resource related to more than one note, an archived note still pointing at a goal.
    public var links: [MapLink]

    private var parentOf: [String: String] = [:]
    private var nodes: [String: MapNode] = [:]

    public init(roots: [MapNode], links: [MapLink] = []) {
        self.roots = roots
        self.links = links
        func visit(_ node: MapNode, parent: String?) {
            nodes[node.id] = node
            if let parent { parentOf[node.id] = parent }
            node.children.forEach { visit($0, parent: node.id) }
        }
        roots.forEach { visit($0, parent: nil) }
    }

    public static func == (a: LinkMap, b: LinkMap) -> Bool {
        a.roots == b.roots && a.links == b.links
    }

    public var isEmpty: Bool { roots.isEmpty }

    public var allNodes: [MapNode] { roots.flatMap(\.flattened) }

    public func node(_ id: String) -> MapNode? { nodes[id] }

    public func parent(of id: String) -> String? { parentOf[id] }

    /// Everything this node serves: its parents up the tree and its second links, transitively.
    /// Groups are left out; they are containers, not things to serve.
    public func upstream(of id: String) -> Set<String> {
        var seen = Set<String>()
        var queue = [id]
        while let current = queue.popLast() {
            var next: [String] = []
            if let parent = parentOf[current] { next.append(parent) }
            next += links.filter { $0.from == current }.map(\.to)
            for candidate in next where !seen.contains(candidate) && candidate != id {
                if let node = nodes[candidate], case .group = node.content { continue }
                seen.insert(candidate)
                queue.append(candidate)
            }
        }
        return seen
    }

    /// Everything that serves this node: its children in the tree and the sources of second
    /// links pointing at it, transitively.
    public func downstream(of id: String) -> Set<String> {
        var seen = Set<String>()
        var queue = [id]
        while let current = queue.popLast() {
            var next = nodes[current]?.children.map(\.id) ?? []
            next += links.filter { $0.to == current }.map(\.from)
            for candidate in next where !seen.contains(candidate) && candidate != id {
                seen.insert(candidate)
                queue.append(candidate)
            }
        }
        return seen
    }

    /// The node, what it serves and what serves it.
    public func neighbourhood(of id: String) -> Set<String> {
        upstream(of: id).union(downstream(of: id)).union([id])
    }
}

public extension NoteIndex {
    /// How many open tasks a note shows in the map before the rest fold into "+n more".
    static let mapTaskLimit = 8

    /// Finds the goal a `goal:` line points at: exact title or file name first, then either
    /// one containing the other, ignoring case and punctuation.
    func goal(matching reference: String) -> Note? {
        func fold(_ s: String) -> String {
            s.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " }
                .split(separator: " ").joined(separator: " ")
        }
        let wanted = fold(reference)
        guard !wanted.isEmpty else { return nil }
        let goals = notes(kind: .goal)
        let names: [(Note, [String])] = goals.map { ($0, [fold($0.title), fold($0.displayTitle), fold($0.fileName)]) }
        if let exact = names.first(where: { $0.1.contains(wanted) }) { return exact.0 }
        return names.first { $0.1.contains { !$0.isEmpty && ($0.contains(wanted) || wanted.contains($0)) } }?.0
    }

    /// Builds the link map. Calendar notes stay out; they belong to days, not goals.
    func linkMap(taskLimit: Int = NoteIndex.mapTaskLimit) -> LinkMap {
        let candidates = notes.filter { $0.kind != .daily }
        // Finished projects sit with the archive until they are moved there.
        func isParked(_ note: Note) -> Bool { note.isArchived || note.status == "done" || note.status == "completed" }
        let active = candidates.filter { !isParked($0) }
        let archived = candidates.filter(isParked)
        let activePaths = Set(active.map(\.relativePath))

        // Resolve every reference once: the map is rebuilt on each change, and wikilinks are
        // parsed with a regular expression.
        var outgoing: [String: [Note]] = [:]
        for note in candidates {
            var seen = Set<String>()
            outgoing[note.relativePath] = note.outgoingReferences.compactMap { ref -> Note? in
                guard let target = self.note(matching: ref), target.relativePath != note.relativePath,
                      seen.insert(target.relativePath).inserted else { return nil }
                return target
            }
        }

        func goalServed(by note: Note) -> Note? {
            guard let reference = note.goal, let match = goal(matching: reference),
                  match.relativePath != note.relativePath, activePaths.contains(match.relativePath) else { return nil }
            return match
        }

        func areaOf(_ note: Note) -> Note? {
            if let name = note.area, let match = self.note(matching: name), match.kind == .area,
               match.relativePath != note.relativePath, activePaths.contains(match.relativePath) {
                return match
            }
            return outgoing[note.relativePath]?.first { $0.kind == .area && activePaths.contains($0.relativePath) }
        }

        // Every active note that links to a resource, or that the resource links to.
        func notesSupported(by resource: Note) -> [Note] {
            var seen = Set<String>()
            var out: [Note] = []
            let linked = (outgoing[resource.relativePath] ?? []) + active.filter { other in
                (outgoing[other.relativePath] ?? []).contains { $0.relativePath == resource.relativePath }
            }
            for note in linked where activePaths.contains(note.relativePath) && note.kind != .resource && note.kind != .inbox {
                if seen.insert(note.relativePath).inserted { out.append(note) }
            }
            let rank: [ParaKind: Int] = [.project: 0, .area: 1, .goal: 2]
            return out.sorted { a, b in
                let ra = rank[a.kind] ?? 3, rb = rank[b.kind] ?? 3
                if ra != rb { return ra < rb }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }

        // MARK: Parents

        var parent: [String: String] = [:]
        var links: [MapLink] = []
        let unlinkedID = "group:" + MapNode.Group.unlinked.rawValue
        let resourcesID = "group:" + MapNode.Group.resources.rawValue
        let archiveID = "group:" + MapNode.Group.archive.rawValue

        for note in active {
            let path = note.relativePath
            switch note.kind {
            case .goal:
                if let parentGoal = goalServed(by: note), parentGoal.kind == .goal {
                    parent[path] = parentGoal.relativePath
                }
            case .area:
                if let goal = goalServed(by: note) {
                    parent[path] = goal.relativePath
                } else {
                    parent[path] = unlinkedID
                }
            case .project:
                let goal = goalServed(by: note)
                if let area = areaOf(note) {
                    parent[path] = area.relativePath
                    if let goal { links.append(MapLink(from: path, to: goal.relativePath)) }
                } else if let goal {
                    parent[path] = goal.relativePath
                } else {
                    parent[path] = unlinkedID
                }
            case .resource:
                let supported = notesSupported(by: note)
                if let first = supported.first {
                    parent[path] = first.relativePath
                    links += supported.dropFirst().map { MapLink(from: path, to: $0.relativePath) }
                } else {
                    parent[path] = resourcesID
                }
            case .inbox, .archive, .daily:
                break
            }
        }

        // A goal chain that loops back on itself becomes a root at the first repeat.
        for note in active where note.kind == .goal {
            var seen: Set<String> = [note.relativePath]
            var cursor = parent[note.relativePath]
            while let current = cursor {
                if !seen.insert(current).inserted {
                    parent[note.relativePath] = nil
                    break
                }
                cursor = parent[current]
            }
        }

        for note in archived {
            parent[note.relativePath] = archiveID
            if let goal = goalServed(by: note) { links.append(MapLink(from: note.relativePath, to: goal.relativePath)) }
            if let area = areaOf(note) { links.append(MapLink(from: note.relativePath, to: area.relativePath)) }
        }

        // MARK: Tree

        let byParent = Dictionary(grouping: candidates.filter { parent[$0.relativePath] != nil }) { parent[$0.relativePath]! }

        func rank(_ note: Note) -> Int {
            switch note.kind {
            case .goal: return 0
            case .area: return 1
            case .project: return 2
            case .inbox: return 3
            case .archive: return 4
            case .resource: return 5
            case .daily: return 6
            }
        }

        func sorted(_ notes: [Note]) -> [Note] {
            notes.sorted { a, b in
                if rank(a) != rank(b) { return rank(a) < rank(b) }
                if a.kind == .goal, b.kind == .goal {
                    let ha = a.horizon ?? .year, hb = b.horizon ?? .year
                    if ha != hb { return GoalHorizon.allCases.firstIndex(of: ha)! < GoalHorizon.allCases.firstIndex(of: hb)! }
                }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }

        func taskChips(of note: Note) -> [MapNode] {
            guard note.kind.isTaskKind else { return [] }
            let open = note.openTasks.filter { !$0.isSubtask }
            var chips = open.prefix(taskLimit).map { task in
                MapNode(id: "\(note.relativePath)#\(task.lineIndex)",
                        content: .task(TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task), noteKind: note.kind))
            }
            if open.count > taskLimit {
                chips.append(MapNode(id: "\(note.relativePath)#more", content: .more(count: open.count - taskLimit, notePath: note.relativePath)))
            }
            return chips
        }

        func build(_ note: Note) -> MapNode {
            let below = sorted(byParent[note.relativePath] ?? [])
            let cards = below.filter { $0.kind != .resource }.map(build)
            let resources = below.filter { $0.kind == .resource }.map(build)
            return MapNode(id: note.relativePath, content: .note(note), children: cards + taskChips(of: note) + resources)
        }

        func group(_ group: MapNode.Group, id: String) -> MapNode? {
            let members = sorted(byParent[id] ?? [])
            guard !members.isEmpty else { return nil }
            return MapNode(id: id, content: .group(group), children: members.map(build))
        }

        let rootGoals = sorted(active.filter { $0.kind == .goal && parent[$0.relativePath] == nil })
        var roots = rootGoals.map(build)
        roots += sorted(active.filter { $0.kind == .inbox }).map(build)
        if let unlinked = group(.unlinked, id: unlinkedID) { roots.append(unlinked) }
        if let loose = group(.resources, id: resourcesID) { roots.append(loose) }
        if let archive = group(.archive, id: archiveID) { roots.append(archive) }

        // Keep only links whose both ends are on the map.
        let ids = Set(roots.flatMap(\.flattened).map(\.id))
        var seenLinks = Set<MapLink>()
        let kept = links.filter { ids.contains($0.from) && ids.contains($0.to) && seenLinks.insert($0).inserted }
        return LinkMap(roots: roots, links: kept)
    }
}
