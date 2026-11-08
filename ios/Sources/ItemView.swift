import SwiftUI

/// One cuisine, dish, ingredient, recipe site or cookbook, drawn natively from its page model
struct ItemView: View {
    @Environment(Store.self) private var store
    @Environment(Library.self) private var library
    let ref: String
    @State private var page: Page?
    @State private var missing = false

    var body: some View {
        Group {
            if let page {
                ScrollViewReader { proxy in
                    ScrollView {
                        PageContent(page: page)
                            .padding(.horizontal, Space.xl)
                            .padding(.bottom, 40)
                    }
                    .task {
                        // For screenshots: -scrollTo "Where it's grown"
                        guard let title = UserDefaults.standard.string(forKey: "scrollTo") else { return }
                        try? await Task.sleep(for: .milliseconds(600))
                        withAnimation { proxy.scrollTo(title, anchor: .top) }
                    }
                }
            } else if missing {
                ContentUnavailableView {
                    Label("Couldn’t open this page", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Try again") { Task { await load() } }.buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView().tint(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.ground)
        .navigationTitle(page?.name ?? store.node(ref)?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(library.isSaved(ref) ? "Saved" : "Save", systemImage: library.isSaved(ref) ? "bookmark.fill" : "bookmark") {
                    library.toggleSaved(ref)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: library.isSaved(ref))
                if let url = Share.url(ref) {
                    ShareLink(item: url, subject: Text(page?.name ?? ""), message: Text(page.map { Page.summary($0) } ?? ""))
                }
            }
        }
        .task(id: ref) { await load() }
    }

    private func load() async {
        missing = false
        page = store.cachedPage(ref)
        if page == nil { page = await store.page(ref); missing = page == nil }
        if page != nil { library.visited(ref) }
    }
}

struct PageContent: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    let page: Page

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !page.crumb.isEmpty {
                Text(crumb).font(Theme.caption).foregroundStyle(Theme.muted).padding(.top, 8).padding(.bottom, 6)
            }
            if let isbn = page.isbn {
                RemoteImage(url: URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg?default=false"), placeholder: .clear)
                    .frame(width: 110, height: 165)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.vertical, 8)
                    .accessibilityHidden(true)
            }
            Text(page.name)
                .font(Theme.title)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                Mark(color: page.dot, square: page.square)
                Text(page.sub).font(Theme.callout).foregroundStyle(Theme.muted)
                if page.suggested { Tag(text: "Suggested") }
            }
            .padding(.top, 8)
            if let names = page.names {
                Text(names).font(Theme.callout).foregroundStyle(Theme.muted).padding(.top, 6)
            }
            if let photo = page.photo {
                PhotoView(photo: photo, name: page.name).padding(.top, Space.l)
            }
            ForEach(Array(page.intro.enumerated()), id: \.offset) { _, para in
                Text(attributed(para))
                    .font(Theme.bodyLarge)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }
            sourceLine.padding(.top, 10)

            actions.padding(.top, 18)

            ForEach(page.sections) { s in
                SectionView(section: s).padding(.top, 30).id(s.title)
            }

            if store.linkCount(page.ref) > 0 {
                ConnectionsSection(ref: page.ref).padding(.top, 30).id("Connections")
            }

            if let url = URL(string: "https://github.com/kyle-pace/cuisine-explorer/issues/new?title="
                             + (page.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) {
                Text(LocalizedStringKey(String("Something wrong or missing? [Suggest a correction](\(url.absoluteString)).")))
                    .font(Theme.caption).foregroundStyle(Theme.muted).padding(.top, 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var crumb: AttributedString {
        var out = AttributedString()
        for (i, c) in page.crumb.enumerated() {
            if i > 0 { out += AttributedString(" / ") }
            out += linked(c, underline: false)
        }
        return out
    }

    private func attributed(_ para: [Page.Segment]) -> AttributedString {
        para.reduce(into: AttributedString()) { out, seg in
            switch seg {
            case .text(let t): out += AttributedString(t)
            case .link(let l): out += linked(l)
            }
        }
    }

    @ViewBuilder private var sourceLine: some View {
        if page.fromWikipedia {
            Text("Intro from Wikipedia, shared under CC BY-SA.").font(Theme.caption).foregroundStyle(Theme.muted)
        } else if page.isNote {
            let from = page.sources.compactMap { s in s.url.map { "[\(s.name)](\($0.absoluteString))" } }
            Text(LocalizedStringKey("Written for this explorer" + (from.isEmpty ? "" : " from " + from.joined(separator: ", ")) + "."))
                .font(Theme.caption).foregroundStyle(Theme.muted)
        }
    }

    private var actions: some View {
        FlowLayout(spacing: Space.s) {
            if store.place(page.ref) != nil {
                Button("Show on the map", systemImage: "map") { app.showOnMap(page.ref) }
            }
            ForEach(page.actions.filter { $0.kind != "globe" }, id: \.self) { a in
                if let url = a.url {
                    Link(destination: url) {
                        Label(a.kind == "wiki" ? "Wikipedia" : (a.label ?? "Open"), systemImage: "arrow.up.right")
                    }
                }
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .font(Theme.callout600)
    }
}

/// An inline link: to another page in the app when it has a ref, plain text otherwise
func linked(_ l: Page.Link, underline: Bool = true) -> AttributedString {
    var a = AttributedString(l.name)
    if let ref = l.ref, let url = AppLink.url(ref) {
        a.link = url
        a.foregroundColor = Theme.ink
        if underline { a.underlineStyle = .single }
    }
    return a
}

struct PhotoView: View {
    let photo: Photo
    let name: String
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Button { open = true } label: {
                RemoteImage(url: photo.url)
                    .aspectRatio(max(0.6, min(2.2, photo.width / max(photo.height, 1))), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Photo of \(photo.pictured ?? name)")
            .accessibilityHint("Opens it full screen")
            Text(credit).font(Theme.caption).foregroundStyle(Theme.muted)
        }
        .fullScreenCover(isPresented: $open) { PhotoViewer(photo: photo, name: name, credit: credit) }
    }

    fileprivate var credit: AttributedString {
        var out = AttributedString(photo.pictured.map { "Pictured: \($0). " } ?? "")
        out += AttributedString("Photo: \(photo.author), ")
        var lic = AttributedString(photo.license)
        if let u = photo.licenseURL { lic.link = u; lic.underlineStyle = .single }
        out += lic
        out += AttributedString(", via ")
        var commons = AttributedString("Wikimedia Commons")
        if let u = photo.page { commons.link = u; commons.underlineStyle = .single }
        out += commons
        return out
    }
}

struct SectionView: View {
    let section: Page.Section

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.title).font(Theme.heading).foregroundStyle(Theme.ink)
                if let n = section.count { Text("\(n)").font(Theme.callout).foregroundStyle(Theme.muted) }
            }
            .accessibilityAddTraits(.isHeader)
            switch section.body {
            case .rows(let rows):
                VStack(spacing: 8) { ForEach(rows, id: \.self) { RowCard(row: $0) } }
            case .links(let links, let note):
                LinkChips(links: links)
                if let note { Text(note).font(Theme.caption).foregroundStyle(Theme.muted) }
            case .groups(let groups):
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                        GroupBlock(head: g.0, links: g.1)
                    }
                }
            case .grown(let g):
                GrownChart(grown: g)
            case .empty(let text, let tryLinks):
                Text(emptyText(text, tryLinks)).font(Theme.body).foregroundStyle(Theme.muted)
            }
        }
    }

