import Foundation

struct CandidateItem: Identifiable, Hashable, Sendable {
    // 现有字段 (保持不变)
    let id: URL
    let url: URL
    let isDirectory: Bool
    let sizeBytes: Int64
    var ruleMatch: RuleMatch?
    var aiAnalysis: AIAnalysis?

    // 新增字段
    let sourceCategoryId: String            // 来源分类ID
    let scanSessionId: UUID                 // 所属扫描会话
    let scannedAt: Date                     // 扫描时间戳

    // 可选时间元数据 (按需加载)
    var contentModificationDate: Date?
    var creationDate: Date?

    // 现有computed properties
    var name: String { url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent }
    
    var effectiveRiskLevel: RiskLevel? {
        aiAnalysis?.riskLevel ?? ruleMatch?.rule.riskLevel
    }
}

