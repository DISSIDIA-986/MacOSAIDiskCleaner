import Foundation

struct LargeDirectoryTemplate: PromptTemplate {
    let id = "large_directory"
    let name = "Large Directory"

    func render(context: AnalysisContext, sanitizedPath: String) -> String {
        """
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
    }
}

struct CacheTemplate: PromptTemplate {
    let id = "cache"
    let name = "Cache Directory"

    func render(context: AnalysisContext, sanitizedPath: String) -> String {
        """
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
    }
}

struct AppSupportTemplate: PromptTemplate {
    let id = "app_support"
    let name = "Application Support"

    func render(context: AnalysisContext, sanitizedPath: String) -> String {
        """
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
    }
}

