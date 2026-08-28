import Foundation
import SwiftUI

// MARK: - Date Range

enum AnalyticsDateRange: Hashable, Identifiable {
    case week
    case month
    case quarter
    case all
    case custom(start: Date, end: Date)

    var id: String {
        switch self {
        case .week: "7d"
        case .month: "30d"
        case .quarter: "90d"
        case .all: "All"
        case .custom: "Custom"
        }
    }

    var label: String { id }

    static let presets: [AnalyticsDateRange] = [.week, .month, .quarter, .all]
}

// MARK: - Supporting Types

struct TokenTimeSeriesEntry: Identifiable {
    let id = UUID()
    let date: Date
    let model: String
    let tokens: Int
}

nonisolated struct HeatmapEntry: Sendable {
    let date: Date
    let dateString: String
    let messages: Int
    let sessions: Int
}

struct CostBreakdownEntry: Identifiable {
    let id = UUID()
    let model: String
    let cost: Double
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
}

// MARK: - ViewModel

@MainActor
@Observable
final class AnalyticsViewModel {
    var stats: StatsCache?
    var isLoading = true
    var selectedDateRange: AnalyticsDateRange = .all

    // Custom range state
    var isCustomRangePresented = false
    var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    var customEndDate = Date.now

    /// Creates a ViewModel with pre-loaded stats (for previews and snapshot tests).
    init(preloaded stats: StatsCache? = nil) {
        if let stats {
            self.stats = stats
            self.isLoading = false
        }
    }

    // MARK: - Loading

    func loadStats() async {
        isLoading = true
        let loaded = await Task.detached {
            // Use Claude Code's cache only when it covers the latest transcripts;
            // otherwise scan JSONL locally. The cache is known to freeze while
            // sessions continue (token charts stop months before the session list).
            StatsCacheLoader.loadAnalytics(projectsPath: SessionLoader().claudeProjectsPath)
        }.value
        withAnimation(.easeInOut(duration: 0.4)) {
            stats = loaded
            isLoading = false
        }
    }

    // MARK: - Date Filtering

    private var referenceDate: Date {
        if let stats {
            return AnalyticsFormatters.parseDate(stats.lastComputedDate)
        }
        return .now
    }

    private var dateRange: (start: Date, end: Date)? {
        let ref = referenceDate
        switch selectedDateRange {
        case .week:
            guard let start = Calendar.current.date(byAdding: .day, value: -7, to: ref) else { return nil }
            return (start, ref)
        case .month:
            guard let start = Calendar.current.date(byAdding: .day, value: -30, to: ref) else { return nil }
            return (start, ref)
        case .quarter:
            guard let start = Calendar.current.date(byAdding: .day, value: -90, to: ref) else { return nil }
            return (start, ref)
        case .all:
            return nil
        case let .custom(start, end):
            return (start, end)
        }
    }

    func applyCustomRange() {
        selectedDateRange = .custom(start: customStartDate, end: customEndDate)
        isCustomRangePresented = false
    }

    var isCustomRange: Bool {
        if case .custom = selectedDateRange { return true }
        return false
    }

    // MARK: - Filtered Data

    var filteredDailyActivity: [StatsCache.DailyActivity] {
        guard let stats else { return [] }
        guard let range = dateRange else { return stats.dailyActivity }
        return stats.dailyActivity.filter {
            let date = AnalyticsFormatters.parseDate($0.date)
            return date >= range.start && date <= range.end
        }
    }

    var filteredDailyModelTokens: [StatsCache.DailyModelTokens] {
        guard let stats else { return [] }
        guard let range = dateRange else { return stats.dailyModelTokens }
        return stats.dailyModelTokens.filter {
            let date = AnalyticsFormatters.parseDate($0.date)
            return date >= range.start && date <= range.end
        }
    }

    // MARK: - Token Time Series

    var tokenTimeSeriesData: [TokenTimeSeriesEntry] {
        filteredDailyModelTokens.flatMap { day in
            day.tokensByModel.map { model, tokens in
                TokenTimeSeriesEntry(
                    date: AnalyticsFormatters.parseDate(day.date),
                    model: StatsCache.friendlyModelName(model),
                    tokens: tokens
                )
            }
        }
    }

    // MARK: - Heatmap Data

    var heatmapData: [HeatmapEntry] {
        filteredDailyActivity.map { day in
            HeatmapEntry(
                date: AnalyticsFormatters.parseDate(day.date),
                dateString: day.date,
                messages: day.messageCount,
                sessions: day.sessionCount
            )
        }
    }

    // MARK: - Cost Breakdown

    var costBreakdownEntries: [CostBreakdownEntry] {
        guard let stats else { return [] }
        return stats.modelUsage.map { key, value in
            CostBreakdownEntry(
                model: StatsCache.friendlyModelName(key),
                cost: value.costUSD,
                inputTokens: value.inputTokens,
                outputTokens: value.outputTokens,
                cacheTokens: value.cacheReadInputTokens + value.cacheCreationInputTokens
            )
        }
        .sorted { $0.cost > $1.cost }
    }

    // MARK: - Summary Computations

    var totalCost: Double {
        stats?.totalCostUSD ?? 0
    }

    var hasCostData: Bool {
        totalCost > 0
    }

    var totalTokens: Int {
        guard let stats else { return 0 }
        return stats.totalInputTokens + stats.totalOutputTokens
    }

    var totalToolCalls: Int {
        stats?.totalToolCalls ?? 0
    }

    var filteredTotalMessages: Int {
        filteredDailyActivity.reduce(0) { $0 + $1.messageCount }
    }

    var filteredTotalSessions: Int {
        filteredDailyActivity.reduce(0) { $0 + $1.sessionCount }
    }

    var filteredTotalToolCalls: Int {
        filteredDailyActivity.reduce(0) { $0 + $1.toolCallCount }
    }

    var timeSavedFormatted: String {
        guard let stats else { return "—" }
        let ms = stats.totalSpeculationTimeSavedMs
        if ms == 0 { return "—" }
        return AnalyticsFormatters.formatDuration(milliseconds: ms)
    }

    var hasTimeSavedData: Bool {
        (stats?.totalSpeculationTimeSavedMs ?? 0) > 0
    }
}