    private func emptyText(_ text: String, _ links: [Page.Link]) -> AttributedString {
        var out = AttributedString(text)
        if !links.isEmpty {
            out += AttributedString(". Try ")
            for (i, l) in links.enumerated() {
                if i > 0 { out += AttributedString(" or ") }
                out += linked(l)
            }
        }
        out += AttributedString(".")
        return out
    }
}

struct RowCard: View {
    @Environment(Store.self) private var store
    let row: Page.Row

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Mark(color: row.color, square: !row.isCuisine).padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.name).font(Theme.callout600).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    if row.suggested { Tag(text: "Suggested") }
                }
                if !row.sub.isEmpty { Text(row.sub).font(Theme.caption).foregroundStyle(Theme.muted) }
                if let note = row.note, !note.isEmpty {
                    Text(note).font(Theme.caption).foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let url = row.url {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.muted).frame(width: 32, height: 32).contentShape(Rectangle())
                }
                .accessibilityLabel("Open \(row.name)")
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Theme.line))
        .overlay {
            if let ref = row.ref {
                NavigationLink(value: store.route(ref)) { Color.clear }
                    .padding(.trailing, row.url == nil ? 0 : 48)
                    .accessibilityLabel(row.name)
            }
        }
    }
}

struct LinkChips: View {
    @Environment(Store.self) private var store
    let links: [Page.Link]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(links.enumerated()), id: \.offset) { _, l in
                if let ref = l.ref {
                    NavigationLink(value: store.route(ref)) { chip(l.name, linked: true) }.buttonStyle(.plain)
                } else {
                    chip(l.name, linked: false)
                }
            }
        }
    }

    private func chip(_ name: String, linked: Bool) -> some View {
        Text(name)
            .font(Theme.callout)
            .foregroundStyle(linked ? Theme.ink : Theme.muted)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(linked ? Theme.surface : .clear, in: Capsule())
            .overlay(Capsule().stroke(Theme.line))
    }
}

