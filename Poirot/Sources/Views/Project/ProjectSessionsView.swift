import SwiftUI

struct ProjectSessionsView: View {
    let project: Project
    @Environment(AppState.self)
    private var appState
    @State
    private var isRevealed = false
    @State
    private var filterQuery = ""

    private var filteredSessions: [Session] {
        let q = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return project.sessions }
        return project.sessions
            .compactMap { session -> (Session, Int)? in
                let best = max(
                    HighlightedText.fuzzyMatch(session.title, query: q)?.score ?? 0,
                    HighlightedText.fuzzyMatch(session.preview ?? "", query: q)?.score ?? 0,
                    HighlightedText.fuzzyMatch(session.id, query: q)?.score ?? 0
                )
                return best > 0 ? (session, best) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private static let screenID = "projectSessions"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if filteredSessions.isEmpty, !filterQuery.isEmpty {
                ConfigEmptyState(
                    icon: "magnifyingglass",
                    message: "No sessions match \"\(filterQuery)\"",
                    hint: "Try a different search term"
                )
            } else {
                sessionsContent
            }
        }
        .background(PoirotTheme.Colors.bgApp)
        .toolbar { projectToolbar }
        .task(id: project.id) {
            filterQuery = ""
            isRevealed = false
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeOut(duration: 0.4)) {
                isRevealed = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.md) {
                Image(systemName: "folder.fill")
                    .font(PoirotTheme.Typography.headingSmall)
                    .foregroundStyle(PoirotTheme.Colors.green)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                            .fill(PoirotTheme.Colors.green.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                    Text(project.name)
                        .font(PoirotTheme.Typography.heading)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)

                    Text("\(project.sessions.count) \(project.sessions.count == 1 ? "session" : "sessions")")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .padding(.horizontal, PoirotTheme.Spacing.sm)
                        .padding(.vertical, PoirotTheme.Spacing.xxs)
                        .background(
                            Capsule().fill(PoirotTheme.Colors.bgElevated)
                        )
                }

                Spacer()
            }

            Text("Claude Code sessions for this project")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                .lineSpacing(PoirotTheme.Spacing.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PoirotTheme.Spacing.xxxl)
        .padding(.vertical, PoirotTheme.Spacing.xl)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.3)
        }
    }

    @ToolbarContentBuilder
    private var projectToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Spacer()
        }
        ToolbarItemGroup(placement: .primaryAction) {
            ConfigFilterField(searchQuery: $filterQuery, placeholder: "Find in Sessions\u{2026}")
                .frame(width: 200)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    appState.sessionLayout = appState.sessionLayout == .grid ? .list : .grid
                }
            } label: {
                Image(systemName: appState.sessionLayout == .grid ? "list.bullet" : "square.grid.2x2")
                    .frame(width: 16, height: 16)
                    .contentTransition(.symbolEffect(.replace))
            }
            .help("Toggle layout")
        }
    }

    // MARK: - Sessions Content

    @ViewBuilder
    private var sessionsContent: some View {
        if appState.sessionLayout == .grid {
            sessionsGrid
        } else {
            sessionsList
        }
    }

    // MARK: - Grid (Masonry)

    private var sessionsGrid: some View {
        ScrollView {
            HStack(alignment: .top, spacing: PoirotTheme.Spacing.lg) {
                ForEach(0 ..< 2, id: \.self) { column in
                    LazyVStack(spacing: PoirotTheme.Spacing.lg) {
                        ForEach(sessionsForColumn(column), id: \.element.id) { index, session in
                            SessionCard(session: session, filterQuery: filterQuery)
                                .shimmerReveal(
                                    isRevealed: isRevealed,
                                    delay: Double(min(index, 7)) * 0.04,
                                    cornerRadius: PoirotTheme.Radius.md
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.xxl)
            .padding(.top, PoirotTheme.Spacing.lg)
            .padding(.bottom, PoirotTheme.Spacing.xxl)
        }
    }

    private func sessionsForColumn(_ column: Int) -> [(offset: Int, element: Session)] {
        Array(filteredSessions.enumerated()).filter { $0.offset % 2 == column }
    }

    // MARK: - List

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PoirotTheme.Spacing.md) {
                ForEach(Array(filteredSessions.enumerated()), id: \.element.id) { index, session in
                    SessionListRow(session: session, filterQuery: filterQuery)
                        .shimmerReveal(
                            isRevealed: isRevealed,
                            delay: Double(min(index, 9)) * 0.03,
                            cornerRadius: PoirotTheme.Radius.md
                        )
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.xxl)
            .padding(.top, PoirotTheme.Spacing.lg)
            .padding(.bottom, PoirotTheme.Spacing.xxl)
        }
    }
}

// MARK: - Session Card (Grid)

private struct SessionCard: View {
    let session: Session
    var filterQuery: String = ""
    @Environment(AppState.self)
    private var appState
    @State
    private var isHovered = false

    private var isSelected: Bool {
        appState.selectedSession == session
    }

    var body: some View {
        Button {
            guard appState.selectedSession?.id != session.id else { return }
            appState.selectedSession = session
        } label: {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
                Text(HighlightedText.fuzzyAttributedString(session.title, query: filterQuery))
                    .font(PoirotTheme.Typography.bodyMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let preview = session.preview {
                    Text(HighlightedText.fuzzyAttributedString(preview, query: filterQuery))
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }

                SessionBadgeRow(session: session)
                    .padding(.top, PoirotTheme.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cardChrome(isHovered: isHovered, isSelected: isSelected)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? PoirotTheme.Colors.accent : PoirotTheme.Colors.accent.opacity(0.3))
                    .frame(width: 3)
                    .padding(.vertical, PoirotTheme.Spacing.sm)
            }
        }
        .buttonStyle(.plain)
        .help("Open session")
        .onHover { isHovered = $0 }
    }
}

// MARK: - Session List Row

private struct SessionListRow: View {
    let session: Session
    var filterQuery: String = ""
    @Environment(AppState.self)
    private var appState
    @State
    private var isHovered = false

    private var isSelected: Bool {
        appState.selectedSession == session
    }

    var body: some View {
        Button {
            guard appState.selectedSession?.id != session.id else { return }
            appState.selectedSession = session
        } label: {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
                Text(HighlightedText.fuzzyAttributedString(session.title, query: filterQuery))
                    .font(PoirotTheme.Typography.bodyMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .lineLimit(1)

                if let preview = session.preview {
                    Text(HighlightedText.fuzzyAttributedString(preview, query: filterQuery))
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                        .lineLimit(2)
                }

                SessionBadgeRow(session: session)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PoirotTheme.Spacing.lg)
            .cardChrome(isHovered: isHovered, isSelected: isSelected)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? PoirotTheme.Colors.accent : PoirotTheme.Colors.accent.opacity(0.3))
                    .frame(width: 3)
                    .padding(.vertical, PoirotTheme.Spacing.sm)
            }
        }
        .buttonStyle(.plain)
        .help("Open session")
        .onHover { isHovered = $0 }
    }
}

