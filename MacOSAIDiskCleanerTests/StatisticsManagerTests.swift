import XCTest
@testable import MacOSAIDiskCleaner

final class StatisticsManagerTests: XCTestCase {
    func testRecordCleanupUpdatesAggregates() async {
        let sm = StatisticsManager()
        let sessionId = UUID()
        let stats = CleanupStatistics(
            sessionId: sessionId,
            timestamp: Date(),
            categoryId: "system.caches",
            totalItemsTrashed: 2,
            totalBytesFreed: 1024,
            successfulOperations: 2,
            failedOperations: 0,
            byRuleOnly: 2,
            byAIRecommendation: 0,
            byManualSelection: 0
        )
        await sm.recordCleanup(stats, ruleBreakdown: [("r1","Rule 1",2,1024)])
        let agg = await sm.getAggregatedStats()
        XCTAssertEqual(agg.totalItemsTrashed, 2)
        XCTAssertEqual(agg.totalBytesFreed, 1024)
        XCTAssertFalse(agg.weeklyTrend.isEmpty)
    }

    func testRecordSessionIncrementsScans() async {
        let sm = StatisticsManager()
        let sessionId = UUID()
        let session = ScanSession(
            id: sessionId,
            startedAt: Date(),
            categoryId: "system.caches",
            totalItemsVisited: 0,
            matchedItemsCount: 0,
            totalBytesMatched: 0,
            aiAnalyzedCount: 0,
            status: .inProgress
        )
        await sm.recordSessionStart(session)
        await sm.recordSessionComplete(sessionId, itemsMatched: 10, bytesMatched: 2048)

        let agg = await sm.getAggregatedStats()
        XCTAssertEqual(agg.totalScans, 1)
    }

    func testMigrationSkipsWhenStatsExist() async {
        let sm = StatisticsManager()

        // Record a cleanup to make stats non-empty
        let stats = CleanupStatistics(
            sessionId: UUID(),
            timestamp: Date(),
            categoryId: "system.caches",
            totalItemsTrashed: 1,
            totalBytesFreed: 512,
            successfulOperations: 1,
            failedOperations: 0,
            byRuleOnly: 1,
            byAIRecommendation: 0,
            byManualSelection: 0
        )
        await sm.recordCleanup(stats, ruleBreakdown: [])

        // Migration should be a no-op since stats already exist
        await sm.migrateFromAuditLogIfNeeded()

        let agg = await sm.getAggregatedStats()
        // Verify stats remain unchanged (only the one cleanup we recorded)
        XCTAssertEqual(agg.totalItemsTrashed, 1)
        XCTAssertEqual(agg.totalBytesFreed, 512)
    }
}
