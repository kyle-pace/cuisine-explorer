import SwiftUI

/// Walk mode, as in the web view: the page you're on in the middle, everything linked to it
/// around it. Tap a dot to make it the center; the trail at the bottom retraces your route.
struct WalkView: View {
    @Environment(Store.self) private var store
    @Environment(Library.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let start: String
    @State private var center: String
    @State private var trail: [String] = []
    @State private var hidden: Set<Store.Kind> = []
    @State private var picked: String?
    @State private var showAll = false
    @State private var page: Page?

    init(start: String) {
        self.start = start
        _center = State(initialValue: start)
    }

    private var all: [Store.Node] { store.neighbors(center) }
    private var shown: [Store.Node] { all.filter { !hidden.contains($0.type) } }
    private var counts: [(Store.Kind, Int)] {
        Store.Kind.allCases.compactMap { k in
            let n = all.filter { $0.type == k }.count
            return n > 0 ? (k, n) : nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if counts.count > 1 {
                ChipRow {
                    ForEach(counts, id: \.0) { kind, n in
                        FilterChip(kind.plural, count: n, isOn: !hidden.contains(kind)) {
                            withAnimation(Theme.motion(reduceMotion)) {
                                if hidden.contains(kind) { hidden.remove(kind) } else { hidden.insert(kind) }
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.s)
            }

            RadialGraph(center: center, neighbors: Array(shown.prefix(RadialGraph.maxShown)),
                        picked: picked, labels: true) { ref in
                step(to: ref)
            }
            .frame(maxHeight: .infinity)
            .accessibilityLabel("Connections of \(store.node(center)?.name ?? "")")

            panel
        }
        .background(Theme.ground)
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Everything linked here", systemImage: "list.bullet") { showAll = true }
            }
        }
        .sheet(isPresented: $showAll) { NeighborsSheet(center: center) { step(to: $0) } }
        .task(id: center) {
            page = store.cachedPage(center)
            if page == nil { page = await store.page(center) }
        }
        .sensoryFeedback(.selection, trigger: center)
    }

    private func step(to ref: String) {
        guard ref != center else { return }
        withAnimation(Theme.motion(reduceMotion)) {
            trail.append(center)
            if trail.count > 30 { trail.removeFirst() }
            center = ref
            picked = nil
        }
    }

    private func back(to i: Int) {
        withAnimation(Theme.motion(reduceMotion)) {
            let target = trail[i]
            trail.removeSubrange(i...)
            center = target
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            if let n = store.node(center) {
                HStack(alignment: .top, spacing: Space.m) {
                    if let thumb = store.thumbnail(center) {
                        RemoteImage(url: thumb).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: Radius.small))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(n.name).font(Theme.heading).foregroundStyle(Theme.ink)
                        Text(n.sub.isEmpty ? n.type.singular : n.sub).font(Theme.caption).foregroundStyle(Theme.muted).lineLimit(1)
                        if let p = page {
                            Text(Page.summary(p)).font(Theme.callout).foregroundStyle(Theme.muted).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    NavigationLink(value: Route.item(center)) {
                        Text("Open").font(Theme.callout600)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
                if all.count > RadialGraph.maxShown {
                    Button("Showing \(min(shown.count, RadialGraph.maxShown)) of \(all.count) links. See them all") { showAll = true }
                        .font(Theme.caption)
                }
            }
            if !trail.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.xs) {
                            ForEach(Array(trail.enumerated()), id: \.offset) { i, ref in
                                Button(store.node(ref)?.name ?? ref) { back(to: i) }
                                    .font(Theme.caption)
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.capsule)
                                    .controlSize(.small)
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.muted)
                            }
                            Text(store.node(center)?.name ?? "").font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.ink).id("end")
                        }
                    }
                    .onChange(of: trail.count) { withAnimation(Theme.motion(reduceMotion)) { proxy.scrollTo("end", anchor: .trailing) } }
                    .accessibilityLabel("Your trail, \(trail.count) steps")
                }
            }
        }
        .padding(Space.l)
        .background(Theme.surface)
        .overlay(alignment: .top) { Divider().overlay(Theme.line) }
    }
}

