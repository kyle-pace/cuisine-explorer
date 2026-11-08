import SwiftUI
import WidgetKit

/// Today's dish on the Home Screen: the same pick as the app (Daily.swift), with its photo.
/// Tapping opens the dish in the app.
@main
struct CuisinesWidgetBundle: WidgetBundle {
    var body: some Widget { TodaysDishWidget() }
}

struct TodaysDishWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "net.kylepace.cuisines.today", provider: TodayProvider()) { entry in
            TodayView(entry: entry)
                .containerBackground(for: .widget) { Color(red: 0x1B / 255, green: 0x14 / 255, blue: 0x24 / 255) }
        }
        .configurationDisplayName("Today’s dish")
        .description("A dish from somewhere in the world, new every day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let ref: String?
    let name: String
    let cuisine: String
    let image: UIImage?

    static let placeholder = TodayEntry(date: .now, ref: nil, name: "Pad thai", cuisine: "Thai cuisine", image: nil)
    static let unavailable = TodayEntry(date: .now, ref: nil, name: "Today’s dish", cuisine: "Open Cuisines to load it", image: nil)
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        Task { completion(await entry() ?? .unavailable) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        Task {
            let e = await entry() ?? .unavailable
            // New dish at midnight; if the fetch failed, try again in an hour
            let next = e.ref == nil ? Date.now.addingTimeInterval(3600)
                : Calendar.current.startOfDay(for: Date.now.addingTimeInterval(86400))
            completion(Timeline(entries: [e], policy: .after(next)))
        }
    }

    /// The skeleton (names, in a stable order) and the app index (photos), as the app loads them
    private func entry() async -> TodayEntry? {
        async let skeleton = Remote.shared.data("skeleton.json")
        async let extras = Remote.shared.data("app.json")
        guard let s = try? JSONSerialization.jsonObject(with: await skeleton ?? Data()) as? [String: Any],
              let e = try? JSONSerialization.jsonObject(with: await extras ?? Data()) as? [String: Any],
              let nodes = s["nodes"] as? [[Any]], let photos = e["photos"] as? [String: String] else { return nil }
        let dishes = nodes.compactMap { n -> (String, String)? in
            guard let ref = n[0] as? String, let name = n[1] as? String, n[2] as? Int == 1, photos[ref] != nil else { return nil }
            return (ref, name)
        }
        guard let ref = Daily.dish(from: dishes.map(\.0)), let name = dishes.first(where: { $0.0 == ref })?.1 else { return nil }
        // Its cuisine: the first cuisine linked to it
        var cuisine = ""
        if let links = s["links"] as? [[Int]], let i = nodes.firstIndex(where: { $0[0] as? String == ref }) {
            for l in links where l.count == 2 && (l[0] == i || l[1] == i) {
                let other = nodes[l[0] == i ? l[1] : l[0]]
                if other[2] as? Int == 0, let n = other[1] as? String { cuisine = n; break }
            }
        }
        var image: UIImage?
        if let p = photos[ref] {
            let host = p.hasPrefix("thumb/") ? "thumb.wikimedia.org" : "upload.wikimedia.org"
            if let url = URL(string: "https://\(host)/wikipedia/commons/\(p)"),
               let (data, _) = try? await URLSession.shared.data(from: url) {
                image = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 600, height: 600))
            }
        }
        return TodayEntry(date: .now, ref: ref, name: name, cuisine: cuisine, image: image)
    }
}

struct TodayView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = entry.image {
                Image(uiImage: img).resizable().scaledToFill()
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Today’s dish").font(.caption2.weight(.bold)).textCase(.uppercase).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.8))
                Text(entry.name).font(family == .systemSmall ? .headline : .title3.weight(.bold)).foregroundStyle(.white).lineLimit(2)
                if !entry.cuisine.isEmpty {
                    Text(entry.cuisine).font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                }
            }
            .padding(family == .systemSmall ? 12 : 16)
        }
        .widgetURL(entry.ref.flatMap { URL(string: "cuisines://open?r=\($0)") } ?? URL(string: "cuisines://open"))
        .accessibilityLabel("Today’s dish: \(entry.name)\(entry.cuisine.isEmpty ? "" : ", \(entry.cuisine)")")
    }
}
