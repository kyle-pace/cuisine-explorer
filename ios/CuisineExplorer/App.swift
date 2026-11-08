import SwiftUI

@main
struct CuisineExplorerApp: App {
    @State private var store = Store()
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(app)
                .preferredColorScheme(.dark)
                .tint(Theme.saffron)
        }
    }
}

/// Which tab is open, each tab's navigation path, and where the map should look
@Observable
final class AppState {
    enum Tab: Hashable { case explore, map, search }
    var tab: Tab = .explore
    var explorePath: [Route] = []
    var searchPath: [Route] = []
    var mapFocus: String?

    func showOnMap(_ ref: String) {
        mapFocus = ref
        tab = .map
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(Store.self) private var store

    var body: some View {
        switch store.state {
        case .ready: tabs.onAppear(perform: openFromLaunchArguments)
        case .loading:
            VStack(spacing: 14) {
                ProgressView().tint(Theme.muted)
                Text("Setting the table…").font(Theme.callout).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.night)
            .task { await store.start() }
        case .failed:
            ContentUnavailableView {
                Label("Couldn’t load the cuisines", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Try again") { Task { await store.start() } }.buttonStyle(.borderedProminent)
            }
            .background(Theme.night)
        }
    }

    /// For screenshots and testing: -open <ref> opens a page, -tab map opens the map
    private func openFromLaunchArguments() {
        let args = UserDefaults.standard
        if let ref = args.string(forKey: "open") { app.explorePath = [store.route(ref)] }
        if args.string(forKey: "tab") == "map" { app.tab = .map }
        if let ref = args.string(forKey: "map") { app.showOnMap(ref) }
    }

    private var tabs: some View {
        @Bindable var app = app
        return TabView(selection: $app.tab) {
            Tab("Explore", systemImage: "fork.knife", value: AppState.Tab.explore) {
                Stack(path: $app.explorePath) { ExploreView() }
            }
            Tab("Map", systemImage: "globe.americas", value: AppState.Tab.map) {
                MapScreen()
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
                    switch route {
                    case .item(let ref): ItemView(ref: ref)
                    case .hub(let ref): HubView(ref: ref)
                    }
                }
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "cx", let ref = AppLink.ref(from: url) else { return .systemAction }
            path.append(store.route(ref))
            return .handled
        })
    }
}

/// In-app links inside text: cx://open?r=<ref>
enum AppLink {
    static func url(_ ref: String) -> URL? {
        var c = URLComponents(); c.scheme = "cx"; c.host = "open"; c.queryItems = [.init(name: "r", value: ref)]
        return c.url
    }
    static func ref(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "r" }?.value
    }
}
