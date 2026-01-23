import Foundation

struct CandidateItem: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let isDirectory: Bool
    let sizeBytes: Int64

    var ruleMatch: RuleMatch?
    var aiAnalysis: AIAnalysis?

    var name: String { url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent }

    var effectiveRiskLevel: RiskLevel? {
        aiAnalysis?.riskLevel ?? ruleMatch?.rule.riskLevel
    }
}

