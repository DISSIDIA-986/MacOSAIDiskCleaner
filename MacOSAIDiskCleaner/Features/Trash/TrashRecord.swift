import Foundation

struct TrashRecord: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let originalPath: String
    let trashedPath: String?
    let sizeBytes: Int64
    let decisionSource: String
    let matchedRuleId: String?
    let aiRecommendedAction: String?
    let dryRun: Bool
    let success: Bool
    let errorMessage: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        originalPath: String,
        trashedPath: String?,
        sizeBytes: Int64,
        decisionSource: String,
        matchedRuleId: String?,
        aiRecommendedAction: String?,
        dryRun: Bool,
        success: Bool,
        errorMessage: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.originalPath = originalPath
        self.trashedPath = trashedPath
        self.sizeBytes = sizeBytes
        self.decisionSource = decisionSource
        self.matchedRuleId = matchedRuleId
        self.aiRecommendedAction = aiRecommendedAction
        self.dryRun = dryRun
        self.success = success
        self.errorMessage = errorMessage
    }
}

