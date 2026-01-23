import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var baseURLString: String
    @Published var model: String
    @Published var apiKeyDraft: String = ""
    @Published private(set) var hasSavedAPIKey: Bool = false
    @Published var maxConcurrentRequests: Int
    @Published var dryRun: Bool
    @Published var denylistPatterns: [String]
    @Published var allowlistPatterns: [String]

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let baseURLString = "settings.baseURLString"
        static let model = "settings.model"
        static let maxConcurrentRequests = "settings.maxConcurrentRequests"
        static let dryRun = "settings.dryRun"
        static let denylistPatterns = "settings.denylistPatterns"
        static let allowlistPatterns = "settings.allowlistPatterns"
    }

    init() {
        self.baseURLString = defaults.string(forKey: Keys.baseURLString) ?? "https://api.openai.com/"
        self.model = defaults.string(forKey: Keys.model) ?? "gpt-4o-mini"
        let mc = defaults.integer(forKey: Keys.maxConcurrentRequests)
        self.maxConcurrentRequests = mc == 0 ? 3 : mc

        self.dryRun = defaults.bool(forKey: Keys.dryRun)
        self.denylistPatterns = defaults.stringArray(forKey: Keys.denylistPatterns) ?? []
        self.allowlistPatterns = defaults.stringArray(forKey: Keys.allowlistPatterns) ?? []

        self.hasSavedAPIKey = (KeychainManager.loadAPIKey() != nil)
    }

    func save() {
        defaults.set(baseURLString, forKey: Keys.baseURLString)
        defaults.set(model, forKey: Keys.model)
        defaults.set(maxConcurrentRequests, forKey: Keys.maxConcurrentRequests)
        defaults.set(dryRun, forKey: Keys.dryRun)
        defaults.set(denylistPatterns, forKey: Keys.denylistPatterns)
        defaults.set(allowlistPatterns, forKey: Keys.allowlistPatterns)

        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            try? KeychainManager.saveAPIKey(trimmed)
            apiKeyDraft = ""
        }
        hasSavedAPIKey = (KeychainManager.loadAPIKey() != nil)
    }
    
    func ruleMatcherOptions() -> RuleMatcher.Options {
        RuleMatcher.Options(
            activeProjectDays: 30,
            denylistPatterns: denylistPatterns,
            allowlistPatterns: allowlistPatterns
        )
    }

    func deleteAPIKey() {
        try? KeychainManager.deleteAPIKey()
        hasSavedAPIKey = false
    }

    func resolvedBaseURL() -> URL? {
        URL(string: baseURLString)
    }

    func snapshot() -> AIConfiguration? {
        guard let url = resolvedBaseURL() else { return nil }
        return AIConfiguration(baseURL: url, model: model, maxConcurrentRequests: maxConcurrentRequests)
    }
}

