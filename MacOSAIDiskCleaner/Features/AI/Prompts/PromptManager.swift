import Foundation

struct PromptManager: Sendable {
    private let templates: [PromptTemplate]

    init(templates: [PromptTemplate] = [CacheTemplate(), AppSupportTemplate(), LargeDirectoryTemplate()]) {
        self.templates = templates
    }

    func makePrompt(context: AnalysisContext) -> (templateId: String, prompt: String) {
        let sanitizedPath = PathSanitizer.sanitize(context.path)
        let template = selectTemplate(for: context)
        return (template.id, template.render(context: context, sanitizedPath: sanitizedPath))
    }

    func selectTemplate(for context: AnalysisContext) -> PromptTemplate {
        let p = context.path

        if p.contains("/Library/Caches/") {
            return templates.first(where: { $0.id == "cache" }) ?? CacheTemplate()
        }
        if p.contains("/Library/Application Support/") {
            return templates.first(where: { $0.id == "app_support" }) ?? AppSupportTemplate()
        }

        // 大目录兜底（>1GB 或目录）
        if context.isDirectory || context.sizeBytes >= 1_000_000_000 {
            return templates.first(where: { $0.id == "large_directory" }) ?? LargeDirectoryTemplate()
        }

        return templates.first(where: { $0.id == "large_directory" }) ?? LargeDirectoryTemplate()
    }
}

