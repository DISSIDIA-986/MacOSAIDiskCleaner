import Foundation

struct AnalysisContext: Hashable, Sendable {
    let path: String
    let isDirectory: Bool
    let sizeBytes: Int64

    /// 规则引擎的匹配结果（可选）
    let matchedRuleId: String?
    let matchedRuleName: String?
    let riskLevel: RiskLevel?
    let isActiveProject: Bool?

    init(
        path: String,
        isDirectory: Bool,
        sizeBytes: Int64,
        matchedRuleId: String? = nil,
        matchedRuleName: String? = nil,
        riskLevel: RiskLevel? = nil,
        isActiveProject: Bool? = nil
    ) {
        self.path = path
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.matchedRuleId = matchedRuleId
        self.matchedRuleName = matchedRuleName
        self.riskLevel = riskLevel
        self.isActiveProject = isActiveProject
    }
}

