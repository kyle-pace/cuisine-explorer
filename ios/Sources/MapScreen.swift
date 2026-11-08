import SwiftUI
import MapKit

/// Every cuisine with a place, as a dot in its continent's color. Tap one for a card.
struct MapScreen: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let world = MKCoordinateRegion(center: .init(latitude: 25, longitude: 10), span: .init(latitudeDelta: 110, longitudeDelta: 140))
    static let regions: [String: MKCoordinateRegion] = [
        "africa": .init(center: .init(latitude: 4, longitude: 20), span: .init(latitudeDelta: 75, longitudeDelta: 75)),
        "the-americas": .init(center: .init(latitude: 12, longitude: -85), span: .init(latitudeDelta: 115, longitudeDelta: 115)),
        "asia": .init(center: .init(latitude: 30, longitude: 95), span: .init(latitudeDelta: 85, longitudeDelta: 95)),
        "europe": .init(center: .init(latitude: 52, longitude: 15), span: .init(latitudeDelta: 38, longitudeDelta: 45)),
        "oceania": .init(center: .init(latitude: -22, longitude: 150), span: .init(latitudeDelta: 60, longitudeDelta: 70)),
    ]
    @State private var position: MapCameraPosition = .region(MapScreen.world)
    @State private var selected: String?
    @State private var path: [Route] = []
    @State private var span: Double = 110

    var body: some View {
        NavigationStack(path: $path) {
            Map(position: $position, selection: $selected) {
                ForEach(visiblePlaces) { p in
                    if let n = store.node(p.ref) {
                        Annotation(n.name, coordinate: p.coordinate, anchor: .center) {
                            Circle()
                                .fill(color(p.ref))
                                .frame(width: dotSize(n), height: dotSize(n))
                                .overlay(Circle().stroke(selected == p.ref ? Theme.ink : Theme.ground.opacity(0.7),
                                                         lineWidth: selected == p.ref ? 3 : 1.5))
                                .scaleEffect(selected == p.ref ? 1.5 : 1)
                                .padding(10)
                                .contentShape(Circle())
                        }
                        .annotationTitles(span < 12 || selected == p.ref ? .automatic : .hidden)
                        .tag(p.ref)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .mapControls { MapCompass(); MapScaleView() }
            .safeAreaInset(edge: .top) {
                ChipRow {
                    ForEach(Store.continents, id: \.slug) { c in
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) {
                                selected = nil
                                position = .region(Self.regions[c.slug] ?? Self.world)
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
            .sensoryFeedback(.selection, trigger: selected)
            .onMapCameraChange(frequency: .onEnd) { ctx in span = ctx.region.span.latitudeDelta }
            .safeAreaInset(edge: .bottom) {
                if let ref = selected, let n = store.node(ref) {
                    PlaceCard(node: n) { path.append(.item(ref)) } close: { selected = nil }
                        .padding(.horizontal, 12).padding(.bottom, 8)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Theme.motion(reduceMotion), value: selected)
            .navigationDestination(for: Route.self) { $0.view }
            .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "cx", let ref = AppLink.ref(from: url) else { return .systemAction }
            path.append(store.route(ref))
            return .handled
        })
        .onAppear(perform: focus)
        .onChange(of: app.mapFocus) { focus() }
    }

    /// National cuisines always; regional ones once you zoom in, so the world view stays calm
    private var visiblePlaces: [Store.Place] {
        store.places.filter { p in
            span < 40 || p.ref == selected || (store.node(p.ref)?.isNational ?? false)
        }
    }

    /// Smaller dots when the whole world is in view, so Europe doesn't become one blob
    private func dotSize(_ n: Store.Node) -> CGFloat { (n.isNational ? 14 : 10) * (span > 60 ? 0.7 : 1) }

    private func color(_ ref: String) -> Color {
        let key = store.continent(ref)
        return Store.continents.first { $0.key == key }?.color ?? Theme.muted
    }

    private func focus() {
        guard let ref = app.mapFocus, let p = store.place(ref) else { return }
        app.mapFocus = nil
        path = []
        selected = ref
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) {
            position = .region(MKCoordinateRegion(center: p.coordinate, span: .init(latitudeDelta: 14, longitudeDelta: 14)))
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
