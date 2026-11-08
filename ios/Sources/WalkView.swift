import SwiftUI
import TipKit

/// Shown once, the first time a ring is too crowded to label every dot
struct HoldForNameTip: Tip {
    var title: Text { Text("Crowded ring") }
    var message: Text? { Text("Tap a dot to move there. Hold an unnamed one to see its name.") }
    var image: Image? { Image(systemName: "hand.tap") }
}

/// Walk mode, as in the web view: the page you're on in the middle, everything linked to it
/// around it. Tap a dot to make it the center; the trail at the bottom retraces your route.
struct WalkView: View {
    @Environment(Store.self) private var store
    @Environment(Library.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    let start: String
    @State private var center: String
    @State private var trail: [String] = []
    @State private var focus: Store.Kind?
    @State private var picked: String?
    @State private var showAll = false
    @State private var page: Page?

    init(start: String) {
        self.start = start
        _center = State(initialValue: start)
    }

    private var all: [Store.Node] { store.neighbors(center) }
    private var shown: [Store.Node] { focus.map { k in all.filter { $0.type == k } } ?? all }
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
                    FilterChip("All", isOn: focus == nil) { withAnimation(Theme.motion(reduceMotion)) { focus = nil } }
                    ForEach(counts, id: \.0) { kind, n in
                        FilterChip(kind.plural, count: n, isOn: focus == kind) {
                            withAnimation(Theme.motion(reduceMotion)) { focus = focus == kind ? nil : kind }
                        }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.s)
            }

            RadialGraph(center: center, neighbors: Array(shown.prefix(RadialGraph.maxShown)),
                        picked: picked, labels: true, onTap: step(to:), onHold: { picked = $0 })
            .frame(maxHeight: .infinity)
            .accessibilityLabel("Connections of \(store.node(center)?.name ?? "")")


