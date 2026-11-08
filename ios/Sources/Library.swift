import Foundation
import Observation

/// What the person has saved and recently opened. Kept on the phone in UserDefaults
/// (a few hundred short strings at most), included in the normal iPhone backup.
@MainActor @Observable
final class Library {
    private(set) var saved: [String]
    private(set) var recent: [String]
    private(set) var searches: [String]
    private let defaults = UserDefaults.standard

    init() {
        saved = defaults.stringArray(forKey: "saved") ?? []
        recent = defaults.stringArray(forKey: "recent") ?? []
        searches = defaults.stringArray(forKey: "searches") ?? []
    }

    func isSaved(_ ref: String) -> Bool { saved.contains(ref) }

    func toggleSaved(_ ref: String) {
        if let i = saved.firstIndex(of: ref) { saved.remove(at: i) } else { saved.insert(ref, at: 0) }
        defaults.set(saved, forKey: "saved")
    }

    /// Called when a page opens; the newest comes first and the list stays short
    func visited(_ ref: String) {
        recent.removeAll { $0 == ref }
        recent.insert(ref, at: 0)
        if recent.count > 40 { recent.removeLast(recent.count - 40) }
        defaults.set(recent, forKey: "recent")
    }

    /// A search that led somewhere, newest first, for the Search tab before you type
    func searched(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count > 1 else { return }
        searches.removeAll { $0.caseInsensitiveCompare(q) == .orderedSame }
        searches.insert(q, at: 0)
        if searches.count > 8 { searches.removeLast(searches.count - 8) }
        defaults.set(searches, forKey: "searches")
    }

    func forgetSearch(_ query: String) {
        searches.removeAll { $0 == query }
        defaults.set(searches, forKey: "searches")
    }

    func clearSearches() {
        searches = []
        defaults.removeObject(forKey: "searches")
    }

    func clearRecent() {
        recent = []
        defaults.removeObject(forKey: "recent")
    }
}
