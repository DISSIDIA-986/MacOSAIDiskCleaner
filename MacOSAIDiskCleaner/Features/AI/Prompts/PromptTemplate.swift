import Foundation

protocol PromptTemplate: Sendable {
    var id: String { get }
    var name: String { get }
    func render(context: AnalysisContext, sanitizedPath: String) -> String
}

