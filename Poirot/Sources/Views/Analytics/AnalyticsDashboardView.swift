import Charts
import SwiftUI

struct AnalyticsDashboardView: View {
    @Environment(UsageStore.self)
    private var usageStore
    @Environment(\.provider)
    private var provider
    @Environment(\.openSettings)
    private var openSettings
    @State
    private var viewModel: AnalyticsViewModel
    @State
    private var loadBounce = 0

    // Interactive chart selections
    @State
    private var dailySelectedDate: Date?
    @State
    private var tokenSelectedDate: Date?
    @State
    private var toolCallSelectedDate: Date?
    @State
    private var modelSelectedAngle: Int?

    /// Reference time for usage reset countdowns. `nil` (the default) uses the live clock
    /// at render time; tests inject a fixed value for deterministic snapshots.
    private let usageNow: Date?

    init(viewModel: AnalyticsViewModel = AnalyticsViewModel(), usageNow: Date? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.usageNow = usageNow
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                AnalyticsShimmerView()
                    .transition(.opacity)
            } else {
                dashboardContent
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PoirotTheme.Colors.bgApp)
        .animation(.easeInOut(duration: 0.35), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedDateRange)
        .toolbar {
            analyticsToolbar
        }
        .task {
            if viewModel.stats == nil {
                await viewModel.loadStats()
            }
        }
        // Usage is never fetched on appear — only on an explicit action (Enable / Load /
        // Refresh) or the background poll. Restarts show the persisted snapshot, so navigating
        // here never triggers a request.
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var analyticsToolbar: some ToolbarContent { // swiftlint:disable:this attributes
        ToolbarItemGroup(placement: .principal) {
            Spacer()
        }
        ToolbarItemGroup(placement: .primaryAction) {
            dateRangePicker
            customRangeButton
            exportMenu
            refreshButton
        }
    }

