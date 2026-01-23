import Foundation

actor AIAnalysisCache {
    struct Entry: Sendable {
        let analysis: AIAnalysis
        let expiresAt: Date
    }

    private var store: [String: Entry] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 24 * 3600) {
        self.ttl = ttl
    }

    func get(key: String) -> AIAnalysis? {
        guard let entry = store[key] else { return nil }
        if entry.expiresAt <= Date() {
            store.removeValue(forKey: key)
            return nil
        }
        return entry.analysis
    }

    func put(key: String, analysis: AIAnalysis) {
        store[key] = Entry(analysis: analysis, expiresAt: Date().addingTimeInterval(ttl))
    }
}

