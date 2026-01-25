import Foundation

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var isLoading = true
    @Published private(set) var aggregatedStats: AggregatedStatistics?
    @Published private(set) var weeklyTrend: [WeeklyDataPoint] = []
    @Published private(set) var monthlyTrend: [MonthlyDataPoint] = []
    @Published private(set) var categoryBreakdown: [String: CategoryStatistics] = [:]
    @Published private(set) var topRules: [(ruleId: String, ruleName: String, count: Int, bytesFreed: Int64)] = []

    @Published var selectedTimeRange: TimeRange = .last30Days

    enum TimeRange: String, CaseIterable, Identifiable {
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case last90Days = "Last 90 Days"
        case allTime = "All Time"

        var id: String { rawValue }

        var weeks: Int {
            switch self {
            case .last7Days: return 1
            case .last30Days: return 4
            case .last90Days: return 13
            case .allTime: return 52
            }
        }
    }

    private let statsManager: StatisticsManager

    init(statsManager: StatisticsManager = StatisticsManager()) {
        self.statsManager = statsManager
    }

    func load() async {
        isLoading = true

        async let agg = statsManager.getAggregatedStats()
        async let weekly = statsManager.getWeeklyTrend(weeks: selectedTimeRange.weeks)
        async let monthly = statsManager.getMonthlyTrend(months: 12)
        async let categories = statsManager.getCategoryBreakdown()
        async let rules = statsManager.getTopRules(limit: 10)

        (aggregatedStats, weeklyTrend, monthlyTrend, categoryBreakdown, topRules) =
            await (agg, weekly, monthly, categories, rules)

        isLoading = false
    }

    func refresh() async {
        await load()
    }
}
