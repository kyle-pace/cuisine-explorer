import SwiftUI

/// Home: a few cuisines to start from, then every way into the collection
struct ExploreView: View {
    @Environment(Store.self) private var store
    @Environment(Library.self) private var library
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var featured: [Store.Node] = []
    @State private var settings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The world’s cuisines")
                        .font(Theme.title)
                        .foregroundStyle(Theme.ink)
                    Text("\(count(.cuisine)) cuisines, \(count(.dish)) dishes and \(count(.ingredient)) ingredients, each linked to the others.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, Space.xl)

                // One dish a day, the same for everyone that day
                if let dish = dailyDish {
                    NavigationLink(value: Route.item(dish.ref)) {
                        ZStack(alignment: .bottomLeading) {
                            RemoteImage(url: store.photo(dish.ref)).frame(height: 210).clipped()
                            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Today’s dish").font(Theme.caption.weight(.bold)).foregroundStyle(.white.opacity(0.8)).textCase(.uppercase).tracking(0.8)
                                Text(dish.name).font(Theme.heading).foregroundStyle(.white)
                                Text(dish.sub).font(Theme.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                            }
                            .padding(Space.l)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
                        .overlay(RoundedRectangle(cornerRadius: Radius.large).strokeBorder(Theme.line))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Space.xl)
                    .accessibilityLabel("Today’s dish: \(dish.name), \(dish.sub)")
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionHeader("Start somewhere")
                        Spacer()
                        Button("Shuffle", systemImage: "shuffle") { pickFeatured() }
                            .font(Theme.callout600)
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Show other cuisines")
                    }
                    .padding(.horizontal, Space.xl)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(featured) { n in
                                NavigationLink(value: Route.item(n.ref)) { FeatureCard(node: n) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, Space.xl)
                    }
                    .scrollTargetBehavior(.viewAligned)
                }

                if !library.recent.isEmpty || !library.saved.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        NavigationLink(value: Route.hub("x:recent")) {
                            SectionHeader("Pick up where you left off", chevron: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Space.xl)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Space.s) {
                                if !library.saved.isEmpty {
                                    NavigationLink(value: Route.hub("x:saved")) {
                                        Label("Saved \(library.saved.count)", systemImage: "bookmark.fill")
                                            .font(Theme.callout600).foregroundStyle(Theme.onAccent)
                                            .padding(.horizontal, 14).padding(.vertical, 9)
                                            .background(Theme.accent, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                ForEach(library.recent.prefix(12).compactMap(store.node)) { n in
                                    NavigationLink(value: Route.item(n.ref)) {
                                        HStack(spacing: 8) {
                                            Mark(color: n.color, square: n.type != .cuisine)
                                            Text(n.name).font(Theme.callout).foregroundStyle(Theme.ink).lineLimit(1)
                                        }
                                        .padding(.horizontal, 14).padding(.vertical, 9)
                                        .background(Theme.surface, in: Capsule())
                                        .overlay(Capsule().strokeBorder(Theme.line))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Space.xl)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Cuisines by continent")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Store.continents, id: \.slug) { c in
                            NavigationLink(value: Route.hub("cuisines#\(c.slug)")) {
                                ContinentTile(name: c.name, color: c.color,
                                              count: store.hub("cuisines#\(c.slug)").nodes.count)
                            }
                            .buttonStyle(.plain)
                        }
                        NavigationLink(value: Route.hub("x:beyond")) {
                            ContinentTile(name: "Beyond borders", color: Theme.elsewhere,
                                          count: store.hub("x:beyond").nodes.count)
                        }
                        .buttonStyle(.plain)
                    }
                    NavigationLink(value: Route.hub("x:indigenous")) {
                        HStack(spacing: 12) {
                            Mark(color: Theme.tomatillo, size: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Indigenous foodways").font(Theme.callout600).foregroundStyle(Theme.ink)
                                Text("Peoples of Alaska, the Americas and beyond").font(Theme.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted).font(.footnote.weight(.semibold))
                        }
                        .padding(16)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Theme.line))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Space.xl)

                // Ingredients are a good way in: the most-cooked-with ones, with photos
                VStack(alignment: .leading, spacing: Space.m) {
                    NavigationLink(value: Route.hub("ingredients")) {
                        SectionHeader("Browse by ingredient", trailing: "All \(count(.ingredient))", chevron: true)
                    }
                    .buttonStyle(.plain)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s), count: 3), spacing: Space.s) {
                        ForEach(topIngredients) { n in
                            NavigationLink(value: Route.item(n.ref)) {
                                ZStack(alignment: .bottomLeading) {
                                    RemoteImage(url: store.photo(n.ref)).frame(height: 96).clipped()
                                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                                    Text(n.name).font(Theme.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(1).padding(8)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(n.name)
                        }
                    }
                }
                .padding(.horizontal, Space.xl)

                // A way into walk mode from the start, as the web's home offers
                if let start = featured.first {
                    NavigationLink(value: Route.walk(start.ref)) {
                        HStack(spacing: Space.m) {
                            RadialGraph(center: start.ref, neighbors: Array(store.neighbors(start.ref).prefix(8)), labels: false, compact: true)
                                .frame(width: 72, height: 72)
                                .allowsHitTesting(false)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Wander the web").font(Theme.callout600).foregroundStyle(Theme.ink)
                                Text("Start from \(start.name) and follow the links from dish to ingredient to cuisine.")
                                    .font(Theme.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted).font(.footnote.weight(.semibold))
                        }
                        .padding(Space.m)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.large))
                        .overlay(RoundedRectangle(cornerRadius: Radius.large).strokeBorder(Theme.line))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Space.xl)
                }

                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader("Browse everything")
                    ForEach([Store.Kind.dish, .ingredient, .book, .site], id: \.self) { kind in
                        NavigationLink(value: Route.hub(kind.hub)) {
                            HStack {
                                Text(kind.plural).font(Theme.body).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(count(kind))").font(Theme.callout).foregroundStyle(Theme.muted)
                                Image(systemName: "chevron.right").foregroundStyle(Theme.muted).font(.footnote.weight(.semibold))
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
                    .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .background(Theme.ground)
        .toolbarBackground(Theme.ground, for: .navigationBar)
        .onAppear { if featured.isEmpty { pickFeatured() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") { settings = true }
            }
        }
        .sheet(isPresented: $settings) { SettingsView() }
    }

    private func count(_ kind: Store.Kind) -> Int { store.nodes.lazy.filter { $0.type == kind }.count }

    /// The nine ingredients cooked with most, among those with a photo
    private var topIngredients: [Store.Node] {
        store.nodes.filter { $0.type == .ingredient && store.hasPhoto($0.ref) }
            .sorted { store.linkCount($0.ref) > store.linkCount($1.ref) }
            .prefix(9).map { $0 }
    }

    /// Picked from the dishes with photos by the day of the year, so it changes at midnight
    private var dailyDish: Store.Node? {
        Daily.dish(from: store.nodes.filter { $0.type == .dish && store.hasPhoto($0.ref) }.map(\.ref)).flatMap(store.node)
    }

    private func pickFeatured() {
        let withPhotos = store.nodes.filter { $0.type == .cuisine && store.hasPhoto($0.ref) }
        featured = Array(withPhotos.shuffled().prefix(8))
    }
}

struct FeatureCard: View {
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let node: Store.Node
    private var width: CGFloat { typeSize.isAccessibilitySize ? 300 : 240 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: store.photo(node.ref))
                .frame(width: width, height: 170)
                .clipped()
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Mark(color: node.color)
                    Text(node.name).font(Theme.callout600).foregroundStyle(Theme.ink).lineLimit(2)
                }
                Text(node.sub).font(Theme.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            .padding(12)
            .frame(width: width, alignment: .leading)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Theme.line))
        .accessibilityElement(children: .combine)
    }
}

