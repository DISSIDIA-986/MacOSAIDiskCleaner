import Foundation

struct CleanupRule: Identifiable, Hashable, Codable, Sendable {
    enum PatternKind: String, Codable, Sendable {
        case glob
        case regex
    }

    let id: String
    let name: String
    let kind: PatternKind
    let pattern: String
    let riskLevel: RiskLevel
    /// 数值越大越优先。建议：用户自定义(1000+) > 内置安全规则(500+) > 通用规则(100+)
    let priority: Int
    let isUserDefined: Bool

    init(
        id: String,
        name: String,
        kind: PatternKind,
        pattern: String,
        riskLevel: RiskLevel,
        priority: Int,
        isUserDefined: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.pattern = pattern
        self.riskLevel = riskLevel
        self.priority = priority
        self.isUserDefined = isUserDefined
    }
}

