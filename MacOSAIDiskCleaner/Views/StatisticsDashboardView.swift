import SwiftUI

struct StatisticsDashboardView: View {
    @StateObject private var viewModel = StatisticsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 时间范围选择器
                Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                    ForEach(StatisticsViewModel.TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: viewModel.selectedTimeRange) { _ in
                    Task { await viewModel.load() }
                }

                // 汇总卡片
                HStack(spacing: 16) {
                    SummaryCard(
                        title: "Total Space Freed",
                        value: ByteCountFormatter.string(
                            fromByteCount: viewModel.aggregatedStats?.totalBytesFreed ?? 0,
                            countStyle: .file
                        ),
                        icon: "arrow.down.circle.fill",
                        color: .green
                    )
                    SummaryCard(
                        title: "Items Cleaned",
                        value: "\(viewModel.aggregatedStats?.totalItemsTrashed ?? 0)",
                        icon: "trash.fill",
                        color: .blue
                    )
                    SummaryCard(
                        title: "Total Scans",
                        value: "\(viewModel.aggregatedStats?.totalScans ?? 0)",
                        icon: "magnifyingglass",
                        color: .orange
                    )
                }
                .padding(.horizontal)

                // 简单的趋势图表（兼容 macOS 12）
                GroupBox("Cleanup Trend") {
                    if viewModel.weeklyTrend.isEmpty {
                        Text("No data yet")
                            .foregroundStyle(.secondary)
                            .frame(height: 200)
                    } else {
                        SimpleBarChart(data: viewModel.weeklyTrend)
                            .frame(height: 200)
                    }
                }
                .padding(.horizontal)

                // 分类分布
                GroupBox("By Category") {
                    if viewModel.categoryBreakdown.isEmpty {
                        Text("No data yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(viewModel.categoryBreakdown.keys.sorted()), id: \.self) { catId in
                            if let stats = viewModel.categoryBreakdown[catId] {
                                HStack {
                                    Text(catId)
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: stats.bytesFreed, countStyle: .file))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // 规则排行
                GroupBox("Top Rules") {
                    if viewModel.topRules.isEmpty {
                        Text("No data yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.topRules, id: \.ruleId) { rule in
                            HStack {
                                Text(rule.ruleName)
                                Spacer()
                                Text("\(rule.count) items")
                                    .foregroundStyle(.secondary)
                                Text(ByteCountFormatter.string(fromByteCount: rule.bytesFreed, countStyle: .file))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Statistics")
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }
}

struct SimpleBarChart: View {
    let data: [WeeklyDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(data.reversed(), id: \.weekStart) { point in
                        HStack(spacing: 8) {
                            Text(DateFormatter.shortDateFormatter.string(from: point.weekStart))
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)

                            GeometryReader { geo in
                                let maxBytes = (data.max(by: { $0.bytesFreed < $1.bytesFreed })?.bytesFreed ?? 1)
                                let width = CGFloat(point.bytesFreed) / CGFloat(maxBytes) * geo.size.width
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue)
                                    .frame(width: width)
                            }
                            .frame(height: 20)

                            Text(ByteCountFormatter.string(fromByteCount: point.bytesFreed, countStyle: .file))
                                .font(.caption)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

#Preview {
    StatisticsDashboardView()
}

