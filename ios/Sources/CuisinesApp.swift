import CoreSpotlight
import SwiftUI
import TipKit

@main
struct CuisinesApp: App {
    @State private var store = Store.shared
    @State private var app = AppState.shared
    @State private var library = Library()

    var body: some Scene {
        WindowGroup {
            RootView()
                .kitchenAppearance()
                .environment(store)
                .environment(app)
                .environment(library)
                .tint(Theme.accent)
        }
    }

    init() {
        KitchenUI.registerFonts()
        Palette.use(.saffron, neutrals: .aubergine)   // the globe's colors: saffron on aubergine
        try? Tips.configure()
    }
}

/// Which tab is open, each tab's navigation path, and where the map should look
@MainActor @Observable
final class AppState {
    static let shared = AppState()
    enum Tab: Hashable { case explore, map, wander, search }
    var tab: Tab = .explore
    var explorePath: [Route] = []
    var wanderPath: [Route] = []
    var searchPath: [Route] = []
    var mapFocus: String?
    var searchQuery = ""

    func showOnMap(_ ref: String) {
        mapFocus = ref
        tab = .map
    }

    /// Opens a page, hub or walk in the Browse tab (Spotlight, Siri, widgets, Handoff, links)
    func open(_ route: Route) {
        tab = .explore
        explorePath = [route]
    }

    func search(_ query: String) {
        searchQuery = query
        tab = .search
        searchPath = []
    }

    /// cuisines://open?r=<ref>, cuisines://walk?r=<ref>, cuisines://map?r=<ref>, cuisines://search?q=
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "cuisines", let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let ref = parts.queryItems?.first { $0.name == "r" }?.value
        switch url.host() {
        case "open": if let ref { open(Store.shared.route(ref)) }
        case "walk": if let ref { open(.walk(ref)) }
        case "map": if let ref { showOnMap(ref) }
        case "search": search(parts.queryItems?.first { $0.name == "q" }?.value ?? "")
        default: return false
        }
        return true
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(Store.self) private var store

    var body: some View {
        switch store.state {
        case .ready:
            tabs
                .onAppear(perform: openFromLaunchArguments)
                .task { await Spotlight.index(store) }
                .onOpenURL { _ = app.handle($0) }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if let ref = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String { app.open(store.route(ref)) }
                }
                .onContinueUserActivity(PageActivity.type) { activity in
                    if let ref = activity.userInfo?["ref"] as? String { app.open(store.route(ref)) }
                }
        case .loading:
            VStack(spacing: 14) {
                ProgressView().tint(Theme.muted)
                Text("Setting the table…").font(Theme.callout).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.ground)
            .task { await store.start() }
        case .failed:
            ContentUnavailableView {
                Label("Couldn’t load the cuisines", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Try again") { Task { await store.start() } }.buttonStyle(.borderedProminent)
            }
            .background(Theme.ground)
        }
    }

    /// For screenshots and testing: -open <ref> opens a page, -tab map opens the map
    private func openFromLaunchArguments() {
        let args = UserDefaults.standard
        if let ref = args.string(forKey: "open") { app.tab = .explore; app.explorePath = [store.route(ref)] }
        if let ref = args.string(forKey: "walk") { app.tab = .explore; app.explorePath = [.walk(ref)] }
        if let ref = args.string(forKey: "hub") { app.tab = .explore; app.explorePath = [.hub(ref)] }
        if args.string(forKey: "tab") == "browse" { app.tab = .explore }
        if args.string(forKey: "tab") == "wander" { app.tab = .wander }
        if args.string(forKey: "tab") == "map" { app.tab = .map }
        if let ref = args.string(forKey: "map") { app.showOnMap(ref) }
    }

    private var tabs: some View {
        @Bindable var app = app
        return TabView(selection: $app.tab) {
            // Browse for reading, the map for discovery by place (as on the web), Wander for walk mode
            Tab("Browse", systemImage: "fork.knife", value: AppState.Tab.explore) {
                Stack(path: $app.explorePath) { ExploreView() }
            }
            Tab("Map", systemImage: "globe.americas", value: AppState.Tab.map) {
                MapScreen()
            }
            Tab("Wander", systemImage: "point.3.connected.trianglepath.dotted", value: AppState.Tab.wander) {
                Stack(path: $app.wanderPath) { WanderScreen() }
            }
            Tab(value: AppState.Tab.search, role: .search) {
                Stack(path: $app.searchPath) { SearchView() }
            }
        }
    }
}

/// A navigation stack that opens pages and hubs, and turns cx:// links in text into pushes
struct Stack<Content: View>: View {
    @Binding var path: [Route]
    @ViewBuilder var content: Content
    @Environment(Store.self) private var store

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: Route.self) { route in
                    route.view
                }
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "cx", let ref = AppLink.ref(from: url) else { return .systemAction }
            path.append(url.host() == "walk" ? .walk(ref) : store.route(ref))
            return .handled
        })
    }
}

/// In-app links inside text and menus: cx://open?r=<ref>, cx://walk?r=<ref>
enum AppLink {
    static func url(_ ref: String, action: String = "open") -> URL? {
        var c = URLComponents(); c.scheme = "cx"; c.host = action; c.queryItems = [.init(name: "r", value: ref)]
        return c.url
    }
    static func ref(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "r" }?.value
    }
}
