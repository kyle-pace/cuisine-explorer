import SwiftUI

/// Home: a few cuisines to start from, then every way into the collection
struct ExploreView: View {
    @Environment(Store.self) private var store
    @State private var featured: [Store.Node] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The world’s cuisines")
                        .font(Theme.title)
                        .foregroundStyle(Theme.rice)
                    Text("\(count(.cuisine)) cuisines, \(count(.dish)) dishes and \(count(.ingredient)) ingredients, each linked to the others.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionTitle("Start somewhere")
                        Spacer()
                        Button("Shuffle", systemImage: "shuffle") { pickFeatured() }
                            .font(Theme.callout600)
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Show other cuisines")
                    }
                    .padding(.horizontal, 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(featured) { n in
                                NavigationLink(value: Route.item(n.ref)) { FeatureCard(node: n) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 20)
                    }
                    .scrollTargetBehavior(.viewAligned)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Cuisines by continent")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Store.continents, id: \.slug) { c in
                            NavigationLink(value: Route.hub("cuisines#\(c.slug)")) {
                                ContinentTile(name: c.name, color: c.color,
                                              count: store.hub("cuisines#\(c.slug)").nodes.count)
                            }
                            .buttonStyle(.plain)
                        }
                        NavigationLink(value: Route.hub("x:beyond")) {
                            ContinentTile(name: "Beyond borders", color: Theme.muted,
                                          count: store.hub("x:beyond").nodes.count)
                        }
                        .buttonStyle(.plain)
                    }
                    NavigationLink(value: Route.hub("x:indigenous")) {
                        HStack(spacing: 12) {
                            Mark(color: Theme.tomatillo, size: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Indigenous foodways").font(Theme.callout600).foregroundStyle(Theme.rice)
                                Text("Peoples of Alaska, the Americas and beyond").font(Theme.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted).font(.footnote.weight(.semibold))
                        }
                        .padding(16)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 4) {
                    SectionTitle("Everything")
                    ForEach([Store.Kind.dish, .ingredient, .book, .site], id: \.self) { kind in
                        NavigationLink(value: Route.hub(kind.hub)) {
                            HStack {
                                Text(kind.plural).font(Theme.body).foregroundStyle(Theme.rice)
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
                .padding(.horizontal, 20)

                Text("Intros from Wikipedia (CC BY-SA), photos from Wikimedia Commons, production figures from FAOSTAT (CC BY 4.0), plus notes written for this explorer.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .background(Theme.night)
        .toolbarBackground(Theme.night, for: .navigationBar)
        .onAppear { if featured.isEmpty { pickFeatured() } }
    }

    private func count(_ kind: Store.Kind) -> Int { store.nodes.lazy.filter { $0.type == kind }.count }

    private func pickFeatured() {
        let withPhotos = store.nodes.filter { $0.type == .cuisine && store.hasPhoto($0.ref) }
        featured = Array(withPhotos.shuffled().prefix(8))
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(Theme.heading).foregroundStyle(Theme.rice).accessibilityAddTraits(.isHeader)
    }
}

struct FeatureCard: View {
    @Environment(Store.self) private var store
    let node: Store.Node

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: store.photo(node.ref))
                .frame(width: 240, height: 170)
                .clipped()
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Mark(color: node.color)
                    Text(node.name).font(Theme.callout600).foregroundStyle(Theme.rice).lineLimit(1)
                }
                Text(node.sub).font(Theme.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            .padding(12)
            .frame(width: 240, alignment: .leading)
        }
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
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
            Text(name).font(Theme.callout600).foregroundStyle(Theme.rice)
            Text("\(count) cuisines").font(Theme.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(colors: [color.opacity(0.22), Theme.panel], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
        .accessibilityElement(children: .combine)
    }
}

/// Every item in a hub: "Asia", "Dishes", "Indigenous foodways"…
struct HubView: View {
    @Environment(Store.self) private var store
    let ref: String
    @State private var filter = ""

    var body: some View {
        let hub = store.hub(ref)
        let list = filter.isEmpty ? hub.nodes
            : hub.nodes.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        List(list) { n in
            NavigationLink(value: Route.item(n.ref)) { NodeRow(node: n) }
                .listRowBackground(Theme.night)
                .listRowSeparatorTint(Theme.line)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.night)
        .searchable(text: $filter, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Filter \(hub.title)")
        .navigationTitle(hub.title)
        .overlay { if list.isEmpty { ContentUnavailableView.search(text: filter) } }
    }
}

struct NodeRow: View {
    @Environment(Store.self) private var store
    let node: Store.Node

    var body: some View {
        HStack(spacing: 12) {
            if let thumb = store.thumbnail(node.ref) {
                RemoteImage(url: thumb).frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack { RoundedRectangle(cornerRadius: 8).fill(Theme.panel); Mark(color: node.color, square: node.type != .cuisine) }
                    .frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name).font(Theme.body).foregroundStyle(Theme.rice)
                Text(node.sub.isEmpty ? node.type.singular : node.sub)
                    .font(Theme.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// The search tab: everything, by name
struct SearchView: View {
    @Environment(Store.self) private var store
    @State private var query = ""

    var body: some View {
        let results = store.search(query)
        List(results) { n in
            NavigationLink(value: Route.item(n.ref)) { NodeRow(node: n) }
                .listRowBackground(Theme.night)
                .listRowSeparatorTint(Theme.line)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.night)
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Cuisines, dishes, ingredients")
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
