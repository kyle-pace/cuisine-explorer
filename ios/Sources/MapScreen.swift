import SwiftUI
import MapKit

/// The map, as on the globe: countries filled in their continent's color, regional cuisines
/// drawn as the states or provinces they come from once you zoom in, and dots for the
/// cuisines that are a place but not an area (Indigenous foodways, cities). Tap anything for a card.
struct MapScreen: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shapes = Shapes()

    /// Camera heights: the whole world, then each continent
    static let world = MapCamera(centerCoordinate: .init(latitude: 20, longitude: 15), distance: 40_000_000)
    static let regions: [String: MapCamera] = [
        "africa": MapCamera(centerCoordinate: .init(latitude: 2, longitude: 20), distance: 13_000_000),
        "the-americas": MapCamera(centerCoordinate: .init(latitude: 8, longitude: -80), distance: 24_000_000),
        "asia": MapCamera(centerCoordinate: .init(latitude: 28, longitude: 95), distance: 17_000_000),
        "europe": MapCamera(centerCoordinate: .init(latitude: 52, longitude: 14), distance: 7_000_000),
        "oceania": MapCamera(centerCoordinate: .init(latitude: -22, longitude: 150), distance: 11_000_000),
    ]
    @State private var position: MapCameraPosition = .camera(MapScreen.world)
    @State private var selected: String?        // a cuisine ref
    @State private var selectedShape: Int?      // a country with no cuisine of its own
    @State private var path: [Route] = []
    @State private var span: Double = 110

    private var showRegions: Bool { span < 30 }

    var body: some View {
        NavigationStack(path: $path) {
            MapReader { proxy in
                Map(position: $position, interactionModes: [.pan, .zoom, .rotate]) {
                    ForEach(shapes.countries) { c in
                        let color = fill(c), on = isSelected(c)
                        ForEach(Array(c.polygons.enumerated()), id: \.offset) { _, p in
                            MapPolygon(p)
                                .foregroundStyle(color.opacity(on ? 0.75 : 0.42))
                                .stroke(on ? Theme.ink : Theme.ground.opacity(0.9), lineWidth: on ? 1.5 : 0.5)
                        }
                    }
                    if showRegions {
                        ForEach(shapes.regions) { r in
                            let color = fill(r), on = isSelected(r)
                            ForEach(Array(r.polygons.enumerated()), id: \.offset) { _, p in
                                MapPolygon(p)
                                    .foregroundStyle(color.opacity(on ? 0.8 : 0.5))
                                    .stroke(on ? Theme.ink : Theme.ground, lineWidth: on ? 1.5 : 0.8)
                            }
                            if span < 14, let ref = r.ref, let n = store.node(ref), let c = r.rings.first?.first {
                                Annotation(n.name.replacingOccurrences(of: " cuisine", with: ""), coordinate: labelPoint(r), anchor: .center) {
                                    EmptyView()
                                }
                                .annotationTitles(.visible)
                            }
                        }
                    }
                    // Diaspora routes, as on the globe: faint arcs, lit when they touch the selection
                    ForEach(arcs, id: \.route) { a in
                        MapPolyline(coordinates: [a.from, a.to], contourStyle: .geodesic)
                            .stroke(a.lit ? Theme.saffron : Theme.ink.opacity(0.16), lineWidth: a.lit ? 2.5 : 1)
                    }
                    // Dots: places without an area. National cuisines are their country; regional
                    // ones with a shape are their shape; the rest appear as you zoom in
                    ForEach(dotPlaces) { p in
                        if let n = store.node(p.ref) {
                            Annotation(n.name, coordinate: p.coordinate, anchor: .center) {
                                Circle()
                                    .fill(color(p.ref))
                                    .frame(width: 11, height: 11)
                                    .overlay(Circle().stroke(selected == p.ref ? Theme.ink : Theme.ground.opacity(0.8), lineWidth: selected == p.ref ? 2.5 : 1.5))
                                    .scaleEffect(selected == p.ref ? 1.4 : 1)
                                    .padding(10)
                                    .contentShape(Circle())
                                    .onTapGesture { select(p.ref) }
                            }
                            .annotationTitles(span < 8 || selected == p.ref ? .visible : .hidden)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
                .mapControls { MapCompass(); MapScaleView() }
                .onMapCameraChange(frequency: .onEnd) { ctx in span = ctx.region.span.latitudeDelta }
                .onTapGesture { point in
                    guard let coord = proxy.convert(point, from: .local) else { return }
                    if let hit = shapes.hit(coord, regions: showRegions) {
                        if let ref = hit.ref { select(ref) } else { selectedShape = hit.id; selected = nil }
                    } else {
                        withAnimation(Theme.motion(reduceMotion)) { selected = nil; selectedShape = nil }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                ChipRow {
                    ForEach(Store.continents, id: \.slug) { c in
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) {
                                selected = nil; selectedShape = nil
                                position = .camera(Self.regions[c.slug] ?? Self.world)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(c.color).frame(width: 10, height: 10)
                                Text(c.name)
                            }
                            .font(Theme.callout600).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line.opacity(0.6)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show \(c.name)")
                    }
                }
                .padding(.horizontal, Space.l).padding(.vertical, Space.s)
            }
            .safeAreaInset(edge: .bottom) {
                if let ref = selected, let n = store.node(ref) {
                    PlaceCard(node: n) { path.append(.item(ref)) } close: { selected = nil }
                        .padding(.horizontal, Space.m).padding(.bottom, Space.s)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                } else if let i = selectedShape, let c = shapes.countries.first(where: { $0.id == i }) {
                    HStack {
                        Text("No cuisine page for \(c.name) yet.").font(Theme.callout).foregroundStyle(Theme.muted)
                        Spacer()
                        Button("Suggest one") { suggest(c.name) }.font(Theme.callout600)
                    }
                    .padding(Space.m)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.large))
                    .overlay(RoundedRectangle(cornerRadius: Radius.large).strokeBorder(Theme.line))
                    .padding(.horizontal, Space.m).padding(.bottom, Space.s)
                    .transition(.opacity)
                } else if !shapes.loaded {
                    HStack(spacing: Space.s) {
                        ProgressView().tint(Theme.muted)
                        Text("Drawing the borders…").font(Theme.caption).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, Space.m).padding(.vertical, Space.s)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, Space.s)
                }
            }
            .animation(Theme.motion(reduceMotion), value: selected)
            .animation(Theme.motion(reduceMotion), value: selectedShape)
            .sensoryFeedback(.selection, trigger: selected)
            .navigationDestination(for: Route.self) { $0.view }
            .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "cx", let ref = AppLink.ref(from: url) else { return .systemAction }
            path.append(store.route(ref))
            return .handled
        })
        .task { await shapes.load(national: store.national, regionRefs: store.regionRefs) }
        .onAppear(perform: focus)
        .onChange(of: app.mapFocus) { focus() }
        .onChange(of: shapes.loaded) { focus() }
    }

    // MARK: What's drawn

    private var shaped: Set<String> {
        var s = Set(shapes.countries.flatMap(\.refs))
        if showRegions { s.formUnion(shapes.regions.flatMap(\.refs)) }
        return s
    }

    private struct Arc { let route: Store.Route3; let from: CLLocationCoordinate2D; let to: CLLocationCoordinate2D; let lit: Bool }
    private var arcs: [Arc] {
        let sel = selected
        let selIso = sel.flatMap { ref in store.national.first { $0.value == ref }?.key }
        return store.routes.compactMap { r in
            guard let a = store.national[r.from].flatMap(store.place), let b = store.national[r.to].flatMap(store.place) else { return nil }
            let lit = r.ref == sel || (selIso != nil && (r.from == selIso || r.to == selIso))
            return Arc(route: r, from: a.coordinate, to: b.coordinate, lit: lit)
        }
    }

    private var dotPlaces: [Store.Place] {
        let covered = shaped
        return store.places.filter { p in
            if p.ref == selected { return !covered.contains(p.ref) }
            guard let n = store.node(p.ref), !covered.contains(p.ref) else { return false }
            // National cuisines without a country shape (Palestine, Kosovo) show from afar; the rest when close
            return n.isNational || span < 40
        }
    }

    private func color(_ ref: String) -> Color {
        let key = store.continent(ref)
        return Store.continents.first { $0.key == key }?.color ?? Theme.elsewhere
    }

    private func fill(_ s: MapShape) -> Color {
        s.ref.map(color) ?? Theme.muted.opacity(0.6)
    }

    private func isSelected(_ s: MapShape) -> Bool {
        if let selected { return s.refs.contains(selected) }
        return selectedShape == s.id && s.refs.isEmpty
    }

    private func labelPoint(_ s: MapShape) -> CLLocationCoordinate2D {
        // The middle of the largest polygon's bounds, which is close enough for a label
        let big = s.polygons.max { $0.boundingMapRect.width * $0.boundingMapRect.height < $1.boundingMapRect.width * $1.boundingMapRect.height }!
        return MKMapPoint(x: big.boundingMapRect.midX, y: big.boundingMapRect.midY).coordinate
    }

    // MARK: Selection

    private func select(_ ref: String) {
        withAnimation(Theme.motion(reduceMotion)) { selected = ref; selectedShape = nil }
    }

    private func suggest(_ country: String) {
        let title = "\(country): add its cuisine".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://github.com/kyle-pace/cuisine-explorer/issues/new?title=\(title)") { UIApplication.shared.open(url) }
    }

    private func focus() {
        // Wait for the shapes, so a country or region can be framed (onChange(loaded) calls again)
        guard let ref = app.mapFocus, shapes.loaded else { return }
        app.mapFocus = nil
        path = []
        selected = ref
        selectedShape = nil
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) {
            if let s = shapes.shape(for: ref) {
                let r = s.bounds
                position = .rect(r.insetBy(dx: -r.width * 0.3, dy: -r.height * 0.3))
            } else if let p = store.place(ref) {
                position = .region(MKCoordinateRegion(center: p.coordinate, span: .init(latitudeDelta: 10, longitudeDelta: 10)))
            }
        }
    }
}

struct PlaceCard: View {
    @Environment(Store.self) private var store
    let node: Store.Node
    let open: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            if let url = store.photo(node.ref) {
                RemoteImage(url: url).frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name).font(Theme.callout600).foregroundStyle(Theme.ink)
                Text(node.sub).font(Theme.caption).foregroundStyle(Theme.muted).lineLimit(2)
                Button(action: open) {
                    Text("Open").font(Theme.callout600)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Theme.ink, in: Capsule())
                        .foregroundStyle(Theme.ground)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
            Button(action: close) {
                Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(Theme.muted)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Close")
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(12)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Theme.line))
        .contentShape(RoundedRectangle(cornerRadius: Radius.large))
        .onTapGesture(perform: open)
    }
}