    private var dateRangePicker: some View {
        Picker("Range", selection: Binding(
            get: {
                if viewModel.isCustomRange { return "Custom" }
                return viewModel.selectedDateRange.id
            },
            set: { newValue in
                switch newValue {
                case "7d": viewModel.selectedDateRange = .week
                case "30d": viewModel.selectedDateRange = .month
                case "90d": viewModel.selectedDateRange = .quarter
                case "All": viewModel.selectedDateRange = .all
                default: break
                }
            }
        )) {
            ForEach(AnalyticsDateRange.presets) { range in
                Text(range.label).tag(range.id)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }

    private var customRangeButton: some View {
        Button {
            viewModel.isCustomRangePresented.toggle()
        } label: {
            Image(systemName: viewModel.isCustomRange ? "calendar.circle.fill" : "calendar")
                .foregroundStyle(viewModel.isCustomRange ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
        }
        .help("Custom date range")
        .popover(isPresented: $viewModel.isCustomRangePresented, arrowEdge: .bottom) {
            customRangePopover
        }
    }

    private var customRangePopover: some View {
        VStack(spacing: PoirotTheme.Spacing.md) {
            Text("Custom Range")
                .font(PoirotTheme.Typography.bodyMedium)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)

            DatePicker("From", selection: $viewModel.customStartDate, displayedComponents: .date)
                .datePickerStyle(.field)
            DatePicker("To", selection: $viewModel.customEndDate, displayedComponents: .date)
                .datePickerStyle(.field)

            HStack {
                Button("Cancel") {
                    viewModel.isCustomRangePresented = false
                }
                .buttonStyle(.plain)
                .help("Cancel")
                .foregroundStyle(PoirotTheme.Colors.textSecondary)

                Spacer()

                Button("Apply") {
                    viewModel.applyCustomRange()
                }
                .buttonStyle(.borderedProminent)
                .help("Apply custom range")
                .tint(PoirotTheme.Colors.accent)
            }
        }
        .padding(PoirotTheme.Spacing.lg)
        .frame(width: 260)
    }

    private var exportMenu: some View {
        Menu {
            if let stats = viewModel.stats {
                Section("Share") {
                    Button {
                        shareAsImage(stats)
                    } label: {
                        Label("Share as Image", systemImage: "photo")
                    }
                    .help("Share dashboard as image")
                }
                Section("Export CSV") {
                    ForEach(AnalyticsExportType.allCases) { type in
                        Button(type.rawValue) {
                            let csv = AnalyticsCSVExporter.export(stats, type: type)
                            AnalyticsCSVExporter.presentSavePanel(csv: csv, suggestedName: type.suggestedFileName)
                        }
                        .help("Export \(type.rawValue) as CSV")
                    }
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 24)
        .disabled(viewModel.stats == nil)
        .help("Share or export")
    }

    private func shareAsImage(_ stats: StatsCache) {
        let snapshotContent = AnalyticsSnapshotView(
            stats: stats,
            viewModel: viewModel
        )
        guard let image = AnalyticsImageExporter.renderToImage(snapshotContent) else { return }
        AnalyticsImageExporter.presentSavePanel(image: image)
    }

    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.loadStats()
                if provider.supports(.usage) {
                    await usageStore.refresh(force: true)
                }
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .symbolEffect(.rotate, value: viewModel.isLoading)
        }
        .disabled(viewModel.isLoading)
        .help("Refresh analytics")
    }

    // MARK: - Dashboard Content

    /// Always renders the header and the usage section (when supported), so usage limits are
    /// reachable even when there's no stats cache. The stats area below shows charts when the
    /// cache is present, or a compact notice when it isn't.
    private var dashboardContent: some View {
        VStack(spacing: 0) {
            header(viewModel.stats)
            ScrollView {
                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxl) {
                    if provider.supports(.usage) {
                        usageSection
                    }

                    if let stats = viewModel.stats {
                        statsCharts(stats)
                    } else {
                        noStatsNotice
                    }
                }
                .padding(PoirotTheme.Spacing.xxl)
            }
        }
    }

    @ViewBuilder
    private func statsCharts(_ stats: StatsCache) -> some View {
        summaryCards(stats)

        DailyActivityChart(
            dailyActivity: viewModel.filteredDailyActivity,
            selectedDate: $dailySelectedDate
        )

        HourlyActivityChart(hourCounts: stats.sortedHourCounts)

        ContributionHeatmap(entries: viewModel.heatmapData)

        TokenUsageOverTimeChart(
            data: viewModel.tokenTimeSeriesData,
            selectedDate: $tokenSelectedDate
        )

        ToolCallsOverTimeChart(
            dailyActivity: viewModel.filteredDailyActivity,
            selectedDate: $toolCallSelectedDate
        )

        HStack(alignment: .top, spacing: PoirotTheme.Spacing.lg) {
            ModelUsageChart(
                modelUsage: stats.modelUsage,
                selectedAngle: $modelSelectedAngle
            )
            .frame(maxHeight: .infinity)

            CostBreakdownView(
                entries: viewModel.costBreakdownEntries,
                totalCost: viewModel.totalCost
            )
            .frame(maxHeight: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - No Stats Notice

    private var noStatsNotice: some View {
        VStack(spacing: PoirotTheme.Spacing.md) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .symbolEffect(.bounce, value: loadBounce)

            Text("No session analytics yet")
                .font(PoirotTheme.Typography.headingSmall)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)

            // swiftlint:disable:next line_length
            Text("No Claude Code sessions found yet. Analytics are computed locally from your sessions and appear once you've used Claude Code in a project.")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PoirotTheme.Spacing.xxxl)
        .onAppear { loadBounce += 1 }
    }

    // MARK: - Header

    private func header(_ stats: StatsCache?) -> some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.md) {
                Image(systemName: "chart.xyaxis.line")
                    .font(PoirotTheme.Typography.headingSmall)
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                            .fill(PoirotTheme.Colors.accent.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                    Text("Session Analytics")
                        .font(PoirotTheme.Typography.heading)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)

                    if let stats {
                        HStack(spacing: PoirotTheme.Spacing.xs) {
                            Text("Last computed: \(AnalyticsFormatters.formatLocalizedDate(stats.lastComputedDate))")
                                .font(PoirotTheme.Typography.tiny)
                                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                                .padding(.horizontal, PoirotTheme.Spacing.sm)
                                .padding(.vertical, PoirotTheme.Spacing.xxs)
                                .background(
                                    Capsule().fill(PoirotTheme.Colors.bgElevated)
                                )

                            if case let .custom(start, end) = viewModel.selectedDateRange {
                                Text(
                                    "\(AnalyticsFormatters.formatShortDate(start)) — \(AnalyticsFormatters.formatShortDate(end))"
                                )
                                .font(PoirotTheme.Typography.tiny)
                                .foregroundStyle(PoirotTheme.Colors.accent)
                                .padding(.horizontal, PoirotTheme.Spacing.sm)
                                .padding(.vertical, PoirotTheme.Spacing.xxs)
                                .background(
                                    Capsule().fill(PoirotTheme.Colors.accentDim)
                                )
                            }
                        }
                    }
                }

                Spacer()
            }