            panel
        }
        .background(Theme.ground)
        .navigationTitle("Wander")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Everything linked here", systemImage: "list.bullet") { showAll = true }
            }
        }
        .sheet(isPresented: $showAll) { NeighborsSheet(center: center) { step(to: $0) } }
        .onChange(of: focus) { picked = nil }
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
            if shown.count > (typeSize.isAccessibilitySize ? 8 : 18) { TipView(HoldForNameTip()).tipBackground(Theme.raised) }
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
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.muted).accessibilityHidden(true)
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
    @Environment(\.dynamicTypeSize) private var typeSize
    let center: String
    let neighbors: [Store.Node]
    var picked: String?
    var labels = true
    var compact = false
    var onTap: (String) -> Void = { _ in }
    var onHold: (String) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let mid = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let (points, labeled) = layout(in: geo.size)
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
                            .accessibilityHidden(true)
                    }
                }
                ForEach(neighbors) { n in
                    if let p = points[n.ref] {
                        Dot(node: n, size: dotSize, label: labels && (labeled.contains(n.ref) || picked == n.ref),
                            labelBelow: p.y >= mid.y, emphasized: picked == n.ref, labelWidth: neighbors.count > 12 ? 74 : 92)
                            .onTapGesture { onTap(n.ref) }
                            .onLongPressGesture(minimumDuration: 0.25) { onHold(n.ref) }
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
                        .accessibilityElement()
                        .accessibilityLabel("\(c.name), the center, \(neighbors.count) links shown")
                        .accessibilitySortPriority(2000)
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

    /// One ring up to 18, then two. Rings are ellipses so a tall phone screen is used.
    /// Labels fit on a ring of up to 18 dots.
    private func layout(in size: CGSize) -> (points: [String: CGPoint], labeled: Set<String>) {
        let mid = CGPoint(x: size.width / 2, y: size.height / 2)
        let room: CGFloat = labels && !compact ? 48 : 12
        let rx = max(40, size.width / 2 - room), ry = max(40, size.height / 2 - room - (compact ? 0 : 10))
        var out: [String: CGPoint] = [:]
        var labeled = Set<String>()
        func place(_ ring: [Store.Node], scale: CGFloat, offset: CGFloat) {
            for (i, n) in ring.enumerated() {
                let a = -CGFloat.pi / 2 + (CGFloat(i) + offset) / CGFloat(max(ring.count, 1)) * 2 * .pi
                out[n.ref] = CGPoint(x: mid.x + rx * scale * cos(a), y: mid.y + ry * scale * sin(a))
            }
        }
        // At the accessibility text sizes only a few labels fit; the rest show on hold or to VoiceOver
        let fit = typeSize.isAccessibilitySize ? 8 : 18
        if neighbors.count <= 18 {
            place(neighbors, scale: 1, offset: 0)
            if neighbors.count <= fit { labeled = Set(neighbors.map(\.ref)) }
        } else {
            // The outer ring has room for labels (about 70 points apart on a phone), so the
            // likeliest next steps (cuisines, then dishes) go there; the rest sit inside, unlabeled
            let outer = Array(neighbors.prefix(18)), inner = Array(neighbors.dropFirst(18))
            place(outer, scale: 1, offset: 0)
            place(inner, scale: 0.5, offset: 0.5)
            if !typeSize.isAccessibilitySize { labeled = Set(outer.map(\.ref)) }
        }
        return (out, labeled)
    }
}

struct Dot: View {
    let node: Store.Node
    var size: CGFloat
    var label: Bool
    var labelBelow = true
    var emphasized = false
    var isCenter = false
    var labelWidth: CGFloat = 92
    var hitSize: CGFloat = 44

    var body: some View {
        // The hit area is the dot alone, so neighbors on a crowded ring don't steal taps
        RoundedRectangle(cornerRadius: node.type == .cuisine ? size / 2 : size * 0.22)
            .fill(node.color)
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: node.type == .cuisine ? size / 2 : size * 0.22)
                .stroke(isCenter || emphasized ? Theme.ink : Theme.ground, lineWidth: isCenter ? 3 : 1.5))
            .shadow(color: .black.opacity(isCenter ? 0.25 : 0), radius: 6, y: 2)
            .scaleEffect(emphasized && !isCenter ? 1.3 : 1)
            .frame(width: max(size, hitSize), height: max(size, hitSize))
            .contentShape(Circle())
            .overlay(alignment: labelBelow ? .top : .bottom) {
                if label {
                    text.offset(y: labelBelow ? max(size, hitSize) / 2 + size / 2 + 2 : -(max(size, hitSize) / 2 + size / 2 + 2))
                        .allowsHitTesting(false)
                }
            }
    }

    private var text: some View {
        Text(node.name)
            .font(.app(isCenter ? 13 : 11, isCenter ? .bold : .medium, relativeTo: .caption2))
            .foregroundStyle(isCenter || emphasized ? Theme.ink : Theme.muted)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(width: labelWidth)
            .fixedSize(horizontal: false, vertical: true)
            .background(emphasized && !isCenter ? AnyShapeStyle(Theme.surface.opacity(0.92)) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 6))
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

/// The Wander tab: walk mode from a cuisine picked at random, with a way to start somewhere new
struct WanderScreen: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: String?

    var body: some View {
        Group {
            if let start {
                WalkView(start: start)
                    .id(start)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Somewhere new", systemImage: "shuffle") { pick() }
                        }
                    }
            } else {
                Color.clear.onAppear(perform: pick)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: start)
    }

    private func pick() {
        // A cuisine with a photo and a few links makes a good starting point
        let candidates = store.nodes.filter { $0.type == .cuisine && store.hasPhoto($0.ref) && store.linkCount($0.ref) >= 4 }
        guard let n = candidates.filter({ $0.ref != start }).randomElement() ?? candidates.first else { return }
        withAnimation(Theme.motion(reduceMotion)) { start = n.ref }
    }
}
