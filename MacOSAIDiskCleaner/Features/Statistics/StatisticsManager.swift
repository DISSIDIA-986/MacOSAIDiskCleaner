import Foundation

actor StatisticsManager {
    private let statsURL: URL
    private let auditLogURL: URL
    private var aggregatedStats: AggregatedStatistics
    private var sessions: [UUID: ScanSession]
    private var cleanupRecords: [CleanupStatistics]
    private var migrationTriggered: Bool = false

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacOSAIDiskCleaner", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        self.statsURL = base.appendingPathComponent("statistics.json")
        self.auditLogURL = base.appendingPathComponent("audit.log")

        // 加载已有统计
        if let data = try? Data(contentsOf: statsURL),
           let stats = try? JSONDecoder().decode(AggregatedStatistics.self, from: data) {
            self.aggregatedStats = stats
        } else {
            self.aggregatedStats = AggregatedStatistics(
                totalScans: 0,
                totalBytesFreed: 0,
                totalItemsTrashed: 0,
                lastUpdated: Date(),
                categoryBreakdown: [:],
                ruleBreakdown: [:],
                weeklyTrend: [],
                monthlyTrend: []
            )
        }
        self.sessions = [:]
        self.cleanupRecords = []
    }

    /// Check and trigger migration from audit.log if needed.
    /// Call this once after initialization to migrate historical data.
    func migrateFromAuditLogIfNeeded() async {
        // Only migrate once per session and only if stats are empty
        guard !migrationTriggered else { return }
        migrationTriggered = true

        // Check if migration is needed: stats are empty but audit.log exists
        guard aggregatedStats.totalScans == 0 && aggregatedStats.totalItemsTrashed == 0 else {
            return
        }

        guard FileManager.default.fileExists(atPath: auditLogURL.path) else {
            return
        }

        // Perform migration
        let auditLog = AuditLog()
        await migrateFromAuditLog(auditLog: auditLog)
    }

    // MARK: - Session Management

    func recordSessionStart(_ session: ScanSession) {
        sessions[session.id] = session
    }

    func recordSessionComplete(_ sessionId: UUID, itemsMatched: Int, bytesMatched: Int64) {
        guard var session = sessions[sessionId] else { return }
        session.completedAt = Date()
        session.status = .completed
        session.matchedItemsCount = itemsMatched
        session.totalBytesMatched = bytesMatched
        sessions[sessionId] = session

        // 更新聚合统计
        aggregatedStats.totalScans += 1

        // 更新分类统计
        var catStats = aggregatedStats.categoryBreakdown[session.categoryId] ?? CategoryStatistics(
            scanCount: 0, bytesFreed: 0, itemsTrashed: 0, totalScanDuration: 0
        )
        catStats.scanCount += 1
        if let duration = session.duration {
            catStats.totalScanDuration += duration
        }
        aggregatedStats.categoryBreakdown[session.categoryId] = catStats

        aggregatedStats.lastUpdated = Date()
        Task { try? await persist() }
    }

    // MARK: - Cleanup Recording

    func recordCleanup(_ stats: CleanupStatistics, ruleBreakdown: [(ruleId: String, ruleName: String, count: Int, bytes: Int64)]) {
        cleanupRecords.append(stats)

        // 更新聚合
        aggregatedStats.totalBytesFreed += stats.totalBytesFreed
        aggregatedStats.totalItemsTrashed += stats.totalItemsTrashed

        // 更新分类统计
        var catStats = aggregatedStats.categoryBreakdown[stats.categoryId] ?? CategoryStatistics(
            scanCount: 0, bytesFreed: 0, itemsTrashed: 0, totalScanDuration: 0
        )
        catStats.bytesFreed += stats.totalBytesFreed
        catStats.itemsTrashed += stats.totalItemsTrashed
        aggregatedStats.categoryBreakdown[stats.categoryId] = catStats

        // 更新规则统计
        for (ruleId, ruleName, count, bytes) in ruleBreakdown {
            var ruleStats = aggregatedStats.ruleBreakdown[ruleId] ?? RuleStatistics(
                ruleId: ruleId, ruleName: ruleName, matchCount: 0, trashedCount: 0, bytesFreed: 0
            )
            ruleStats.trashedCount += count
            ruleStats.bytesFreed += bytes
            aggregatedStats.ruleBreakdown[ruleId] = ruleStats
        }

        // 更新时间序列
        updateTimeSeries(stats)

        aggregatedStats.lastUpdated = Date()
        Task { try? await persist() }
    }

    private func updateTimeSeries(_ stats: CleanupStatistics) {
        // 周数据
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: stats.timestamp)?.start ?? stats.timestamp

        if let idx = aggregatedStats.weeklyTrend.firstIndex(where: { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }) {
            aggregatedStats.weeklyTrend[idx].bytesFreed += stats.totalBytesFreed
            aggregatedStats.weeklyTrend[idx].itemsTrashed += stats.totalItemsTrashed
        } else {
            aggregatedStats.weeklyTrend.append(WeeklyDataPoint(
                weekStart: weekStart,
                bytesFreed: stats.totalBytesFreed,
                itemsTrashed: stats.totalItemsTrashed,
                scanCount: 1
            ))
            // 保留最近52周
            if aggregatedStats.weeklyTrend.count > 52 {
                aggregatedStats.weeklyTrend.removeFirst()
            }
        }

        // 月数据
        let monthStart = calendar.dateInterval(of: .month, for: stats.timestamp)?.start ?? stats.timestamp
        if let idx = aggregatedStats.monthlyTrend.firstIndex(where: { calendar.isDate($0.month, inSameDayAs: monthStart) }) {
            aggregatedStats.monthlyTrend[idx].bytesFreed += stats.totalBytesFreed
            aggregatedStats.monthlyTrend[idx].itemsTrashed += stats.totalItemsTrashed
        } else {
            aggregatedStats.monthlyTrend.append(MonthlyDataPoint(
                month: monthStart,
                bytesFreed: stats.totalBytesFreed,
                itemsTrashed: stats.totalItemsTrashed,
                scanCount: 1
            ))
            // 保留最近24个月
            if aggregatedStats.monthlyTrend.count > 24 {
                aggregatedStats.monthlyTrend.removeFirst()
            }
        }
    }

    // MARK: - Query Methods

    func getAggregatedStats() -> AggregatedStatistics {
        aggregatedStats
    }

    func getWeeklyTrend(weeks: Int) -> [WeeklyDataPoint] {
        Array(aggregatedStats.weeklyTrend.suffix(weeks))
    }

    func getMonthlyTrend(months: Int) -> [MonthlyDataPoint] {
        Array(aggregatedStats.monthlyTrend.suffix(months))
    }

    func getCategoryBreakdown() -> [String: CategoryStatistics] {
        aggregatedStats.categoryBreakdown
    }

    func getTopRules(limit: Int) -> [(ruleId: String, ruleName: String, count: Int, bytesFreed: Int64)] {
        aggregatedStats.ruleBreakdown.values
            .sorted { $0.bytesFreed > $1.bytesFreed }
            .prefix(limit)
            .map { ($0.ruleId, $0.ruleName, $0.trashedCount, $0.bytesFreed) }
    }

    // MARK: - Persistence

    private func persist() async throws {
        let data = try JSONEncoder().encode(aggregatedStats)
        try data.write(to: statsURL)
    }

    // MARK: - Migration

    func migrateFromAuditLog(auditLog: AuditLog) async {
        let records = await auditLog.readRecent(limit: 10000)

        for record in records where record.success && !record.dryRun {
            aggregatedStats.totalBytesFreed += record.sizeBytes
            aggregatedStats.totalItemsTrashed += 1

            if let ruleId = record.matchedRuleId {
                var ruleStats = aggregatedStats.ruleBreakdown[ruleId] ?? RuleStatistics(
                    ruleId: ruleId, ruleName: ruleId, matchCount: 0, trashedCount: 0, bytesFreed: 0
                )
                ruleStats.trashedCount += 1
                ruleStats.bytesFreed += record.sizeBytes
                aggregatedStats.ruleBreakdown[ruleId] = ruleStats
            }
        }

        aggregatedStats.lastUpdated = Date()
        try? await persist()
    }
}
