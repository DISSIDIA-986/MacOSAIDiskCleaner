import Foundation

struct LargeDirectoryTemplate: PromptTemplate {
    let id = "large_directory"
    let name = "Large Directory"
    let description = "General analysis for large directories and files"
    let version = "1.0"
    let applicableCategories: Set<String>? = nil  // 适用所有分类
    let triggerConditions = TemplateTriggerConditions(
        minSizeBytes: 1_000_000_000,  // 1GB
        priority: 10
    )

    func render(
        context: AnalysisContext,
        sanitizedPath: String,
        developerProfile: DeveloperProfile?
    ) -> String {
        var prompt = """
You are a macOS storage expert. Analyze whether this item is safe to delete.

Return ONLY JSON with the following schema:
{
  "summary": "short summary",
  "recommended_action": "keep|review|delete",
  "risk_level": "low|medium|high",
  "reasons": ["..."],
  "warnings": ["..."],
  "confidence": 0.0
}

Item:
- path: \(sanitizedPath)
- is_directory: \(context.isDirectory)
- size_bytes: \(context.sizeBytes)
- matched_rule: \(context.matchedRuleName ?? "null")
- rule_risk: \(context.riskLevel?.rawValue ?? "null")
- active_project: \(context.isActiveProject.map(String.init(describing:)) ?? "null")
"""
        
        // 新增: 开发者配置上下文
        if let profile = developerProfile, !profile.activeStacks.isEmpty {
            prompt += "\n- user_dev_stacks: \(profile.activeStacks.joined(separator: ", "))"
        }
        
        return prompt
    }
}

struct CacheTemplate: PromptTemplate {
    let id = "cache"
    let name = "Cache Directory"
    let description = "Analysis for cache directories"
    let version = "1.0"
    let applicableCategories: Set<String>? = ["system.caches"]
    let triggerConditions = TemplateTriggerConditions(
        pathContains: ["/Caches/"],
        priority: 20
    )

    func render(
        context: AnalysisContext,
        sanitizedPath: String,
        developerProfile: DeveloperProfile?
    ) -> String {
        var prompt = """
You are a macOS cache expert. Evaluate whether deleting this cache is safe and what side effects to expect.

Return ONLY JSON with schema:
{
  "summary": "short summary",
  "recommended_action": "keep|review|delete",
  "risk_level": "low|medium|high",
  "reasons": ["..."],
  "warnings": ["..."],
  "confidence": 0.0
}

Item:
- path: \(sanitizedPath)
- size_bytes: \(context.sizeBytes)
"""
        
        if let profile = developerProfile, !profile.activeStacks.isEmpty {
            prompt += "\n- user_dev_stacks: \(profile.activeStacks.joined(separator: ", "))"
        }
        
        return prompt
    }
}

struct AppSupportTemplate: PromptTemplate {
    let id = "app_support"
    let name = "Application Support"
    let description = "Analysis for Application Support directories"
    let version = "1.0"
    let applicableCategories: Set<String>? = nil
    let triggerConditions = TemplateTriggerConditions(
        pathContains: ["/Application Support/"],
        priority: 20
    )

    func render(
        context: AnalysisContext,
        sanitizedPath: String,
        developerProfile: DeveloperProfile?
    ) -> String {
        var prompt = """
You are a macOS application data expert. Determine if this looks like essential app data.

Return ONLY JSON with schema:
{
  "summary": "short summary",
  "recommended_action": "keep|review|delete",
  "risk_level": "low|medium|high",
  "reasons": ["..."],
  "warnings": ["..."],
  "confidence": 0.0
}

Item:
- path: \(sanitizedPath)
- size_bytes: \(context.sizeBytes)
"""
        
        if let profile = developerProfile, !profile.activeStacks.isEmpty {
            prompt += "\n- user_dev_stacks: \(profile.activeStacks.joined(separator: ", "))"
        }
        
        return prompt
    }
}

