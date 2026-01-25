import Foundation

struct PromptManager: Sendable {
    private let templateManager: TemplateManager

    init(templateManager: TemplateManager = TemplateManager()) {
        self.templateManager = templateManager
    }

    func makePrompt(
        context: AnalysisContext,
        category: ScanCategory?,
        developerProfile: DeveloperProfile?
    ) async -> (templateId: String, prompt: String) {
        let sanitizedPath = PathSanitizer.sanitize(context.path)
        let template = await templateManager.selectTemplate(
            for: context,
            category: category,
            developerProfile: developerProfile
        )
        return (template.id, template.render(
            context: context,
            sanitizedPath: sanitizedPath,
            developerProfile: developerProfile
        ))
    }
}

