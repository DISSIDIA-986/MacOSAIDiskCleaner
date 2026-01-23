import Foundation

struct RuleMatch: Hashable, Sendable {
    let rule: CleanupRule
    /// 如果匹配项属于活跃项目（如 node_modules），这里会记录活动性判断结果
    let isActiveProject: Bool
    let note: String?
}

