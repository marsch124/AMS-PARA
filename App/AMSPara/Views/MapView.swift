import SwiftUI
import AMSParaCore

/// The link map: goals at the top, the areas and projects that serve them below, their open
/// tasks and resources under those, then unlinked notes and the archive. Clicking a box
/// lights up everything it serves and everything that serves it, and opens its note.
struct MapView: View {
    @EnvironmentObject private var model: AppModel
    @State private var map = LinkMap(roots: [])
    @State private var selectedID: String?
    @State private var zoom: CGFloat = 1

    private static let zoomSteps: [CGFloat] = [0.6, 0.75, 0.9, 1, 1.15, 1.3, 1.5]

    var body: some View {
        VStack(spacing: 0) {
            if map.isEmpty {
                ContentUnavailableView("Nothing to map yet", systemImage: SidebarSection.map.systemImage,
                                       description: Text("Create a goal, then give your projects and areas a goal: line. They show up here, top down."))
            } else {
                let layout = MapLayout(map: map, zoom: zoom)
                let lit = selectedID.map { map.neighbourhood(of: $0) }
                ScrollView([.horizontal, .vertical]) {
                    MapCanvas(layout: layout, lit: lit, selectedID: selectedID) { node in
                        select(node)
                    }
                    .frame(width: layout.size.width, height: layout.size.height)
                    .padding(28)
                }
                Divider()
                MapFooter(map: map, selectedID: selectedID)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { step(-1) } label: { Label("Zoom out", systemImage: "minus.magnifyingglass") }
                    .disabled(zoom <= Self.zoomSteps.first!)
                Button { step(1) } label: { Label("Zoom in", systemImage: "plus.magnifyingglass") }
                    .disabled(zoom >= Self.zoomSteps.last!)
            }
        }
        .onAppear { rebuild() }
        .onChange(of: model.notes) { _, _ in rebuild() }
        .onChange(of: model.selectedNotePath) { _, path in
            // Follow a note chosen elsewhere; a task chip keeps its own selection.
            guard let path, map.node(path) != nil, selectedID.flatMap(map.node)?.notePath != path else { return }
            selectedID = path
        }
    }

    private func rebuild() {
        map = model.index.linkMap()
        if let selectedID, map.node(selectedID) == nil { self.selectedID = nil }
    }

    private func step(_ direction: Int) {
        let steps = Self.zoomSteps
        let current = steps.firstIndex(of: zoom) ?? steps.firstIndex(of: 1)!
        let next = min(max(current + direction, 0), steps.count - 1)
        zoom = steps[next]
    }

    private func select(_ node: MapNode) {
        selectedID = node.id
        model.log("map: selected \(node.id)")
        if let path = node.notePath, model.selectedNotePath != path {
            model.selectedNotePath = path
        }
    }
}

// MARK: - Layout

/// Positions for every node and every line, computed once per map and zoom level. Parents
/// are centred over their subtrees; tasks and resources stack under their note.
struct MapLayout {
    struct Item: Identifiable {
        let node: MapNode
        let frame: CGRect
        var id: String { node.id }
    }

    struct Edge: Identifiable {
        let from: String
        let to: String
        let start: CGPoint
        let end: CGPoint
        /// A second link (dashed) rather than the tree line.
        let dashed: Bool
        var id: String { from + " > " + to }
    }

    let zoom: CGFloat
    let items: [Item]
    let edges: [Edge]
    let size: CGSize

