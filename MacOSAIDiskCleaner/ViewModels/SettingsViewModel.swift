import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - LLM Settings
    @Published var selectedProvider: LLMProvider = .custom
    @Published var baseURLString: String
    @Published var model: String
    @Published var apiKeyDraft: String = ""
    @Published private(set) var hasSavedAPIKey: Bool = false
    @Published var maxConcurrentRequests: Int

    // MARK: - Connection Test
    @Published private(set) var isTestingConnection: Bool = false
    @Published private(set) var connectionStatus: String?

    // MARK: - Developer Profile
    @Published var devSwift: Bool
    @Published var devPython: Bool
    @Published var devNodeJS: Bool
    @Published var devRuby: Bool

    // MARK: - Safety & Rules
    @Published var dryRun: Bool
    @Published var denylistPatterns: [String]
    @Published var allowlistPatterns: [String]

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedProvider = "settings.selectedProvider"
        static let baseURLString = "settings.baseURLString"
        static let model = "settings.model"
        static let maxConcurrentRequests = "settings.maxConcurrentRequests"
        static let dryRun = "settings.dryRun"
        static let denylistPatterns = "settings.denylistPatterns"
        static let allowlistPatterns = "settings.allowlistPatterns"
        static let devSwift = "settings.devSwift"
        static let devPython = "settings.devPython"
        static let devNodeJS = "settings.devNodeJS"
        static let devRuby = "settings.devRuby"
    }

    // MARK: - LLM Provider Presets
    enum LLMProvider: String, CaseIterable, Identifiable {
        case openai = "OpenAI"
        case grok = "Grok"
        case qwen = "Qwen"
        case custom = "Custom"

        var id: String { rawValue }

        var defaultURL: String {
            switch self {
            case .openai: return "https://api.openai.com/"
            case .grok: return "https://api.x.ai/"
            case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode/"
            case .custom: return ""
            }
        }

        var defaultModel: String {
            switch self {
            case .openai: return "gpt-4o-mini"
            case .grok: return "grok-2-latest"
            case .qwen: return "qwen-turbo"
            case .custom: return ""
            }
        }
    }

    init() {
        // LLM Settings
        if let providerRaw = defaults.string(forKey: Keys.selectedProvider),
           let provider = LLMProvider(rawValue: providerRaw) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .openai
        }
        self.baseURLString = defaults.string(forKey: Keys.baseURLString) ?? "https://api.openai.com/"
        self.model = defaults.string(forKey: Keys.model) ?? "gpt-4o-mini"
        let mc = defaults.integer(forKey: Keys.maxConcurrentRequests)
        self.maxConcurrentRequests = mc == 0 ? 3 : mc

        // Developer Profile
        self.devSwift = defaults.bool(forKey: Keys.devSwift)
        self.devPython = defaults.bool(forKey: Keys.devPython)
        self.devNodeJS = defaults.bool(forKey: Keys.devNodeJS)
        self.devRuby = defaults.bool(forKey: Keys.devRuby)

        // Safety & Rules
        self.dryRun = defaults.bool(forKey: Keys.dryRun)
        self.denylistPatterns = defaults.stringArray(forKey: Keys.denylistPatterns) ?? []
        self.allowlistPatterns = defaults.stringArray(forKey: Keys.allowlistPatterns) ?? []

        self.hasSavedAPIKey = (KeychainManager.loadAPIKey() != nil)
    }

    func save() {
        defaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider)
        defaults.set(baseURLString, forKey: Keys.baseURLString)
        defaults.set(model, forKey: Keys.model)
        defaults.set(maxConcurrentRequests, forKey: Keys.maxConcurrentRequests)

        // Developer Profile
        defaults.set(devSwift, forKey: Keys.devSwift)
        defaults.set(devPython, forKey: Keys.devPython)
        defaults.set(devNodeJS, forKey: Keys.devNodeJS)
        defaults.set(devRuby, forKey: Keys.devRuby)

        // Safety & Rules
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

    func applyProvider(_ provider: LLMProvider) {
        selectedProvider = provider
        if provider != .custom {
            baseURLString = provider.defaultURL
            model = provider.defaultModel
        }
    }

    func testConnection() {
        guard let url = resolvedBaseURL(),
              let apiKey = KeychainManager.loadAPIKey(), !apiKey.isEmpty else {
            connectionStatus = "❌ API Key not set"
            return
        }

        isTestingConnection = true
        connectionStatus = nil

        Task {
            do {
                let testURL = url.appendingPathComponent("v1/models")
                var request = URLRequest(url: testURL)
                request.httpMethod = "GET"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 10

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        connectionStatus = "✅ Connection successful"
                    } else if httpResponse.statusCode == 401 {
                        connectionStatus = "❌ Invalid API Key"
                    } else {
                        connectionStatus = "⚠️ HTTP \(httpResponse.statusCode)"
                    }
                }
            } catch {
                connectionStatus = "❌ \(error.localizedDescription)"
            }
            isTestingConnection = false
        }
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

