import Foundation

struct ScanSession: Identifiable, Codable, Sendable {
    let id: UUID
    let startedAt: Date
    var completedAt: Date?
    let categoryId: String                  // 关联ScanCategory.id
    var totalItemsVisited: Int              // 遍历的条目数
    var matchedItemsCount: Int              // 规则匹配数
    var totalBytesMatched: Int64            // 匹配项总大小
    var aiAnalyzedCount: Int                // AI分析数
    var status: ScanStatus

    enum ScanStatus: String, Codable, Sendable {
        case inProgress
        case completed
        case cancelled
        case failed
    }

    var duration: TimeInterval? {
        guard let end = completedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }
}