    init(map: LinkMap, zoom: CGFloat) {
        self.zoom = zoom
        let card = CGSize(width: 180 * zoom, height: 50 * zoom)
        let chip = CGSize(width: 180 * zoom, height: 26 * zoom)
        let gapX = 20 * zoom, rootGap = 48 * zoom, rowGap = 46 * zoom, chipGap = 4 * zoom

        var widths: [String: CGFloat] = [:]
        func measure(_ node: MapNode) -> CGFloat {
            let chips = node.children.filter(\.isChip)
            var columns = node.children.filter { !$0.isChip }.map(measure)
            if !chips.isEmpty { columns.insert(card.width, at: 0) }
            let total = columns.reduce(0, +) + gapX * CGFloat(max(columns.count - 1, 0))
            let width = max(card.width, total)
            widths[node.id] = width
            return width
        }
        map.roots.forEach { _ = measure($0) }

        struct Pending {
            let node: MapNode
            let row: Int
            let x: CGFloat
            let offsetY: CGFloat
        }
        var pending: [Pending] = []
        var rowHeights: [Int: CGFloat] = [:]
        func place(_ node: MapNode, x: CGFloat, row: Int) {
            let width = widths[node.id] ?? card.width
            pending.append(Pending(node: node, row: row, x: x + (width - card.width) / 2, offsetY: 0))
            rowHeights[row] = max(rowHeights[row] ?? 0, card.height)
            let chips = node.children.filter(\.isChip)
            let branches = node.children.filter { !$0.isChip }
            var columns = branches.map { widths[$0.id] ?? card.width }
            if !chips.isEmpty { columns.insert(card.width, at: 0) }
            let total = columns.reduce(0, +) + gapX * CGFloat(max(columns.count - 1, 0))
            var cursor = x + (width - total) / 2
            if !chips.isEmpty {
                var y: CGFloat = 0
                for chipNode in chips {
                    pending.append(Pending(node: chipNode, row: row + 1, x: cursor, offsetY: y))
                    y += chip.height + chipGap
                }
                rowHeights[row + 1] = max(rowHeights[row + 1] ?? 0, y - chipGap)
                cursor += card.width + gapX
            }
            for branch in branches {
                place(branch, x: cursor, row: row + 1)
                cursor += (widths[branch.id] ?? card.width) + gapX
            }
        }
        var x: CGFloat = 0
        for root in map.roots {
            place(root, x: x, row: 0)
            x += (widths[root.id] ?? card.width) + rootGap
        }

        var rowY: [Int: CGFloat] = [:]
        var y: CGFloat = 0
        for row in 0...(rowHeights.keys.max() ?? 0) {
            rowY[row] = y
            y += (rowHeights[row] ?? card.height) + rowGap
        }
        let placed = pending.map { p in
            Item(node: p.node, frame: CGRect(x: p.x, y: (rowY[p.row] ?? 0) + p.offsetY,
                                             width: card.width, height: p.node.isChip ? chip.height : card.height))
        }
        items = placed
        size = CGSize(width: max(x - rootGap, card.width), height: max(y - rowGap, card.height))

        let frames = Dictionary(placed.map { ($0.id, $0.frame) }, uniquingKeysWith: { a, _ in a })
        var lines: [Edge] = []
        for item in placed {
            for child in item.node.children {
                guard let target = frames[child.id] else { continue }
                lines.append(Edge(from: child.id, to: item.id,
                                  start: CGPoint(x: target.midX, y: target.minY),
                                  end: CGPoint(x: item.frame.midX, y: item.frame.maxY), dashed: false))
            }
        }
        for link in map.links {
            guard let source = frames[link.from], let target = frames[link.to] else { continue }
            lines.append(Edge(from: link.from, to: link.to,
                              start: CGPoint(x: source.midX, y: source.minY),
                              end: CGPoint(x: target.midX, y: target.maxY), dashed: true))
        }
        edges = lines
    }
}

// MARK: - Drawing

struct MapCanvas: View {
    let layout: MapLayout
    /// Nodes to draw at full strength; nil lights everything.
    let lit: Set<String>?
    let selectedID: String?
    let select: (MapNode) -> Void

    var body: some View {
        let tints = Dictionary(layout.items.map { ($0.id, $0.node.tint) }, uniquingKeysWith: { a, _ in a })
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for edge in layout.edges {
                    var path = Path()
                    path.move(to: edge.start)
                    let midY = (edge.start.y + edge.end.y) / 2
                    path.addCurve(to: edge.end,
                                  control1: CGPoint(x: edge.start.x, y: midY),
                                  control2: CGPoint(x: edge.end.x, y: midY))
                    let bright = lit.map { $0.contains(edge.from) && $0.contains(edge.to) } ?? true
                    let color = (tints[edge.from] ?? .secondary).opacity(bright ? 0.85 : 0.18)
                    context.stroke(path, with: .color(color),
                                   style: StrokeStyle(lineWidth: (edge.dashed ? 1.2 : 1.8) * layout.zoom,
                                                      dash: edge.dashed ? [5 * layout.zoom, 4 * layout.zoom] : []))
                }
            }
            ForEach(layout.items) { item in
                MapNodeView(node: item.node, zoom: layout.zoom,
                            dimmed: lit.map { !$0.contains(item.id) } ?? false,
                            selected: item.id == selectedID)
                    .frame(width: item.frame.width, height: item.frame.height)
                    .position(x: item.frame.midX, y: item.frame.midY)
                    .onTapGesture { select(item.node) }
            }
        }
    }
}

extension MapNode {
    var tint: Color {
        switch content {
        case .note(let note): return note.tint
        case .task(_, let noteKind): return noteKind.tint
        case .more(_, let path): return path.hasPrefix("Areas/") ? ParaKind.area.tint : ParaKind.project.tint
        case .group(let group): return group == .archive ? ParaKind.archive.tint : Color.secondary
        }
    }

    var paraKind: ParaKind? {
        switch content {
        case .note(let note): return note.kind
        case .group(let group): return group == .archive ? .archive : nil
        case .task, .more: return nil
        }
    }
}

struct MapNodeView: View {
    let node: MapNode
    let zoom: CGFloat
    let dimmed: Bool
    let selected: Bool

