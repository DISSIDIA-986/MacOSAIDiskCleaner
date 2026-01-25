import Foundation

actor TemplateManager {
    private var builtInTemplates: [PromptTemplate]
    private var userTemplates: [UserDefinedTemplate]
    private let userTemplatesURL: URL

    init() {
        self.builtInTemplates = [
            CacheTemplate(),
            AppSupportTemplate(),
            LargeDirectoryTemplate()
        ]

        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacOSAIDiskCleaner", isDirectory: true)
        self.userTemplatesURL = base.appendingPathComponent("user_templates.json")

        // 加载用户模板
        if let data = try? Data(contentsOf: userTemplatesURL),
           let templates = try? JSONDecoder().decode([UserDefinedTemplate].self, from: data) {
            self.userTemplates = templates
        } else {
            self.userTemplates = []
        }
    }

    func selectTemplate(
        for context: AnalysisContext,
        category: ScanCategory?,
        developerProfile: DeveloperProfile?
    ) -> PromptTemplate {
        // 1. 优先使用分类指定的模板
        if let categoryTemplateId = category?.preferredTemplateId,
           let template = template(forId: categoryTemplateId) {
            return template
        }

        // 2. 按触发条件和优先级匹配
        let allTemplates: [PromptTemplate] = builtInTemplates + userTemplates
        let candidates = allTemplates
            .filter { matches(template: $0, context: context) }
            .sorted { $0.triggerConditions.priority > $1.triggerConditions.priority }

        if let best = candidates.first {
            return best
        }

        // 3. 兜底
        return LargeDirectoryTemplate()
    }

    private func matches(template: PromptTemplate, context: AnalysisContext) -> Bool {
        let cond = template.triggerConditions

        if let paths = cond.pathContains {
            let found = paths.contains { context.path.contains($0) }
            if !found { return false }
        }

        if let minSize = cond.minSizeBytes, context.sizeBytes < minSize {
            return false
        }

        if let reqDir = cond.requiresDirectory, reqDir != context.isDirectory {
            return false
        }

        if let ruleIds = cond.ruleIdMatches,
           let matchedId = context.matchedRuleId,
           !ruleIds.contains(matchedId) {
            return false
        }

        return true
    }

    func template(forId id: String) -> PromptTemplate? {
        builtInTemplates.first { $0.id == id } ?? userTemplates.first { $0.id == id }
    }

    func allTemplates() -> [PromptTemplate] {
        builtInTemplates + userTemplates
    }
}

struct UserDefinedTemplate: PromptTemplate, Codable {
    let id: String
    let name: String
    let description: String
    let version: String
    let applicableCategories: Set<String>?
    let triggerConditions: TemplateTriggerConditions
    let promptBody: String  // 带占位符的模板文本

    func render(
        context: AnalysisContext,
        sanitizedPath: String,
        developerProfile: DeveloperProfile?
    ) -> String {
        var result = promptBody
        result = result.replacingOccurrences(of: "{{path}}", with: sanitizedPath)
        result = result.replacingOccurrences(of: "{{size}}", with: String(context.sizeBytes))
        result = result.replacingOccurrences(of: "{{is_directory}}", with: String(context.isDirectory))
        if let profile = developerProfile {
            result = result.replacingOccurrences(of: "{{dev_stacks}}", with: profile.activeStacks.joined(separator: ", "))
        }
        return result
    }
}
