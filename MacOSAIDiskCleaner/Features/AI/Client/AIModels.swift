import Foundation

struct AIAnalysis: Codable, Hashable, Sendable {
    let summary: String
    let recommendedAction: RecommendedAction
    let riskLevel: RiskLevel
    let reasons: [String]
    let warnings: [String]
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case summary
        case recommendedAction = "recommended_action"
        case riskLevel = "risk_level"
        case reasons
        case warnings
        case confidence
    }
}

enum RecommendedAction: String, CaseIterable, Codable, Sendable {
    case keep
    case review
    case delete
}

