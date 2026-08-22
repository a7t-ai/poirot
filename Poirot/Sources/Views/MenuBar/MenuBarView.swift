import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self)
    private var appState
    @Environment(\.provider)
    private var provider
    @Environment(\.openWindow)
    private var openWindow
    @State
    private var menuBarState = MenuBarState()

    var body: some View {
        VStack(spacing: 0) {
            headerSection
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
