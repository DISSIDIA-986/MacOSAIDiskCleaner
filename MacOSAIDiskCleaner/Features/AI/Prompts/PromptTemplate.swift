import Foundation

protocol PromptTemplate: Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }              // 新增: 模板描述
    var version: String { get }                  // 新增: 版本控制
    var applicableCategories: Set<String>? { get } // 新增: 适用分类
    var triggerConditions: TemplateTriggerConditions { get } // 新增: 触发条件

    // 修改: 增加developerProfile参数
    func render(
        context: AnalysisContext,
        sanitizedPath: String,
        developerProfile: DeveloperProfile?
    ) -> String
}

struct TemplateTriggerConditions: Sendable, Codable {
    var pathContains: [String]?              // 路径包含条件
    var minSizeBytes: Int64?                 // 最小大小
    var requiresDirectory: Bool?             // 目录限制
    var ruleIdMatches: Set<String>?          // 规则匹配
    var priority: Int                        // 越高越优先

    static let `default` = TemplateTriggerConditions(priority: 0)
}

struct DeveloperProfile: Sendable, Codable {
    var swift: Bool
    var python: Bool
    var nodeJS: Bool
    var ruby: Bool

    var activeStacks: [String] {
        var stacks: [String] = []
        if swift { stacks.append("Swift/Xcode") }
        if python { stacks.append("Python") }
        if nodeJS { stacks.append("Node.js/npm") }
        if ruby { stacks.append("Ruby") }
        return stacks
    }
}