            Text("Claude Code usage statistics, computed locally from your sessions.")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PoirotTheme.Spacing.xxxl)
        .padding(.vertical, PoirotTheme.Spacing.xl)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.3)
        }
    }

    // MARK: - Usage Limits

    @ViewBuilder
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.md) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Text("Usage Limits")
                    .font(PoirotTheme.Typography.headingSmall)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                // swiftlint:disable:next line_length
                InfoTooltipButton(text: "Your Claude subscription's rate-limit windows. Poirot uses the token you generate with `claude setup-token` — no extra login.")
                Spacer()
            }

            usageContent
        }
    }

    @ViewBuilder
    private var usageContent: some View {
        if !usageStore.isEnabled {
            UsageOptInCard {
                Task { await usageStore.enable() }
            }
        } else {
            enabledUsageContent
        }
    }

    @ViewBuilder
    private var enabledUsageContent: some View {
        switch usageStore.state {
        case let .loaded(usage):
            loadedUsage(usage)

        case .loading:
            UsagePlaceholderCard(
                icon: "gauge.with.dots.needle.bottom.50percent",
                message: "Loading usage limits…",
                pulse: true
            )

        case let .idle(note):
            if usageStore.hasToken {
                // A token is stored: the tap loads/retries. `note` explains a prior failure.
                UsageOptInCard(
                    icon: note == nil ? "gauge.with.dots.needle.bottom.50percent" : "key.slash",
                    title: note == nil ? "Load your usage limits" : "Couldn't read your usage limits",
                    message: note ?? "Fetch your current 5-hour and 7-day rate-limit windows.",
                    actionTitle: note == nil ? "Load" : "Try again",
                    actionIcon: note == nil ? "arrow.down.circle" : "arrow.clockwise"
                ) { Task { await usageStore.refresh(force: true) } }
            } else {
                // No token yet: retrying is pointless — send the user to Settings to add one.
                UsageOptInCard(
                    icon: "key.slash",
                    title: "Add your usage token",
                    // swiftlint:disable:next line_length
                    message: note ?? "Run `claude setup-token` in your terminal, then paste the token in Settings › Usage.",
                    actionTitle: "Open Settings",
                    actionIcon: "gearshape"
                ) { openSettings() }
            }
        }
    }

    @ViewBuilder
    private func loadedUsage(_ usage: ClaudeUsage) -> some View {
        let now = usageNow ?? Date()
        VStack(spacing: PoirotTheme.Spacing.md) {
            HStack(spacing: PoirotTheme.Spacing.md) {
                UsageGaugeCard(title: "5-Hour Window", icon: "clock.arrow.circlepath", window: usage.fiveHour, now: now)
                UsageGaugeCard(title: "7-Day Window", icon: "calendar", window: usage.sevenDay, now: now)
            }
            .frame(height: usageCardHeight)

            if usage.sevenDayOpus != nil || usage.sevenDaySonnet != nil {
                HStack(spacing: PoirotTheme.Spacing.md) {
                    if let opus = usage.sevenDayOpus {
                        UsageGaugeCard(title: "Opus · Weekly", icon: "sparkle", window: opus, now: now)
                    }
                    if let sonnet = usage.sevenDaySonnet {
                        UsageGaugeCard(title: "Sonnet · Weekly", icon: "wand.and.stars", window: sonnet, now: now)
                    }
                }
                .frame(height: usageCardHeight)
            }

            if let spend = usage.spend, spend.enabled {
                UsagePlaceholderCard(
                    icon: "dollarsign.circle",
                    message: "Spend: \(String(format: "$%.2f", spend.usedDollars)) · \(Int(spend.utilization.rounded()))% of limit",
                    tint: PoirotTheme.Colors.green
                )
            }

            if let extra = usage.extraUsage, extra.enabled {
                UsagePlaceholderCard(
                    icon: "plus.circle",
                    message: "Extra usage: \(Int((extra.utilization ?? 0).rounded()))% used",
                    tint: PoirotTheme.Colors.orange
                )
            }
        }
    }

    private let usageCardHeight: CGFloat = 96

    // MARK: - Summary Cards

    private let cardColumns = Array(repeating: GridItem(.flexible(), spacing: PoirotTheme.Spacing.md), count: 4)
    private let cardRowHeight: CGFloat = 110

    private func summaryCards(_ stats: StatsCache) -> some View {
        LazyVGrid(columns: cardColumns, spacing: PoirotTheme.Spacing.md) {
            StatCard(
                title: "Total Sessions",
                value: "\(stats.totalSessions)",
                icon: "rectangle.stack.fill",
                color: PoirotTheme.Colors.accent
            )
            .frame(height: cardRowHeight)

            StatCard(
                title: "Total Messages",
                value: AnalyticsFormatters.formatLargeNumber(stats.totalMessages),
                icon: "message.fill",
                color: PoirotTheme.Colors.blue
            )
            .frame(height: cardRowHeight)

            StatCard(
                title: "Longest Session",
                value: stats.longestSessionFormatted,
                subtitle: "\(stats.longestSession.messageCount) messages",
                icon: "timer",
                color: PoirotTheme.Colors.orange
            )
            .frame(height: cardRowHeight)

            StatCard(
                title: "First Session",
                value: AnalyticsFormatters.formatFirstSessionDate(stats.firstSessionParsedDate),
                icon: "calendar",
                color: PoirotTheme.Colors.green
            )
            .frame(height: cardRowHeight)

            // Row 2
            StatCard(
                title: "Total Cost",
                value: viewModel.hasCostData ? AnalyticsFormatters.formatCost(viewModel.totalCost) : "—",
                subtitle: viewModel.hasCostData ? nil : "included in subscription",
                icon: "dollarsign.circle.fill",
                color: PoirotTheme.Colors.green,
                dimmed: !viewModel.hasCostData,
                info: viewModel
                    .hasCostData ? nil :
                    // swiftlint:disable:next line_length
                    "API users see per-model costs here. Subscription plans (Max, Pro) include usage at no extra charge."
            )
            .frame(height: cardRowHeight)

            StatCard(
                title: "Total Tokens",
                value: AnalyticsFormatters.formatLargeNumber(viewModel.totalTokens),
                icon: "number.circle.fill",
                color: PoirotTheme.Colors.purple
            )
            .frame(height: cardRowHeight)

            StatCard(
                title: "Tool Calls",
                value: AnalyticsFormatters.formatLargeNumber(viewModel.totalToolCalls),
                icon: "wrench.and.screwdriver.fill",
                color: PoirotTheme.Colors.teal
            )
            .frame(height: cardRowHeight)

            StatCard(
                title: "Time Saved",
                value: viewModel.timeSavedFormatted,
                subtitle: viewModel.hasTimeSavedData ? "speculation cache" : "no cache data",
                icon: "clock.arrow.2.circlepath",
                color: PoirotTheme.Colors.blue,
                dimmed: !viewModel.hasTimeSavedData
            )
            .frame(height: cardRowHeight)
        }
    }
}
