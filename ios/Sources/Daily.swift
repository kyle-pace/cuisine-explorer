import Foundation

/// One dish a day, the same for everyone that day. Shared with the widget, so both agree.
enum Daily {
    /// `refs`: the candidates in a stable order (the skeleton's); returns one by the date
    static func dish(from refs: [String], on date: Date = .now) -> String? {
        guard !refs.isEmpty else { return nil }
        let cal = Calendar.current
        let day = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = cal.component(.year, from: date)
        return refs[(day * 31 + year * 7) % refs.count]
    }
}