struct ContinentTile: View {
    let name: String
    let color: Color
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Circle().fill(color).frame(width: 14, height: 14)
            Spacer(minLength: 12)
            Text(name).font(Theme.callout600).foregroundStyle(Theme.ink)
            Text("\(count) cuisines").font(Theme.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(colors: [color.opacity(0.22), Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Theme.line))
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
    private var continentFacets: Bool { ["dishes", "ingredients", "cookbooks", "sites"].contains(ref) }

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
                    Button("Show on the map", systemImage: "map") { app.showOnMap(node.ref) }
                }
                Button("Explore connections", systemImage: "point.3.connected.trianglepath.dotted") {
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
                ZStack { RoundedRectangle(cornerRadius: Radius.small).fill(Theme.surface); Mark(color: node.color, square: node.type != .cuisine) }
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

/// The search tab: everything, by name
struct SearchView: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    @State private var scope: Scope = .all

    enum Scope: Hashable, CaseIterable { case all, cuisine, dish, ingredient, book, site
        var title: String { ["Everything", "Cuisines", "Dishes", "Ingredients", "Cookbooks", "Sites"][Scope.allCases.firstIndex(of: self)!] }
        var kind: Store.Kind? { [nil, .cuisine, .dish, .ingredient, .book, .site][Scope.allCases.firstIndex(of: self)!] }
    }

    var body: some View {
        @Bindable var app = app
        let query = app.searchQuery
        let all = store.search(query, limit: 200)
        let results = scope.kind.map { k in all.filter { $0.type == k } } ?? Array(all.prefix(80))
        List(results) { n in
            NavigationLink(value: Route.item(n.ref)) { NodeRow(node: n) }
                .listRowBackground(Theme.ground)
                .listRowSeparatorTint(Theme.line)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle("Search")
        .searchable(text: $app.searchQuery, prompt: "Cuisines, dishes, ingredients")
        .searchScopes($scope, activation: .onSearchPresentation) {
            ForEach(Scope.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .overlay {
            if query.isEmpty {
                ContentUnavailableView("Find anything", systemImage: "magnifyingglass",
                                       description: Text("Try “mole”, “seal oil” or “Sichuan”."))
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
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
