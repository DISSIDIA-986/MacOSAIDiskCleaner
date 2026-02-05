import Foundation
import os

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

    func analyze(
        context: AnalysisContext,
        config: AIConfiguration,
        category: ScanCategory? = nil,
        developerProfile: DeveloperProfile? = nil
    ) async throws -> AIAnalysis {
        guard let apiKey = KeychainManager.loadAPIKey(), !apiKey.isEmpty else {
            throw DiskCleanerError.permissionDenied("API Key not set")
        }

        let (templateId, prompt) = await promptManager.makePrompt(
            context: context,
            category: category,
            developerProfile: developerProfile
        )
        let sanitizedPath = PathSanitizer.sanitize(context.path)

        // 🔧 FIX: 包含路径哈希防止缓存键碰撞
        let pathHash = context.path.hashValue
        let globPattern = makeGlobPattern(for: context.path, matchedRule: context.matchedRuleId)
        let cacheKey = "\(templateId)|\(globPattern)|\(pathHash)"

        if let cached = await cache.get(key: cacheKey) {
            return cached
        }

        let client = LLMClient(config: .init(baseURL: config.baseURL, model: config.model))

        let result: AIAnalysis = try await queue.run {
            do {
                return try await client.analyzeJSON(apiKey: apiKey, prompt: prompt)
            } catch {
                // Retry once with explicit JSON format instruction (per implementation plan)
                Logger.ai.info("First attempt failed, retrying with stricter JSON instruction")
                let retryPrompt = prompt + "\n\nIMPORTANT: You must return ONLY valid JSON matching the exact schema. Do not wrap in markdown code blocks, do not add commentary before or after the JSON. Return the JSON object directly."
                do {
                    return try await client.analyzeJSON(apiKey: apiKey, prompt: retryPrompt)
                } catch {
                    // Still failed after retry - log and rethrow
                    Logger.ai.error("JSON parsing failed after retry: \(error.localizedDescription)")
                    throw DiskCleanerError.aiRequestFailed(error)
                }
            }
        }

        await cache.put(key: cacheKey, analysis: result)
        return result
    }
    
    /// Convert a file path to a glob pattern for caching purposes.
    /// If a rule matched, use its pattern; otherwise generate a generic pattern.
    private func makeGlobPattern(for path: String, matchedRule: String?) -> String {
        // If we have a matched rule, try to find its pattern
        if let ruleId = matchedRule,
           let rule = BuiltInRules.all.first(where: { $0.id == ruleId }) {
            return rule.pattern
        }
        
        // Fallback: generate a generic pattern based on path structure
        let components = (path as NSString).pathComponents
        guard !components.isEmpty else { return "**/*" }
        
        // For common patterns, use known globs
        if let cacheIdx = components.firstIndex(of: "Caches") {
            let afterCache = components.suffix(from: cacheIdx + 1)
            if !afterCache.isEmpty {
                return "**/Caches/**/\(afterCache.last ?? "*")"
            }
        }
        
        // Generic: use last component with ** prefix
        let last = components.last ?? "*"
        return "**/\(last)"
    }
}

