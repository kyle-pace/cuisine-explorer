import CoreSpotlight
import UniformTypeIdentifiers

/// Every page in the iPhone's Spotlight search, so "pad thai" from the Home Screen opens it here
enum Spotlight {
    static let domain = "pages"

    @MainActor
    static func index(_ store: Store) async {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        // Once per data set: the node count plus the first and last names change when the data does
        let stamp = "\(store.nodes.count)|\(store.nodes.first?.ref ?? "")|\(store.nodes.last?.ref ?? "")"
        guard UserDefaults.standard.string(forKey: "spotlight") != stamp else { return }
        let items = store.nodes.map { n -> CSSearchableItem in
            let a = CSSearchableItemAttributeSet(contentType: .content)
            a.title = n.name
            a.contentDescription = n.sub.isEmpty ? n.type.singular : "\(n.type.singular) · \(n.sub)"
            a.keywords = [n.type.singular, n.type.plural, "cuisine", "food", "recipe"] + n.sub.split(separator: " ").map(String.init)
            a.url = Share.url(n.ref)
            return CSSearchableItem(uniqueIdentifier: n.ref, domainIdentifier: domain, attributeSet: a)
        }
        do {
            let index = CSSearchableIndex.default()
            try await index.deleteSearchableItems(withDomainIdentifiers: [domain])
            // In batches, so a 5,000-item index doesn't hold memory all at once
            for start in stride(from: 0, to: items.count, by: 500) {
                try await index.indexSearchableItems(Array(items[start..<min(start + 500, items.count)]))
            }
            UserDefaults.standard.set(stamp, forKey: "spotlight")
        } catch { /* Spotlight is a convenience; the app works without it */ }
    }
}

/// The page you're reading, for Handoff to another device (it opens the web page there)
enum PageActivity {
    static let type = "net.kylepace.cuisines.page"
}
