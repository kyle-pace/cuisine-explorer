import AppIntents

/// Siri and Shortcuts: "Surprise me with a cuisine", "What's today's dish", "Search Cuisines for mole"
struct RandomCuisineIntent: AppIntent {
    static let title: LocalizedStringResource = "Surprise me with a cuisine"
    static let description = IntentDescription("Opens a cuisine from somewhere in the world.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store.shared
        if store.state != .ready { await store.start() }
        guard let pick = store.nodes.filter({ $0.type == .cuisine && store.hasPhoto($0.ref) }).randomElement() else {
            return .result(dialog: "Couldn’t load the cuisines right now.")
        }
        AppState.shared.open(.item(pick.ref))
        return .result(dialog: "How about \(pick.name)?")
    }
}

struct TodaysDishIntent: AppIntent {
    static let title: LocalizedStringResource = "Today’s dish"
    static let description = IntentDescription("Opens the dish of the day.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store.shared
        if store.state != .ready { await store.start() }
        guard let dish = Daily.dish(from: store.nodes.filter { $0.type == .dish && store.hasPhoto($0.ref) }.map(\.ref)),
              let n = store.node(dish) else { return .result(dialog: "Couldn’t load the dishes right now.") }
        AppState.shared.open(.item(dish))
        return .result(dialog: "Today it’s \(n.name).")
    }
}

struct SearchCuisinesIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Cuisines"
    static let description = IntentDescription("Searches every cuisine, dish and ingredient.")
    static let openAppWhenRun = true

    @Parameter(title: "Search for") var query: String

    static var parameterSummary: some ParameterSummary { Summary("Search Cuisines for \(\.$query)") }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppState.shared.search(query)
        return .result()
    }
}

struct CuisinesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RandomCuisineIntent(), phrases: [
            "Surprise me in \(.applicationName)", "Pick a cuisine in \(.applicationName)", "Random cuisine in \(.applicationName)",
        ], shortTitle: "Surprise me", systemImageName: "shuffle")
        AppShortcut(intent: TodaysDishIntent(), phrases: [
            "Today’s dish in \(.applicationName)", "What’s today’s dish in \(.applicationName)",
        ], shortTitle: "Today’s dish", systemImageName: "fork.knife")
        AppShortcut(intent: SearchCuisinesIntent(), phrases: [
            "Search \(.applicationName)", "Search \(.applicationName) for a dish",
        ], shortTitle: "Search", systemImageName: "magnifyingglass")
    }
}
