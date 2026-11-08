import SwiftUI
import CoreLocation

/// Everything the app knows, read from the bundled data (see scripts/sync-data.mjs).
/// The skeleton is small and loaded at launch; page models are read one bucket at a time.
@MainActor @Observable
final class Store {
    static let shared = Store()
    struct Node: Identifiable, Hashable {
        let ref: String
        let name: String
        let type: Kind
        let color: Color
        let flags: Int
        let sub: String
        var id: String { ref }
        var isNational: Bool { flags & 1 != 0 }
        var isIndigenous: Bool { flags & 2 != 0 }
        var isBeyondBorders: Bool { flags & 4 != 0 }
    }

    enum Kind: Int, CaseIterable {
        case cuisine, dish, ingredient, site, book
        var plural: String { ["Cuisines", "Dishes", "Ingredients", "Recipe sites", "Cookbooks"][rawValue] }
        var singular: String { ["Cuisine", "Dish", "Ingredient", "Recipe site", "Cookbook"][rawValue] }
        var hub: String { ["cuisines", "dishes", "ingredients", "sites", "cookbooks"][rawValue] }
        var walkOrder: Int { [0, 1, 2, 4, 3][rawValue] }
    }

    struct Place: Identifiable, Hashable {
        let ref: String
        let coordinate: CLLocationCoordinate2D
        var id: String { ref }
        static func == (a: Place, b: Place) -> Bool { a.ref == b.ref }
        func hash(into h: inout Hasher) { h.combine(ref) }
    }

    /// The five continents, in the order the explorer uses, with their colors
    static let continents: [(key: String, name: String, slug: String, color: Color)] = [
        ("African cuisine", "Africa", "africa", Theme.chili),
        ("Cuisine of the Americas", "The Americas", "the-americas", Theme.tomatillo),
        ("Asian cuisine", "Asia", "asia", Theme.saffron),
        ("European cuisine", "Europe", "europe", Theme.beet),
        ("Oceanic cuisine", "Oceania", "oceania", Theme.seaglass),
    ]

    private(set) var nodes: [Node] = []
    private(set) var places: [Place] = []
    private(set) var state: LoadState = .loading
    enum LoadState { case loading, ready, failed }
    private var index: [String: Int] = [:]
    private var placeIndex: [String: Place] = [:]
    private var continentOf: [String: String] = [:]
    private var photoOf: [String: String] = [:]
    private(set) var national: [String: String] = [:]   // iso3 to the national cuisine
    private(set) var regionRefs: [[String]] = []         // cuisines per regions.geojson shape
    private(set) var routes: [Route3] = []               // diaspora cuisines: from one country to another
    struct Route3: Hashable { let ref: String, from: String, to: String }
    @ObservationIgnored private var neighborIndex: [[Int]] = []
    @ObservationIgnored private var buckets: [String: [String: Any]] = [:]
    @ObservationIgnored private var pages: [String: Page] = [:]

    /// Loads the skeleton (every page's name, type and color) and the app index
    func start() async {
        state = .loading
        async let skeleton = Remote.shared.data("skeleton.json")
        async let extras = Remote.shared.data("app.json")
        guard let s = Self.object(await skeleton), let e = Self.object(await extras) else {
            state = .failed
            return
        }
        var nodes: [Node] = [], index: [String: Int] = [:]
        let palette = (s["colors"] as? [String] ?? []).map { Color(hexString: $0) }
        for case let n as [Any] in s["nodes"] as? [Any] ?? [] {
            guard n.count >= 6, let ref = n[0] as? String, let name = n[1] as? String,
                  let t = n[2] as? Int, let kind = Kind(rawValue: t) else { continue }
            let c = n[3] as? Int ?? 0
            index[ref] = nodes.count
            nodes.append(Node(ref: ref, name: name, type: kind,
                              color: palette.indices.contains(c) ? palette[c] : Theme.muted,
                              flags: n[4] as? Int ?? 0, sub: n[5] as? String ?? ""))
        }
        var places: [Place] = [], placeIndex: [String: Place] = [:]
        for case let p as [Any] in e["places"] as? [Any] ?? [] {
            guard p.count == 3, let ref = p[0] as? String, let lat = (p[1] as? NSNumber)?.doubleValue,
                  let lng = (p[2] as? NSNumber)?.doubleValue else { continue }
            let place = Place(ref: ref, coordinate: .init(latitude: lat, longitude: lng))
            places.append(place)
            placeIndex[ref] = place
        }
        var neighbors = Array(repeating: [Int](), count: nodes.count)
        for case let l as [Any] in s["links"] as? [Any] ?? [] {
            guard l.count == 2, let a = l[0] as? Int, let b = l[1] as? Int,
                  nodes.indices.contains(a), nodes.indices.contains(b), a != b else { continue }
            neighbors[a].append(b); neighbors[b].append(a)
        }
        neighborIndex = neighbors.map { Array(Set($0)).sorted() }
        self.nodes = nodes; self.index = index
        self.places = places; self.placeIndex = placeIndex
        continentOf = e["cont"] as? [String: String] ?? [:]
        photoOf = e["photos"] as? [String: String] ?? [:]
        national = e["national"] as? [String: String] ?? [:]
        regionRefs = e["regions"] as? [[String]] ?? []
        routes = (e["routes"] as? [[String]] ?? []).compactMap { $0.count == 3 ? Route3(ref: $0[0], from: $0[1], to: $0[2]) : nil }
        state = .ready
    }

