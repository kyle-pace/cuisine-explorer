import SwiftUI
import MapKit

/// Every cuisine with a place, as a dot in its continent's color. Tap one for a card.
struct MapScreen: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: .init(latitude: 25, longitude: 10), span: .init(latitudeDelta: 110, longitudeDelta: 140)))
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
                                .overlay(Circle().stroke(selected == p.ref ? Theme.rice : Theme.night.opacity(0.7),
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
            .onMapCameraChange(frequency: .onEnd) { ctx in span = ctx.region.span.latitudeDelta }
            .safeAreaInset(edge: .bottom) {
                if let ref = selected, let n = store.node(ref) {
                    PlaceCard(node: n) { path.append(.item(ref)) } close: { selected = nil }
                        .padding(.horizontal, 12).padding(.bottom, 8)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Theme.motion(reduceMotion), value: selected)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .item(let ref): ItemView(ref: ref)
                case .hub(let ref): HubView(ref: ref)
                }
            }
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

    private func dotSize(_ n: Store.Node) -> CGFloat { n.isNational ? 14 : 10 }

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
                RemoteImage(url: url).frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name).font(Theme.callout600).foregroundStyle(Theme.rice)
                Text(node.sub).font(Theme.caption).foregroundStyle(Theme.muted).lineLimit(2)
                Button(action: open) {
                    Text("Open").font(Theme.callout600)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Theme.rice, in: Capsule())
                        .foregroundStyle(Theme.night)
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
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture(perform: open)
    }
}