// MARK: - Shared Badge Row

private struct SessionBadgeRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            if session.isSidechain {
                Label(
                    session.agentId ?? "Agent",
                    systemImage: "cpu"
                )
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(PoirotTheme.Colors.purple)
                .padding(.horizontal, PoirotTheme.Spacing.sm)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(PoirotTheme.Colors.purple.opacity(0.15))
                )
            }

            if let model = session.model {
                badge(formatModel(model), fg: PoirotTheme.Colors.accent, bg: PoirotTheme.Colors.accentDim)
            }

            if session.totalTokens > 0 {
                badge(
                    "\(formatTokens(session.totalTokens)) tk",
                    fg: PoirotTheme.Colors.blue,
                    bg: PoirotTheme.Colors.blue.opacity(0.15)
                )
            }

            badge(
                "\(session.turnCount) \(session.turnCount == 1 ? "turn" : "turns")",
                fg: PoirotTheme.Colors.textTertiary,
                bg: PoirotTheme.Colors.bgElevated
            )

            Spacer(minLength: 0)

            Text(session.timeAgo)
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .lineLimit(1)
        }
    }

    private func badge(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(PoirotTheme.Typography.tiny)
            .foregroundStyle(fg)
            .padding(.horizontal, PoirotTheme.Spacing.sm)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(bg)
            )
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))k"
                : String(format: "%.1fk", k)
        }
        return "\(count)"
    }

    private func formatModel(_ model: String) -> String {
        let name = model.replacingOccurrences(of: "claude-", with: "")

        if name.hasPrefix("opus-") {
            let version = name.dropFirst("opus-".count).prefix(while: { $0 != "-" && $0 != "_" })
            return "Opus \(version.replacingOccurrences(of: "-", with: "."))"
        } else if name.hasPrefix("sonnet-") {
            let version = name.dropFirst("sonnet-".count).prefix(while: { $0 != "-" && $0 != "_" })
            return "Sonnet \(version.replacingOccurrences(of: "-", with: "."))"
        } else if name.hasPrefix("haiku-") {
            let version = name.dropFirst("haiku-".count).prefix(while: { $0 != "-" && $0 != "_" })
            return "Haiku \(version.replacingOccurrences(of: "-", with: "."))"
        }

        return model
    }
}
