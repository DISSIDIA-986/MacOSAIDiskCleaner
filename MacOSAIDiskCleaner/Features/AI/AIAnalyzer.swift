import Foundation

struct AIConfiguration: Sendable, Hashable {
    var baseURL: URL
    var model: String
    var maxConcurrentRequests: Int
}

actor AIAnalyzer {
    private var queue: AIRequestQueue
    private let cache: AIAnalysisCache
    private let promptManager: PromptManager

    init(
        maxConcurrentRequests: Int = 3,
        cache: AIAnalysisCache = AIAnalysisCache(),
        promptManager: PromptManager = PromptManager()
    ) {
        self.queue = AIRequestQueue(maxConcurrent: maxConcurrentRequests)
        self.cache = cache
        self.promptManager = promptManager
    }

    func updateConfiguration(_ config: AIConfiguration) {
        self.queue = AIRequestQueue(maxConcurrent: config.maxConcurrentRequests)
    }

    func analyze(context: AnalysisContext, config: AIConfiguration) async throws -> AIAnalysis {
        guard let apiKey = KeychainManager.loadAPIKey(), !apiKey.isEmpty else {
            throw DiskCleanerError.permissionDenied("API Key not set")
        }

        let (templateId, prompt) = promptManager.makePrompt(context: context)
        let sanitizedPath = PathSanitizer.sanitize(context.path)
        let cacheKey = "\(templateId)|\(sanitizedPath)"

        if let cached = await cache.get(key: cacheKey) {
            return cached
        }

        let client = LLMClient(config: .init(baseURL: config.baseURL, model: config.model))

        let result: AIAnalysis = try await queue.run {
            do {
                return try await client.analyzeJSON(apiKey: apiKey, prompt: prompt)
            } catch {
                // Retry once with a stricter instruction
                let retryPrompt = prompt + "\n\nIMPORTANT: Return ONLY valid JSON matching the schema. No markdown, no commentary."
                return try await client.analyzeJSON(apiKey: apiKey, prompt: retryPrompt)
            }
        }

        await cache.put(key: cacheKey, analysis: result)
        return result
    }
}