struct GroupBlock: View {
    @Environment(Store.self) private var store
    let head: Page.Link
    let links: [Page.Link]
    @State private var open = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(Theme.line)
            Button {
                withAnimation(Theme.motion(reduceMotion)) { open.toggle() }
            } label: {
                HStack {
                    Text(head.name).font(Theme.callout600).foregroundStyle(Theme.ink)
                    Text("\(links.count)").font(Theme.caption).foregroundStyle(Theme.muted)
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0))
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(open ? "Hides its items" : "Shows its items")
            if open {
                if let ref = head.ref {
                    NavigationLink(value: store.route(ref)) {
                        Text("Open \(head.name)").font(Theme.caption).underline().foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(.plain)
                }
                LinkChips(links: links).padding(.bottom, 6)
            }
        }
    }
}

struct GrownChart: View {
    @Environment(Store.self) private var store
    let grown: Page.Grown

    var body: some View {
        let max = grown.top.first?.1 ?? 1
        VStack(alignment: .leading, spacing: 10) {
            Text("Top producers of \(grown.what), averaged over \(grown.years).")
                .font(Theme.callout).foregroundStyle(Theme.muted)
            ForEach(Array(grown.top.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let ref = item.0.ref {
                            NavigationLink(value: store.route(ref)) {
                                Text(item.0.name).underline().foregroundStyle(Theme.ink)
                            }.buttonStyle(.plain)
                        } else {
                            Text(item.0.name).foregroundStyle(Theme.ink)
                        }
                        Spacer()
                        Text(Self.tonnes(item.1)).foregroundStyle(Theme.muted)
                    }
                    .font(Theme.callout)
                    GeometryReader { geo in
                        Capsule().fill(Theme.tomatillo)
                            .frame(width: Swift.max(4, geo.size.width * item.1 / max))
                    }
                    .frame(height: 6)
                    .accessibilityHidden(true)
                }
            }
            if let url = grown.url {
                Text(LocalizedStringKey(String("Production data from [FAO, FAOSTAT](\(url.absoluteString)), CC BY 4.0. The world grows about \(Self.tonnes(grown.world)) a year.")))
                    .font(Theme.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    /// Same wording as render_item.js tonnes()
    static func tonnes(_ t: Double) -> String {
        if t >= 1e6 { return String(format: t >= 1e7 ? "%.0f million tonnes" : "%.1f million tonnes", t / 1e6) }
        let f = NumberFormatter(); f.numberStyle = .decimal
        if t >= 1000 { return "\(f.string(from: NSNumber(value: (t / 1000).rounded())) ?? "") thousand tonnes" }
        return "\(f.string(from: NSNumber(value: t.rounded())) ?? "") tonnes"
    }
}

/// The page's place in the web: a small ring of what links here, and a way into walk mode
struct ConnectionsSection: View {
    @Environment(Store.self) private var store
    let ref: String

    var body: some View {
        let all = store.neighbors(ref)
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text("Connections").font(Theme.heading).foregroundStyle(Theme.ink)
                Text("\(all.count)").font(Theme.callout).foregroundStyle(Theme.muted)
            }
            .accessibilityAddTraits(.isHeader)
            NavigationLink(value: Route.walk(ref)) {
                VStack(spacing: 0) {
                    RadialGraph(center: ref, neighbors: Array(all.prefix(14)), labels: false, compact: true)
                        .frame(height: 170)
                        .allowsHitTesting(false)
                    HStack {
                        Text(summary(all)).font(Theme.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                        Spacer()
                        Label("Explore", systemImage: "arrow.right").font(Theme.callout600).labelStyle(.titleAndIcon)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.horizontal, Space.l).padding(.bottom, Space.m)
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.large))
                .overlay(RoundedRectangle(cornerRadius: Radius.large).strokeBorder(Theme.line.opacity(0.7)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Explore the \(all.count) connections of this page")
        }
    }

    private func summary(_ all: [Store.Node]) -> String {
        let parts = Store.Kind.allCases.compactMap { k -> String? in
            let n = all.filter { $0.type == k }.count
            return n > 0 ? "\(n) \(n == 1 ? k.singular.lowercased() : k.plural.lowercased())" : nil
        }
        return "Linked to " + parts.joined(separator: ", ") + ". Tap a dot to walk the web from here."
    }
}

/// A photo full screen, pinch to zoom, with its credit
struct PhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let photo: Photo
    let name: String
    let credit: AttributedString

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            ZoomableImage(url: photo.url).ignoresSafeArea()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(.black.opacity(0.45), in: Circle())
            }
            .padding(Space.l)
            .accessibilityLabel("Close")
        }
        .overlay(alignment: .bottom) {
            Text(credit).font(Theme.caption).foregroundStyle(.white.opacity(0.85)).tint(.white)
                .padding(Space.l).frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.45))
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
}

/// UIScrollView zooming, which SwiftUI still doesn't have built in
struct ZoomableImage: UIViewRepresentable {
    let url: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 5
        scroll.showsVerticalScrollIndicator = false; scroll.showsHorizontalScrollIndicator = false
        scroll.backgroundColor = .clear
        let image = UIImageView()
        image.contentMode = .scaleAspectFit
        image.frame = scroll.bounds
        image.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.addSubview(image)
        context.coordinator.image = image
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(tap)
        if let url {
            Task { @MainActor in image.image = await ImageLoader.shared.load(url) }
        }
        return scroll
    }

    func updateUIView(_ view: UIScrollView, context: Context) {}

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var image: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { image }
        @objc func doubleTap(_ g: UITapGestureRecognizer) {
            guard let scroll = g.view as? UIScrollView else { return }
            if scroll.zoomScale > 1 { scroll.setZoomScale(1, animated: true) }
            else {
                let p = g.location(in: image)
                let w = scroll.bounds.width / 2.5, h = scroll.bounds.height / 2.5
                scroll.zoom(to: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), animated: true)
            }
        }
    }
}