/// The dots: the center in the middle, its neighbors on a ring (two rings when there are many).
/// Positions animate when the center changes, so a tapped dot slides into the middle.
struct RadialGraph: View {
    static let maxShown = 36
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let center: String
    let neighbors: [Store.Node]
    var picked: String?
    var labels = true
    var compact = false
    let onTap: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            let mid = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let points = layout(in: geo.size)
            let showLabels = labels && (neighbors.count <= 18 || !compact)
            ZStack {
                // Edges: thin bars from the middle to each dot, so they animate with the dots
                ForEach(neighbors) { n in
                    if let p = points[n.ref] {
                        let dx = p.x - mid.x, dy = p.y - mid.y
                        Rectangle()
                            .fill(Theme.line)
                            .frame(width: max(1, hypot(dx, dy)), height: 1)
                            .rotationEffect(.radians(atan2(dy, dx)))
                            .position(x: (p.x + mid.x) / 2, y: (p.y + mid.y) / 2)
                    }
                }
                ForEach(neighbors) { n in
                    if let p = points[n.ref] {
                        Button { onTap(n.ref) } label: {
                            Dot(node: n, size: dotSize, label: showLabels && (neighbors.count <= 18 || picked == n.ref || !compact),
                                labelBelow: p.y >= mid.y, emphasized: picked == n.ref)
                        }
                        .buttonStyle(.plain)
                        .position(p)
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                        .accessibilityLabel("\(n.name), \(n.type.singular)")
                        .accessibilityHint("Makes it the center")
                        .zIndex(picked == n.ref ? 2 : 0)
                    }
                }
                if let c = store.node(center) {
                    Dot(node: c, size: compact ? 18 : 26, label: !compact, labelBelow: true, emphasized: true, isCenter: true)
                        .position(mid)
                        .zIndex(3)
                        .accessibilityLabel("\(c.name), the center")
                }
                if neighbors.isEmpty {
                    Text("Nothing links here yet").font(Theme.callout).foregroundStyle(Theme.muted)
                        .position(x: mid.x, y: mid.y + 40)
                }
            }
            .animation(Theme.motion(reduceMotion), value: center)
            .animation(Theme.motion(reduceMotion), value: neighbors.map(\.ref))
            .contentShape(Rectangle())
        }
        .clipped()
    }

    private var dotSize: CGFloat { compact ? 9 : (neighbors.count > 18 ? 10 : 13) }

    /// One ring up to 12, then two rings: cuisines and dishes inside, the rest outside
    private func layout(in size: CGSize) -> [String: CGPoint] {
        let mid = CGPoint(x: size.width / 2, y: size.height / 2)
        let labelRoom: CGFloat = labels && !compact ? 44 : 12
        let r = max(40, min(size.width, size.height) / 2 - labelRoom)
        var out: [String: CGPoint] = [:]
        if neighbors.count <= 12 {
            for (i, n) in neighbors.enumerated() {
                let a = -CGFloat.pi / 2 + CGFloat(i) / CGFloat(max(neighbors.count, 1)) * 2 * .pi
                out[n.ref] = CGPoint(x: mid.x + r * cos(a), y: mid.y + r * sin(a))
            }
        } else {
            let inner = neighbors.filter { $0.type == .cuisine || $0.type == .dish }
            let outer = neighbors.filter { !($0.type == .cuisine || $0.type == .dish) }
            let rings: [([Store.Node], CGFloat)] = (inner.isEmpty || outer.isEmpty)
                ? [(Array(neighbors.prefix(neighbors.count / 2)), r * 0.58), (Array(neighbors.dropFirst(neighbors.count / 2)), r)]
                : [(inner, r * 0.58), (outer, r)]
            for (ring, radius) in rings {
                for (i, n) in ring.enumerated() {
                    let a = -CGFloat.pi / 2 + (CGFloat(i) + (radius < r ? 0.5 : 0)) / CGFloat(max(ring.count, 1)) * 2 * .pi
                    out[n.ref] = CGPoint(x: mid.x + radius * cos(a), y: mid.y + radius * sin(a))
                }
            }
        }
        return out
    }
}

struct Dot: View {
    let node: Store.Node
    var size: CGFloat
    var label: Bool
    var labelBelow = true
    var emphasized = false
    var isCenter = false

    var body: some View {
        VStack(spacing: 4) {
            if label && !labelBelow { text }
            RoundedRectangle(cornerRadius: node.type == .cuisine ? size / 2 : size * 0.22)
                .fill(node.color)
                .frame(width: size, height: size)
                .overlay(RoundedRectangle(cornerRadius: node.type == .cuisine ? size / 2 : size * 0.22)
                    .stroke(isCenter ? Theme.ink : (emphasized ? Theme.ink : Theme.ground), lineWidth: isCenter ? 3 : 1.5))
                .shadow(color: .black.opacity(isCenter ? 0.25 : 0), radius: 6, y: 2)
            if label && labelBelow { text }
        }
        .frame(width: 92)
        .contentShape(Rectangle())
    }

    private var text: some View {
        Text(node.name)
            .font(.app(isCenter ? 13 : 11, isCenter ? .bold : .medium, relativeTo: .caption2))
            .foregroundStyle(isCenter || emphasized ? Theme.ink : Theme.muted)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Every link from the center, by type, when there are too many to draw
struct NeighborsSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let center: String
    let choose: (String) -> Void

    var body: some View {
        let all = store.neighbors(center)
        NavigationStack {
            List {
                ForEach(Store.Kind.allCases, id: \.self) { kind in
                    let items = all.filter { $0.type == kind }
                    if !items.isEmpty {
                        Section(kind.plural) {
                            ForEach(items) { n in
                                Button { dismiss(); choose(n.ref) } label: { NodeRow(node: n) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Linked to \(store.node(center)?.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
