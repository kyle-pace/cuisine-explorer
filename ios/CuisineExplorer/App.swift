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

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
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
