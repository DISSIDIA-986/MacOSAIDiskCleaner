import Foundation

struct CleanupStatistics: Codable, Sendable {
    let sessionId: UUID
    let timestamp: Date
    let categoryId: String

    var totalItemsTrashed: Int
    var totalBytesFreed: Int64
    var successfulOperations: Int
    var failedOperations: Int

    // 决策来源分布
    var byRuleOnly: Int
    var byAIRecommendation: Int
    var byManualSelection: Int
}

struct AggregatedStatistics: Codable, Sendable {
    var totalScans: Int
    var totalBytesFreed: Int64
    var totalItemsTrashed: Int
    var lastUpdated: Date

    var categoryBreakdown: [String: CategoryStatistics]  // categoryId -> stats
    var ruleBreakdown: [String: RuleStatistics]          // ruleId -> stats
    var weeklyTrend: [WeeklyDataPoint]
    var monthlyTrend: [MonthlyDataPoint]
}

struct CategoryStatistics: Codable, Sendable {
    var scanCount: Int
    var bytesFreed: Int64
    var itemsTrashed: Int
    var totalScanDuration: TimeInterval
    var averageScanTime: TimeInterval { scanCount > 0 ? totalScanDuration / Double(scanCount) : 0 }
}

struct RuleStatistics: Codable, Sendable {
    let ruleId: String
    let ruleName: String
    var matchCount: Int
    var trashedCount: Int
    var bytesFreed: Int64
}

struct WeeklyDataPoint: Codable, Sendable {
    let weekStart: Date                     // ISO week起始日
    var bytesFreed: Int64
    var itemsTrashed: Int
    var scanCount: Int
}

struct MonthlyDataPoint: Codable, Sendable {
    let month: Date                         // 月份第一天
    var bytesFreed: Int64
    var itemsTrashed: Int
    var scanCount: Int
}
