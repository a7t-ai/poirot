import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self)
    private var appState
    @Environment(UsageStore.self)
    private var usageStore
    @Environment(\.provider)
    private var provider
    @Environment(\.openWindow)
    private var openWindow
    @State
    private var menuBarState = MenuBarState()

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            if showUsageSection {
                Divider().opacity(0.3)
                usageSection
            }
            Divider().opacity(0.3)
            searchField
            Divider().opacity(0.3)
            sessionsList
            Divider().opacity(0.3)
            footerSection
        }
        .frame(width: 320)
        .background(PoirotTheme.Colors.bgCard)
        .onAppear {
            menuBarState.loadRecentSessions(from: appState.projects)
            menuBarState.loadStats()
        }
        // The menu bar never fetches usage itself (no Keychain read on open) — it passively
        // mirrors whatever the dashboard has already loaded this session.
    }

    // MARK: - Usage

    private var showUsageSection: Bool {
        guard provider.supports(.usage), usageStore.isEnabled else { return false }
        if case .loaded = usageStore.state { return true }
        return false
    }

    @ViewBuilder
    private var usageSection: some View {
        if case let .loaded(usage) = usageStore.state {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                usageHeader
                MenuBarUsageRow(label: "5h", window: usage.fiveHour)
                MenuBarUsageRow(label: "7d", window: usage.sevenDay)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PoirotTheme.Spacing.lg)
            .padding(.vertical, PoirotTheme.Spacing.sm)
        }
    }

    private var usageHeader: some View {
        HStack(spacing: PoirotTheme.Spacing.xs) {
            Text("Usage")
                .font(PoirotTheme.Typography.microSemibold)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)

            Spacer()

            usageCadenceMenu

            Button {
                Task { await usageStore.refresh(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(usageStore.state == .loading)
            .help("Refresh usage now")
        }
    }

    private var usageCadenceMenu: some View {
        Menu {
            Picker("Auto-refresh", selection: Binding(
                get: { usageStore.refreshInterval },
                set: { usageStore.setRefreshInterval($0) }
            )) {
                ForEach(UsageRefreshInterval.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: usageStore.refreshInterval == .manual ? "hand.tap" : "timer")
                Text(usageStore.refreshInterval.shortLabel)
            }
            .font(PoirotTheme.Typography.tiny)
            .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Auto-refresh interval")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                if let nsImage = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                Text(provider.assistantName)
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)

                Spacer()
            }

            if let stats = menuBarState.stats {
                HStack(spacing: PoirotTheme.Spacing.md) {
                    statItem(
                        value: AnalyticsFormatters.formatLargeNumber(stats.totalSessions),
                        label: "sessions"
                    )
                    statItem(
                        value: AnalyticsFormatters.formatLargeNumber(stats.totalMessages),
                        label: "messages"
                    )
                    statItem(
                        value: AnalyticsFormatters.formatLargeNumber(stats.totalInputTokens + stats.totalOutputTokens),
                        label: "tokens"
                    )
                    if stats.totalCostUSD > 0 {
                        statItem(
                            value: AnalyticsFormatters.formatCost(stats.totalCostUSD),
                            label: "cost"
                        )
                    }
                }
            }
        }
        .padding(.horizontal, PoirotTheme.Spacing.lg)
        .padding(.vertical, PoirotTheme.Spacing.md)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)
            Text(label)
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .help("Total \(label)")
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(PoirotTheme.Typography.small)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)

            TextField(
                "Search recent sessions...",
                text: Binding(
                    get: { menuBarState.searchQuery },
                    set: { menuBarState.searchQuery = $0 }
                )
            )
            .textFieldStyle(.plain)
            .font(PoirotTheme.Typography.caption)
            .foregroundStyle(PoirotTheme.Colors.textPrimary)

            if !menuBarState.searchQuery.isEmpty {
                Button {
                    menuBarState.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(PoirotTheme.Typography.small)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, PoirotTheme.Spacing.lg)
        .padding(.vertical, PoirotTheme.Spacing.sm)
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                let sessions = menuBarState.filteredSessions
                if sessions.isEmpty {
                    emptyState
                } else {
                    ForEach(sessions, id: \.session.id) { pair in
                        MenuBarSessionRow(
                            session: pair.session,
                            projectName: pair.project.name
                        ) {
                            openSessionInApp(pair.session, projectId: pair.project.id)
                        }
                    }
                }
            }
            .padding(PoirotTheme.Spacing.sm)
        }
        .frame(maxHeight: 300)
    }

    private var emptyState: some View {
        VStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: "text.bubble")
                .font(.system(size: 20))
                .foregroundStyle(PoirotTheme.Colors.textTertiary)

            Text(menuBarState.searchQuery.isEmpty ? "No recent sessions" : "No matching sessions")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(PoirotTheme.Spacing.xl)
    }

    // MARK: - Footer

    private var footerSection: some View {
        Button {
            NSApp.activate()
            openWindow(id: "main")
        } label: {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Text("Open Poirot")
                    .font(PoirotTheme.Typography.captionMedium)

                Spacer()

                Image(systemName: "arrow.up.forward")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
            .padding(.horizontal, PoirotTheme.Spacing.lg)
            .padding(.vertical, PoirotTheme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open the main window")
        .foregroundStyle(PoirotTheme.Colors.textPrimary)
    }

    // MARK: - Actions

    private func openSessionInApp(_ session: Session, projectId: String) {
        NSApp.activate()
        appState.selectedProject = projectId
        appState.selectedSession = session
        appState.selectedNav = .sessions
    }
}

// MARK: - Usage Row

private struct MenuBarUsageRow: View {
    let label: String
    let window: UsageWindow
    var now = Date()

    var body: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Text(label)
                .font(PoirotTheme.Typography.microSemibold)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                .frame(width: 18, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PoirotTheme.Colors.bgElevated)
                    Capsule()
                        .fill(window.severity.tint)
                        .frame(width: max(3, geo.size.width * window.fraction))
                }
            }
            .frame(height: 5)

            Text("\(window.percent)%")
                .font(PoirotTheme.Typography.microMedium)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)
                .frame(width: 32, alignment: .trailing)

            Text(resetText)
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .frame(width: 58, alignment: .trailing)
        }
    }

    private var resetText: String {
        guard let interval = window.timeUntilReset(now: now), interval >= 60 else {
            return "resets now"
        }
        return UsageCountdown.format(interval)
    }
}

// MARK: - Session Row

private struct MenuBarSessionRow: View {
    let session: Session
    let projectName: String
    let action: () -> Void

    @State
    private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Image(systemName: "text.bubble")
                    .font(PoirotTheme.Typography.small)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                    Text(session.title)
                        .font(PoirotTheme.Typography.captionMedium)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(projectName)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Text(session.timeAgo)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
            .padding(.horizontal, PoirotTheme.Spacing.sm)
            .padding(.vertical, PoirotTheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                    .fill(isHovered ? PoirotTheme.Colors.bgElevated : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(session.title)
        .onHover { isHovered = $0 }
    }
}
