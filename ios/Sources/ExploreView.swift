import SwiftUI

/// Home, laid out like a food magazine's contents page: photos and names, nothing decorative.
/// Color dots are kept for the map, where they mean something.
struct ExploreView: View {
    @Environment(Store.self) private var store
    @Environment(Library.self) private var library
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var settings = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 36) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("The world\u{2019}s cuisines")
                        .font(Theme.title)
                        .foregroundStyle(Theme.ink)
                    Text("\(count(.cuisine)) cuisines, \(count(.dish)) dishes and \(count(.ingredient)) ingredients, each linked to the others.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, Space.xl)

                continentChips

                if let dish = dailyDish { todaysDish(dish) }

                if !recent.isEmpty || !library.saved.isEmpty { pickUp }

                ForEach(Store.continents, id: \.slug) { c in
                    Shelf(title: c.name, hub: "cuisines#\(c.slug)", nodes: shelfCuisines(store.hub("cuisines#\(c.slug)").nodes))
                }
                Shelf(title: "Indigenous foodways", hub: "x:indigenous", nodes: shelfCuisines(store.hub("x:indigenous").nodes),
                      note: "Peoples of Alaska, the Americas and beyond")
                Shelf(title: "Beyond borders", hub: "x:beyond", nodes: shelfCuisines(store.hub("x:beyond").nodes),
                      note: "Diets, faiths, histories and styles that don\u{2019}t belong to one country")

                ingredients

                VStack(alignment: .leading, spacing: 0) {
                    ForEach([Store.Kind.cuisine, .dish, .ingredient], id: \.self) { kind in
                        NavigationLink(value: Route.hub(kind.hub)) {
                            HStack {
                                Text("Every \(kind.singular.lowercased())").font(Theme.body).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(count(kind))").font(Theme.callout).foregroundStyle(Theme.muted).monospacedDigit()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.muted).font(.footnote.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Theme.line)
                    }
                }
                .padding(.horizontal, Space.xl)

                Text("Intros from Wikipedia (CC BY-SA), photos from Wikimedia Commons, production figures from FAOSTAT (CC BY 4.0), plus notes written for this explorer.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, Space.xl)
                    .padding(.bottom, Space.xl)
            }
            .padding(.top, Space.s)
        }
        .background(Theme.ground)
        .toolbarBackground(Theme.ground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") { settings = true }
            }
        }
        .sheet(isPresented: $settings) { SettingsView() }
    }

    // MARK: Sections

    /// A row of continents up top, so each is one tap away instead of a long scroll down
    private var continentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(Store.continents, id: \.slug) { c in
                    NavigationLink(value: Route.hub("cuisines#\(c.slug)")) {
                        HStack(spacing: 6) {
                            Mark(color: c.color, size: 9)
                            Text(c.name)
                        }
                        .font(Theme.callout600).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .overlay(Capsule().stroke(Theme.line))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cuisines of \(c.name)")
                }
                NavigationLink(value: Route.hub("x:beyond")) {
                    Text("Beyond borders").font(Theme.callout600).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .overlay(Capsule().stroke(Theme.line))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.xl)
        }
    }

    /// The photo, then the words under it, as a magazine would set it
    private func todaysDish(_ dish: Store.Node) -> some View {
        NavigationLink(value: Route.item(dish.ref)) {
            VStack(alignment: .leading, spacing: Space.s) {
                RemoteImage(url: store.photo(dish.ref))
                    .frame(height: typeSize.isAccessibilitySize ? 180 : 240)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large))
                Text("Today\u{2019}s dish").font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                Text(dish.name).font(Theme.heading).foregroundStyle(Theme.ink)
                if let c = cuisineOf(dish) {
                    Text(c).font(Theme.callout).foregroundStyle(Theme.muted)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Space.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today\u{2019}s dish: \(dish.name)\(cuisineOf(dish).map { ", " + $0 } ?? "")")
    }

    private var recent: [Store.Node] {
        library.recent.compactMap(store.node).filter { Store.graphKinds.contains($0.type) }
    }

    private var pickUp: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pick up where you left off").font(Theme.heading).foregroundStyle(Theme.ink)
                Spacer()
                if !library.saved.isEmpty {
                    NavigationLink("Saved", value: Route.hub("x:saved")).font(Theme.callout600)
                }
            }
            .padding(.horizontal, Space.xl)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Space.m) {
                    ForEach(recent.prefix(10)) { n in
                        NavigationLink(value: Route.item(n.ref)) { PhotoTile(node: n, width: 104, height: 104) }
                            .buttonStyle(.plain)
                    }
                    if recent.count > 10 {
                        NavigationLink("All", value: Route.hub("x:recent")).font(Theme.callout600).padding(.top, 40)
                    }
                }
                .padding(.horizontal, Space.xl)
            }
        }
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ShelfHeader(title: "Ingredients", hub: "ingredients", count: count(.ingredient),
                        note: "The ones cooked with most, and where they\u{2019}re grown")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.m, alignment: .top), count: typeSize.isAccessibilitySize ? 2 : 3),
                      alignment: .leading, spacing: Space.l) {
                ForEach(topIngredients) { n in
                    NavigationLink(value: Route.item(n.ref)) { PhotoTile(node: n, width: nil, height: 92, showSub: false) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Space.xl)
        }
    }

    // MARK: Picks

    private func count(_ kind: Store.Kind) -> Int { store.nodes.lazy.filter { $0.type == kind }.count }

    /// A shelf shows the best-connected cuisines with a photo of their own first
    private func shelfCuisines(_ nodes: [Store.Node]) -> [Store.Node] {
        nodes.filter { store.hasPhoto($0.ref) }
            .sorted { (store.linkCount($0.ref), $1.name) > (store.linkCount($1.ref), $0.name) }
            .prefix(12).map { $0 }
    }

    private var topIngredients: [Store.Node] {
        store.nodes.filter { $0.type == .ingredient && store.hasPhoto($0.ref) }
            .sorted { store.linkCount($0.ref) > store.linkCount($1.ref) }
            .prefix(9).map { $0 }
    }

    /// Picked from the dishes with photos by the day of the year, so it changes at midnight
    private var dailyDish: Store.Node? {
        Daily.dish(from: store.nodes.filter { $0.type == .dish && store.hasPhoto($0.ref) }.map(\.ref)).flatMap(store.node)
    }

    private func cuisineOf(_ n: Store.Node) -> String? {
        store.neighbors(n.ref).first { $0.type == .cuisine }?.name
    }

}