    var body: some View {
        Group {
            switch node.content {
            case .note(let note) where note.kind == .resource && !note.isArchived:
                chip(icon: SidebarSection.kind(.resource).systemImage, title: note.title, detail: nil, tint: ParaKind.resource.tint)
            case .note(let note):
                card(note)
            case .task(let ref, _):
                chip(icon: ref.task.priority >= 2 ? "exclamationmark.circle" : "circle", title: ref.task.title,
                     detail: ref.task.dueDate?.description, tint: node.tint)
            case .more:
                chip(icon: "ellipsis", title: node.title, detail: nil, tint: node.tint)
            case .group(let group):
                groupCard(group)
            }
        }
        .opacity(dimmed ? 0.28 : 1)
        .contentShape(Rectangle())
        .help(node.title)
        .animation(.easeInOut(duration: 0.15), value: dimmed)
    }

    private func card(_ note: Note) -> some View {
        HStack(spacing: 8 * zoom) {
            KindBadge(kind: note.kind, size: 20 * zoom)
            VStack(alignment: .leading, spacing: 1) {
                Text(note.displayTitle)
                    .font(.system(size: 12.5 * zoom, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle(for: note))
                    .font(.system(size: 10 * zoom))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8 * zoom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(note.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8 * zoom))
        .overlay(RoundedRectangle(cornerRadius: 8 * zoom).strokeBorder(note.tint, lineWidth: (selected ? 2.5 : 1) * zoom))
    }

    private func groupCard(_ group: MapNode.Group) -> some View {
        HStack(spacing: 8 * zoom) {
            Image(systemName: group == .archive ? "archivebox" : "questionmark.folder")
                .font(.system(size: 12 * zoom, weight: .semibold))
                .foregroundStyle(node.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(group.title)
                    .font(.system(size: 12 * zoom, weight: .semibold))
                    .lineLimit(2)
                Text("\(node.children.count) note\(node.children.count == 1 ? "" : "s")")
                    .font(.system(size: 10 * zoom))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8 * zoom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 8 * zoom)
            .strokeBorder(node.tint.opacity(0.7), style: StrokeStyle(lineWidth: (selected ? 2.5 : 1) * zoom, dash: [4 * zoom, 3 * zoom])))
    }

    private func chip(icon: String, title: String, detail: String?, tint: Color) -> some View {
        HStack(spacing: 6 * zoom) {
            Image(systemName: icon)
                .font(.system(size: 10 * zoom))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 11 * zoom))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let detail {
                Text(detail)
                    .font(.system(size: 9 * zoom))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 7 * zoom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 6 * zoom))
        .overlay(RoundedRectangle(cornerRadius: 6 * zoom).strokeBorder(tint.opacity(selected ? 1 : 0.45), lineWidth: (selected ? 2 : 1) * zoom))
    }

    private func subtitle(for note: Note) -> String {
        var parts: [String] = []
        if let horizon = note.horizon { parts.append(horizon.label) }
        if let status = note.status, status != "active" { parts.append(status.capitalized) }
        if note.kind.isTaskKind {
            let open = note.openTasks.count
            parts.append(open == 0 ? "no open tasks" : "\(open) open")
        }
        if let due = note.dueDate { parts.append("due \(due)") }
        if let target = note.targetDate { parts.append("by \(target)") }
        if parts.isEmpty { parts.append(note.isArchived ? "Archived" : String(note.kind.displayName.dropLast())) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Footer

/// The legend, and for the chosen box: what it serves and what serves it.
struct MapFooter: View {
    @EnvironmentObject private var model: AppModel
    let map: LinkMap
    let selectedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                legend(ParaKind.goal.tint, "Goals")
                legend(ParaKind.area.tint, "Areas")
                legend(ParaKind.project.tint, "Projects, their actions")
                legend(ParaKind.resource.tint, "Resources")
                legend(ParaKind.archive.tint, "Archive")
                Text("Solid line: sits under.  Dashed: also serves.")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            if let selectedID, let node = map.node(selectedID) {
                let up = names(map.upstream(of: selectedID))
                let down = names(map.downstream(of: selectedID))
                HStack(alignment: .top, spacing: 8) {
                    if let kind = node.paraKind {
                        KindBadge(kind: kind, size: 18)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.title).font(.subheadline.weight(.semibold))
                        Text("Serves: " + (up.isEmpty ? "nothing above it" : up.joined(separator: " › ")))
                        Text("Served by: " + (down.isEmpty ? "nothing yet" : down.joined(separator: ", ")))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("Click a box to see what it serves and what serves it. The note opens on the right.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }

    /// Titles ordered top down: goals, areas, projects, then tasks and resources.
    private func names(_ ids: Set<String>) -> [String] {
        let order = map.allNodes.filter { ids.contains($0.id) }
        func rank(_ node: MapNode) -> Int {
            switch node.content {
            case .note(let note):
                switch note.kind {
                case .goal: return 0
                case .area: return 1
                case .project: return 2
                case .inbox: return 3
                case .archive: return 4
                case .resource: return 6
                case .daily: return 7
                }
            case .task, .more: return 5
            case .group: return 8
            }
        }
        let sorted = order.sorted { a, b in
            let ra = rank(a), rb = rank(b)
            if ra != rb { return ra < rb }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
        var titles = sorted.prefix(10).map(\.title)
        if sorted.count > 10 { titles.append("and \(sorted.count - 10) more") }
        return titles
    }
}
