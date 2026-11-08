import SwiftUI

/// One page model from scripts/build_web.mjs, the same thing render_item.js turns into HTML.
struct Page {
    struct Link: Hashable { let name: String; let ref: String? }
    enum Segment { case text(String), link(Link) }
    struct Source: Hashable { let name: String; let url: URL? }
    struct Action: Hashable { let kind: String; let url: URL?; let label: String? }
    struct Row: Hashable {
        let name: String, ref: String?, color: Color, isCuisine: Bool
        let sub: String, note: String?, url: URL?, suggested: Bool
    }
    struct Grown { let what: String, years: String, url: URL?, world: Double; let top: [(Link, Double)] }
    enum Body {
        case rows([Row])
        case links([Link], note: String?)
        case groups([(Link, [Link])])
        case grown(Grown)
        case empty(String, tryLinks: [Link])
    }
    struct Section: Identifiable { let id: Int; let title: String; let count: Int?; let body: Body }

    let ref: String
    let type: String
    let name: String
    let sub: String
    let dot: Color
    let square: Bool
    let suggested: Bool
    let crumb: [Link]
    let names: String?
    let photo: Photo?
    let intro: [[Segment]]
    let fromWikipedia: Bool
    let isNote: Bool
    let sources: [Source]
    let actions: [Action]
    let sections: [Section]
    let isbn: String?

    init(_ m: [String: Any]) {
        ref = m["r"] as? String ?? ""
        type = m["t"] as? String ?? ""
        name = m["n"] as? String ?? ""
        sub = m["sub"] as? String ?? ""
        dot = Color(hexString: (m["dot"] as? String) ?? (m["c"] as? String) ?? "#a99fb5")
        square = m["square"] as? Bool ?? false
        suggested = m["suggested"] as? Bool ?? false
        crumb = (m["crumb"] as? [Any] ?? []).compactMap(Page.link)
        names = m["names"] as? String
        photo = (m["img"] as? [String: Any]).flatMap(Photo.init)
        intro = (m["intro"] as? [[Any]] ?? []).map { para in
            para.compactMap { x in
                if let s = x as? String { return .text(s) }
                return Page.link(x).map(Segment.link)
            }
        }
        fromWikipedia = m["src"] as? String == "wikipedia"
        isNote = m["src"] as? String == "note"
        sources = (m["sources"] as? [[String: Any]] ?? []).map {
            Source(name: $0["name"] as? String ?? "", url: ($0["url"] as? String).flatMap(URL.init(string:)))
        }
        actions = (m["actions"] as? [[String: Any]] ?? []).map {
            Action(kind: $0["kind"] as? String ?? "", url: ($0["url"] as? String).flatMap(URL.init(string:)),
                   label: $0["label"] as? String)
        }
        isbn = m["isbn"] as? String
        sections = (m["sections"] as? [[String: Any]] ?? []).enumerated().compactMap { i, s in
            Page.section(i, s)
        }
    }

    static func link(_ x: Any) -> Link? {
        guard let a = x as? [Any], let name = a.first as? String else { return nil }
        return Link(name: name, ref: a.count > 1 ? a[1] as? String : nil)
    }

    private static func section(_ i: Int, _ s: [String: Any]) -> Section? {
        let title = s["h"] as? String ?? ""
        let count = s["count"] as? Int
        let body: Body
        if let rows = s["rows"] as? [[String: Any]] {
            body = .rows(rows.map { r in
                let url = (r["url"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
                return Row(name: r["name"] as? String ?? "", ref: r["ref"] as? String,
                           color: Color(hexString: r["color"] as? String ?? "#a99fb5"),
                           isCuisine: r["shape"] as? String == "cuisine",
                           sub: r["sub"] as? String ?? "", note: r["note"] as? String,
                           url: url, suggested: r["suggested"] as? Bool ?? false)
            })
        } else if let links = s["links"] as? [Any] {
            body = .links(links.compactMap(link), note: s["note"] as? String)
        } else if let groups = s["groups"] as? [[Any]] {
            body = .groups(groups.compactMap { g in
                guard g.count == 3, let l = link(g) else { return nil }
                return (l, (g[2] as? [Any] ?? []).compactMap(link))
            })
        } else if let g = s["grown"] as? [String: Any] {
            let top: [(Link, Double)] = (g["top"] as? [[Any]] ?? []).compactMap { t in
                guard t.count == 3, let l = link(t), let v = (t[2] as? NSNumber)?.doubleValue else { return nil }
                return (l, v)
            }
            body = .grown(Grown(what: g["what"] as? String ?? "", years: g["years"] as? String ?? "",
                                url: (g["url"] as? String).flatMap(URL.init(string:)),
                                world: (g["world"] as? NSNumber)?.doubleValue ?? 0, top: top))
        } else if let e = s["empty"] as? String {
            body = .empty(e, tryLinks: (s["tryLinks"] as? [Any] ?? []).compactMap(link))
        } else { return nil }
        return Section(id: i, title: title, count: count, body: body)
    }
}

/// A photo from Wikimedia Commons, with what the license asks us to show
struct Photo {
    let url: URL?
    let width: Double
    let height: Double
    let author: String
    let license: String
    let licenseURL: URL?
    let page: URL?
    let pictured: String?

    init?(_ m: [String: Any]) {
        guard let src = m["src"] as? String else { return nil }
        url = Photo.wikimediaURL(src.replacingOccurrences(of: "/labs/cuisines/img/", with: ""))
        width = (m["w"] as? NSNumber)?.doubleValue ?? 4
        height = (m["h"] as? NSNumber)?.doubleValue ?? 3
        author = m["by"] as? String ?? "Unknown"
        let lic = m["lic"] as? String ?? ""
        if lic.range(of: "^(pd|public domain|cc0)", options: [.regularExpression, .caseInsensitive]) != nil {
            license = lic.lowercased().contains("cc0") ? "CC0" : "Public domain"
        } else { license = lic }
        licenseURL = (m["licUrl"] as? String).flatMap(URL.init(string:))
        page = (m["page"] as? String).flatMap(URL.init(string:))
        pictured = m["of"] as? String
    }

    /// Thumbnails live on thumb.wikimedia.org, small originals on upload.wikimedia.org
    static func wikimediaURL(_ path: String) -> URL? {
        let host = path.hasPrefix("thumb/") ? "thumb.wikimedia.org" : "upload.wikimedia.org"
        return URL(string: "https://\(host)/wikipedia/commons/\(path)")
    }
}