/// A section title that leads to the full list
struct ShelfHeader: View {
    let title: String
    let hub: String
    var count: Int?
    var note: String?

    var body: some View {
        NavigationLink(value: Route.hub(hub)) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text(title).font(Theme.heading).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(count.map { "All \($0)" } ?? "All").font(Theme.callout).foregroundStyle(Theme.accent)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
                if let note { Text(note).font(Theme.callout).foregroundStyle(Theme.muted) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Space.xl)
        .accessibilityLabel("\(title), see all\(count.map { " \($0)" } ?? "")")
    }
}

/// A sideways row of cuisines with their photos
struct Shelf: View {
    @Environment(Store.self) private var store
    let title: String
    let hub: String
    let nodes: [Store.Node]
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ShelfHeader(title: title, hub: hub, count: store.hub(hub).nodes.count, note: note)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: Space.m) {
                    ForEach(nodes) { n in
                        NavigationLink(value: Route.item(n.ref)) { PhotoTile(node: n, width: 148, height: 112) }
                            .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Space.xl)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

/// A photo with its name under it. No border, no badge: the photo carries it.
struct PhotoTile: View {
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let node: Store.Node
    var width: CGFloat?
    var height: CGFloat
    var showSub = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let url = store.thumbnail(node.ref)?.absoluteString.replacingOccurrences(of: "/120px-", with: "/330px-") {
                    RemoteImage(url: URL(string: url))
                } else {
                    // No photo: the name's first letter, set large, on the surface color
                    ZStack {
                        Theme.surface
                        Text(String(node.name.prefix(1))).font(.app(34, .bold, relativeTo: .title)).foregroundStyle(Theme.muted)
                    }
                }
            }
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small))
            Text(node.name.replacingOccurrences(of: " cuisine", with: ""))
                .font(Theme.callout600).foregroundStyle(Theme.ink)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                .multilineTextAlignment(.leading)
            if showSub, !node.sub.isEmpty, !node.name.hasPrefix(node.sub) {
                Text(node.sub).font(Theme.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
        }
        .frame(width: typeSize.isAccessibilitySize && width != nil ? (width ?? 0) * 1.3 : width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Every item in a hub: "Asia", "Dishes", "Indigenous foodways"…
struct HubView: View {
    @Environment(Store.self) private var store
    @Environment(Library.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ref: String
    @State private var filter = ""
    @State private var facet: Facet = .all
    @State private var continent: String?
    @State private var sort: Sort?

    enum Sort: String, CaseIterable { case mostLinked = "Most used", alphabetical = "A to Z" }
    /// Ingredients open by how much they're cooked with; everything else A to Z
    private var order: Sort { sort ?? (ref == "ingredients" ? .mostLinked : .alphabetical) }

    /// Ways to narrow a list of cuisines
    enum Facet: String, CaseIterable { case all = "All", national = "National", regional = "Regional", indigenous = "Indigenous"
        func keeps(_ n: Store.Node) -> Bool {
            switch self {
            case .all: true
            case .national: n.isNational
            case .regional: !n.isNational && !n.isIndigenous && !n.isBeyondBorders
            case .indigenous: n.isIndigenous
            }
        }
    }

    private var hub: (title: String, nodes: [Store.Node]) {
        switch ref {
        case "x:saved": ("Saved", library.saved.compactMap(store.node))
        case "x:recent": ("Recently viewed", library.recent.compactMap(store.node))
        default: store.hub(ref)
        }
    }
    private var cuisineFacets: Bool { ref == "cuisines" || ref.hasPrefix("cuisines#") }
    private var continentFacets: Bool { ["dishes", "ingredients"].contains(ref) }

    var body: some View {
        let hub = hub
        let list = visible(hub.nodes)
        let grouped = list.count > 40 && filter.isEmpty && order == .alphabetical
        List {
            if cuisineFacets || continentFacets {
                ChipRow {
                    if cuisineFacets {
                        ForEach(Facet.allCases, id: \.self) { f in
                            let n = hub.nodes.filter(f.keeps).count
                            if n > 0 {
                                FilterChip(f.rawValue, count: f == .all ? nil : n, isOn: facet == f) {
                                    withAnimation(Theme.motion(reduceMotion)) { facet = f }
                                }
                            }
                        }
                    } else {
                        FilterChip("All", isOn: continent == nil) { withAnimation(Theme.motion(reduceMotion)) { continent = nil } }
                        ForEach(Store.continents, id: \.slug) { c in
                            FilterChip(c.name, isOn: continent == c.key) {
                                withAnimation(Theme.motion(reduceMotion)) { continent = continent == c.key ? nil : c.key }
                            }
                        }
                    }
                }
                .listRowBackground(Theme.ground)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.l, bottom: Space.s, trailing: Space.l))
            }
            if grouped {
                ForEach(letters(list), id: \.0) { letter, items in
                    Section {
                        ForEach(items) { row($0) }
                    } header: {
                        Text(letter).font(Theme.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    }
                }
            } else {
                ForEach(list) { row($0) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .searchable(text: $filter, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Filter \(Store.continents.map(\.name).contains(hub.title) ? hub.title : hub.title.lowercased())")
        .navigationTitle(hub.title)
        .navigationSubtitle(grouped ? "\(list.count)" : "")
        .toolbar {
            if ref == "x:recent", !library.recent.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { Button("Clear") { library.clearRecent() } }
            }
            if !["x:recent", "x:saved"].contains(ref) {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort", selection: Binding(get: { order }, set: { sort = $0 })) {
                            ForEach(Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
            }
        }
        .overlay {
            if list.isEmpty {
                if ref == "x:saved" {
                    ContentUnavailableView("Nothing saved yet", systemImage: "bookmark",
                                           description: Text("Tap the bookmark on any page, or swipe a row, to keep it here."))
                } else if ref == "x:recent" {
                    ContentUnavailableView("Nothing yet", systemImage: "clock", description: Text("Pages you open show up here."))
                } else {
                    ContentUnavailableView.search(text: filter)
                }
            }
        }
    }

    private func visible(_ nodes: [Store.Node]) -> [Store.Node] {
        var out = cuisineFacets ? nodes.filter(facet.keeps) : nodes
        if let continent { out = out.filter { store.continents(of: $0.ref).contains(continent) } }
        if !filter.isEmpty { out = out.filter { $0.name.localizedCaseInsensitiveContains(filter) } }
        if order == .mostLinked { out.sort { store.linkCount($0.ref) > store.linkCount($1.ref) } }
        return out
    }

    private func row(_ n: Store.Node) -> some View {
        NavigationLink(value: Route.item(n.ref)) { NodeRow(node: n) }
            .listRowBackground(Theme.ground)
            .listRowSeparatorTint(Theme.line)
            .swipeActions(edge: .trailing) {
                Button(library.isSaved(n.ref) ? "Unsave" : "Save", systemImage: library.isSaved(n.ref) ? "bookmark.slash" : "bookmark") {
                    library.toggleSaved(n.ref)
                }
                .tint(Theme.accent)
            }
    }

    /// A to Z, with everything else under #
    private func letters(_ list: [Store.Node]) -> [(String, [Store.Node])] {
        var groups: [String: [Store.Node]] = [:]
        for n in list {
            let first = n.name.folding(options: .diacriticInsensitive, locale: nil).uppercased().first.map(String.init) ?? "#"
            groups[first.rangeOfCharacter(from: .letters) != nil ? first : "#", default: []].append(n)
        }
        return groups.keys.sorted { $0 == "#" ? false : $1 == "#" ? true : $0 < $1 }.map { ($0, groups[$0]!) }
    }
}

struct NodeRow: View {
    @Environment(Store.self) private var store
    @Environment(Library.self) private var library
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    let node: Store.Node

    /// Dishes and ingredients have no place of their own; say which cuisine they belong to
    private var sub: String {
        if !node.sub.isEmpty { return node.sub }
        let links = store.neighbors(node.ref)
        if node.type == .ingredient {
            let dishes = links.filter { $0.type == .dish }.count
            return dishes > 0 ? "In \(dishes) \(dishes == 1 ? "dish" : "dishes")" : "Ingredient"
        }
        if let c = links.first(where: { $0.type == .cuisine }) { return "\(node.type.singular) · \(c.name)" }
        return node.type.singular
    }

    var body: some View {
        row
            .contextMenu {
                Button(library.isSaved(node.ref) ? "Unsave" : "Save", systemImage: library.isSaved(node.ref) ? "bookmark.slash" : "bookmark") {
                    library.toggleSaved(node.ref)
                }
                if store.place(node.ref) != nil || store.national.values.contains(node.ref) {
                    Button("Show on the globe", systemImage: "globe.americas") { app.showOnMap(node.ref) }
                }
                Button("Wander from here", systemImage: "point.3.connected.trianglepath.dotted") {
                    if let url = AppLink.url(node.ref, action: "walk") { openURL(url) }
                }
                if let url = Share.url(node.ref) { ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") } }
            } preview: {
                PagePeek(ref: node.ref)
            }
    }

    private var row: some View {
        HStack(spacing: 12) {
            if let thumb = store.thumbnail(node.ref) {
                RemoteImage(url: thumb).frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: Radius.small))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.small).fill(Theme.surface)
                    Text(String(node.name.prefix(1))).font(.app(20, .bold, relativeTo: .title3)).foregroundStyle(Theme.muted)
                }
                    .frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name).font(Theme.body).foregroundStyle(Theme.ink)
                Text(sub).font(Theme.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// The search tab: everything, by name. Before you type, your recent searches, what you
/// opened last, and a few searches to try, so the tab is never a blank page.
struct SearchView: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    @Environment(Library.self) private var library
    @State private var scope: Scope = .all

    enum Scope: Hashable, CaseIterable { case all, cuisine, dish, ingredient
        var title: String { ["Everything", "Cuisines", "Dishes", "Ingredients"][Scope.allCases.firstIndex(of: self)!] }
        var kind: Store.Kind? { [nil, .cuisine, .dish, .ingredient][Scope.allCases.firstIndex(of: self)!] }
    }
    static let tries = ["Mole", "Sichuan", "Seal oil", "Coconut milk", "Injera", "Kimchi"]

    var body: some View {
        @Bindable var app = app
        let query = app.searchQuery
        Group {
            if query.isEmpty { start } else { results(query) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle("Search")
        .searchable(text: $app.searchQuery, prompt: "Cuisines, dishes, ingredients")
        .searchScopes($scope, activation: .onSearchPresentation) {
            ForEach(Scope.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .onSubmit(of: .search) { library.searched(query) }
        // Opening a result counts as a search worth keeping
        .onChange(of: app.searchPath) { old, new in if new.count > old.count, !query.isEmpty { library.searched(query) } }
    }

    private func results(_ query: String) -> some View {
        let all = store.search(query, limit: 200)
        let results = scope.kind.map { k in all.filter { $0.type == k } } ?? Array(all.prefix(80))
        return List(results) { n in
            NavigationLink(value: Route.item(n.ref)) { NodeRow(node: n) }
                .listRowBackground(Theme.ground)
                .listRowSeparatorTint(Theme.line)
        }
        .overlay { if results.isEmpty { ContentUnavailableView.search(text: query) } }
    }

    private var recentNodes: [Store.Node] { library.recent.prefix(5).compactMap(store.node) }

    private var start: some View {
        List {
            if !library.searches.isEmpty {
                Section {
                    ForEach(library.searches, id: \.self) { q in
                        Button { app.searchQuery = q } label: {
                            Label(q, systemImage: "clock.arrow.circlepath").font(Theme.body).foregroundStyle(Theme.ink)
                        }
                        .swipeActions { Button("Remove", role: .destructive) { library.forgetSearch(q) } }
                    }
                    .listRowBackground(Theme.ground)
                } header: {
                    HStack {
                        Text("Recent searches")
                        Spacer()
                        Button("Clear") { library.clearSearches() }.font(Theme.callout)
                    }
                }
            }
            if !recentNodes.isEmpty {
                Section("Recently viewed") {
                    ForEach(recentNodes) { n in
                        NavigationLink(value: Route.item(n.ref)) { NodeRow(node: n) }
                    }
                    .listRowBackground(Theme.ground)
                }
            }
            Section("Try searching") {
                ForEach(Self.tries, id: \.self) { q in
                    Button { app.searchQuery = q } label: {
                        Label(q, systemImage: "magnifyingglass").font(Theme.body).foregroundStyle(Theme.ink)
                    }
                }
                .listRowBackground(Theme.ground)
            }
        }
        .listRowSeparatorTint(Theme.line)
    }
}

/// What a long press shows before you commit to a page
struct PagePeek: View {
    @Environment(Store.self) private var store
    let ref: String
    @State private var page: Page?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let url = store.photo(ref) {
                RemoteImage(url: url).frame(width: 320, height: 200).clipped()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(store.node(ref)?.name ?? "").font(Theme.heading).foregroundStyle(Theme.ink)
                if let page { Text(Page.summary(page, max: 220)).font(Theme.callout).foregroundStyle(Theme.muted) }
                else { Text(store.node(ref)?.sub ?? "").font(Theme.callout).foregroundStyle(Theme.muted) }
            }
            .padding(.horizontal, Space.l).padding(.bottom, Space.l)
        }
        .frame(width: 320)
        .background(Theme.surface)
        .task { page = await store.page(ref) }
    }
}
