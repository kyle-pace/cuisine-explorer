import MapKit

/// The map's shapes, as on the globe: every country filled in its continent's color, and
/// regional cuisines drawn as the states or provinces they come from (data/countries.geojson
/// and data/regions.geojson, loaded the first time the map opens).
struct MapShape: Identifiable {
    let id: Int
    let refs: [String]          // the cuisines this shape stands for (empty: a country with none)
    let name: String            // the country or region, for the card when there's no cuisine
    let polygons: [MKPolygon]
    let rings: [[CLLocationCoordinate2D]]
    let bounds: MKMapRect

    var ref: String? { refs.first }

    func contains(_ c: CLLocationCoordinate2D) -> Bool {
        guard bounds.contains(MKMapPoint(c)) else { return false }
        // Even-odd over every ring; holes are rare in these shapes and fine either way
        var inside = false
        for ring in rings {
            var j = ring.count - 1
            for i in ring.indices {
                let a = ring[i], b = ring[j]
                if (a.latitude > c.latitude) != (b.latitude > c.latitude),
                   c.longitude < (b.longitude - a.longitude) * (c.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude {
                    inside.toggle()
                }
                j = i
            }
        }
        return inside
    }
}

@MainActor @Observable
final class Shapes {
    private(set) var countries: [MapShape] = []
    private(set) var regions: [MapShape] = []
    private(set) var loaded = false
    private var loading = false

    /// `national`: iso3 to cuisine ref; `regionRefs`: refs per regions.geojson feature, in order
    func load(national: [String: String], regionRefs: [[String]]) async {
        guard !loaded, !loading else { return }
        loading = true
        async let c = Remote.shared.data("countries.geojson", under: DataSource.root)
        async let r = Remote.shared.data("regions.geojson", under: DataSource.root)
        if let data = await c { countries = Self.parse(data) { i, props in
            // Natural Earth's codes: ISO where it has one (-99 when it doesn't), Kosovo as XKX
            var iso = props["ISO_A3_EH"] as? String ?? ""
            if iso == "-99" || iso.isEmpty { iso = props["ADM0_A3"] as? String ?? "" }
            if iso == "KOS" { iso = "XKX" }
            return (national[iso].map { [$0] } ?? [], props["NAME"] as? String ?? "")
        } }
        if let data = await r { regions = Self.parse(data) { i, _ in (regionRefs.indices.contains(i) ? regionRefs[i] : [], "") } }
        loaded = !countries.isEmpty
        loading = false
    }

    private static func parse(_ data: Data, meta: (Int, [String: Any]) -> ([String], String)) -> [MapShape] {
        guard let objects = try? MKGeoJSONDecoder().decode(data) else { return [] }
        var out: [MapShape] = []
        for (i, object) in objects.enumerated() {
            guard let f = object as? MKGeoJSONFeature else { continue }
            let props = f.properties.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            var polygons: [MKPolygon] = []
            for g in f.geometry {
                if let p = g as? MKPolygon { polygons.append(p) }
                else if let m = g as? MKMultiPolygon { polygons += m.polygons }
            }
            guard !polygons.isEmpty else { continue }
            let rings = polygons.map { p -> [CLLocationCoordinate2D] in
                var coords = Array(repeating: CLLocationCoordinate2D(), count: p.pointCount)
                p.getCoordinates(&coords, range: NSRange(location: 0, length: p.pointCount))
                return coords
            }
            let bounds = polygons.dropFirst().reduce(polygons[0].boundingMapRect) { $0.union($1.boundingMapRect) }
            let (refs, name) = meta(i, props)
            out.append(MapShape(id: out.count, refs: refs, name: name, polygons: polygons, rings: rings, bounds: bounds))
        }
        return out
    }

    /// The smallest shape under a point: a region when regions are showing, else its country
    func hit(_ c: CLLocationCoordinate2D, regions showRegions: Bool) -> MapShape? {
        if showRegions, let r = regions.filter({ $0.contains(c) }).min(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }) {
            return r
        }
        return countries.first { $0.contains(c) }
    }

    func shape(for ref: String) -> MapShape? {
        regions.first { $0.refs.contains(ref) } ?? countries.first { $0.refs.contains(ref) }
    }
}
