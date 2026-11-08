import Foundation

/// Where the data comes from. The cuisine-explorer repo's weekly rebuild commits fresh data
/// here; to serve it from somewhere else, change this one line.
enum DataSource {
    static let root = URL(string: "https://raw.githubusercontent.com/kyle-pace/cuisine-explorer/main/data/")!
    static let base = root.appendingPathComponent("web/")
}

/// Where a page lives on the web, for the share sheet. The site may move; a redirect there
/// will carry old links along, and this is the one place to change.
enum Share {
    static func url(_ ref: String) -> URL? { URL(string: "https://kylepace.dev/world-cuisine/\(ref)/") }
}

/// Fetches data files, revalidating with the server when online and falling back to the
/// on-disk cache when not, so anything already seen opens offline.
final class Remote: Sendable {
    static let shared = Remote()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 16 << 20, diskCapacity: 200 << 20,
                                   directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                                       .appendingPathComponent("data", isDirectory: true))
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = ["User-Agent": "CuisineExplorer-iOS/0.1 (https://github.com/kyle-pace/cuisine-explorer)"]
        session = URLSession(configuration: config)
    }

    /// The file's bytes, or nil when it can't be fetched and isn't cached
    func data(_ path: String, under base: URL = DataSource.base) async -> Data? {
        let url = base.appendingPathComponent(path)
        for policy in [URLRequest.CachePolicy.useProtocolCachePolicy, .returnCacheDataDontLoad] {
            let request = URLRequest(url: url, cachePolicy: policy)
            if let (data, response) = try? await session.data(for: request),
               (response as? HTTPURLResponse)?.statusCode ?? 200 == 200 {
                return data
            }
        }
        return nil
    }
}
