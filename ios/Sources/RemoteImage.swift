import SwiftUI
import UIKit

/// Loads photos from Wikimedia Commons with a User-Agent that says who's asking (their
/// policy asks for one), and keeps them on disk so each photo is fetched once.
@MainActor
final class ImageLoader {
    static let shared = ImageLoader()
    private let memory = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 20 << 20, diskCapacity: 400 << 20)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpAdditionalHeaders = ["User-Agent": "CuisineExplorer-iOS/0.1 (https://github.com/kyle-pace/cuisine-explorer)"]
        config.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: config)
        memory.countLimit = 300
    }

    func cached(_ url: URL) -> UIImage? { memory.object(forKey: url as NSURL) }

    func load(_ url: URL) async -> UIImage? {
        if let img = cached(url) { return img }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let img = UIImage(data: data) else { return nil }
        let ready = await img.byPreparingForDisplay() ?? img
        memory.setObject(ready, forKey: url as NSURL)
        return ready
    }
}

struct RemoteImage: View {
    let url: URL?
    var placeholder: Color = Theme.raised
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            placeholder
            if let image {
                Image(uiImage: image).resizable().scaledToFill().transition(.opacity)
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let hit = ImageLoader.shared.cached(url) { image = hit; return }
            let img = await ImageLoader.shared.load(url)
            withAnimation(.easeOut(duration: 0.2)) { image = img }
        }
    }
}