    private static func object(_ data: Data?) -> [String: Any]? {
        data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    // MARK: Lookups

    func node(_ ref: String) -> Node? { index[ref].map { nodes[$0] } }
    func place(_ ref: String) -> Place? { placeIndex[ref] }
    func continent(_ ref: String) -> String? { continentOf[ref] }

    /// A dish's or ingredient's continents, through the cuisines it's linked to
    func continents(of ref: String) -> Set<String> {
        if let c = continentOf[ref] { return [c] }
        var out = Set<String>()
        for n in neighbors(ref) where n.type == .cuisine { if let c = continentOf[n.ref] { out.insert(c) } }
        return out
    }

    /// Everything linked to an item: its cuisine, dishes, ingredients, sites, books and mentions.
    /// Cuisines first, then dishes, ingredients, books and sites, alphabetical within each.
    func neighbors(_ ref: String) -> [Node] {
        guard let i = index[ref], neighborIndex.indices.contains(i) else { return [] }
        return neighborIndex[i].map { nodes[$0] }.sorted {
            $0.type.walkOrder != $1.type.walkOrder ? $0.type.walkOrder < $1.type.walkOrder
                : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    func linkCount(_ ref: String) -> Int { index[ref].map { neighborIndex[$0].count } ?? 0 }

    /// A small thumbnail for lists (a cuisine without its own photo gets one of its dishes)
    func thumbnail(_ ref: String) -> URL? {
        guard let p = photoOf[ref] else { return nil }
        return Photo.wikimediaURL(p.replacingOccurrences(of: "/500px-", with: "/120px-"))
    }
    func hasPhoto(_ ref: String) -> Bool { photoOf[ref] != nil }
    func photo(_ ref: String) -> URL? { photoOf[ref].flatMap(Photo.wikimediaURL) }
    var refsWithPhotos: [String] { Array(photoOf.keys) }

    /// The page model for an item, if its bucket is already loaded
    func cachedPage(_ ref: String) -> Page? { pages[ref] }

    /// The page model for an item, fetching its bucket the first time; nil for hubs like "cuisines#asia"
    func page(_ ref: String) async -> Page? {
        if let p = pages[ref] { return p }
        let b = Self.bucketOf(ref)
        if buckets[b] == nil {
            guard let bucket = Self.object(await Remote.shared.data("items/\(b).json")) else { return nil }
            buckets[b] = bucket
        }
        guard let raw = buckets[b]?[ref] as? [String: Any] else { return nil }
        let p = Page(raw)
        pages[ref] = p
        return p
    }

    func route(_ ref: String) -> Route { index[ref] != nil ? .item(ref) : .hub(ref) }

    /// FNV-1a over UTF-16 code units, the same as render_item.js
    static func bucketOf(_ ref: String) -> String {
        var h: UInt32 = 0x811c9dc5
        for u in ref.utf16 { h ^= UInt32(u); h = h &* 0x01000193 }
        return String(format: "%02x", h & 255)
    }

    // MARK: Search and lists

    func search(_ query: String, limit: Int = 80) -> [Node] {
        let q = query.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        guard !q.isEmpty else { return [] }
        var scored: [(Int, Node)] = []
        for n in nodes {
            let name = n.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            guard let r = name.range(of: q) else { continue }
            let starts = r.lowerBound == name.startIndex ? 0 : (name[..<r.lowerBound].last == " " ? 1 : 2)
            scored.append((starts * 10 + n.type.rawValue, n))
        }
        return scored.sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1.name < $1.1.name }.prefix(limit).map(\.1)
    }

    /// What a hub address lists: "cuisines", "cuisines#asia", "dishes", "x:indigenous"…
    func hub(_ ref: String) -> (title: String, nodes: [Node]) {
        let sorted: ([Node]) -> [Node] = { $0.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
        let parts = ref.split(separator: "#", maxSplits: 1).map(String.init)
        if ref == "x:indigenous" { return ("Indigenous foodways", sorted(nodes.filter(\.isIndigenous))) }
        if ref == "x:beyond" {
            return ("Beyond borders", sorted(nodes.filter { $0.type == .cuisine && $0.isBeyondBorders && !$0.isIndigenous }))
        }
        if let kind = Kind.allCases.first(where: { $0.hub == parts[0] }) {
            var list = nodes.filter { $0.type == kind }
            var title = kind.plural
            if parts.count == 2, let c = Self.continents.first(where: { $0.slug == parts[1] }) {
                list = list.filter { continentOf[$0.ref] == c.key }
                title = c.name
            }
            return (title, sorted(list))
        }
        return (ref, [])
    }
}

/// Where a navigation stack can go
enum Route: Hashable {
    case item(String)
    case hub(String)
    case walk(String)

    @MainActor @ViewBuilder var view: some View {
        switch self {
        case .item(let ref): ItemView(ref: ref)
        case .hub(let ref): HubView(ref: ref)
        case .walk(let ref): WalkView(start: ref)
        }
    }
}
