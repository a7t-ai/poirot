import SwiftUI

struct SessionsNavigationView: View {
    @Environment(AppState.self)
    private var appState

    @State
    private var listSearchQuery = ""

    @State
    private var collapsedProjects: Set<String> = []

    @State
    private var showTimeline = false

    @SceneStorage("sessionsListWidth")
    private var listWidth: Double = 280

    private var filteredProjects: [Project] {
        let projects = appState.filteredSortedProjects
        let trimmed = listSearchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return projects }

        return projects.compactMap { project in
            if HighlightedText.fuzzyMatch(project.name, query: trimmed) != nil {
                return project
            }
            let matching = project.sessions.filter {
                HighlightedText.fuzzyMatch($0.title, query: trimmed) != nil
                    || HighlightedText.fuzzyMatch($0.id, query: trimmed) != nil
            }
            guard !matching.isEmpty else { return nil }
            return Project(
                id: project.id,
                name: project.name,
                path: project.path,
                sessions: matching
            )
        }
    }

    private func sessionGroup(for session: Session) -> SessionGroup? {
        let parentId = session.parentSessionId ?? session.id
        for project in appState.projects {
            let groups = SessionGroup.group(sessions: project.sessions)
            if let group = groups.first(where: { $0.id == parentId }), !group.agents.isEmpty {
                return group
            }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 0) {
            sessionsListPane
                .frame(width: max(220, min(listWidth, 380)))

            PoirotSplitDivider(position: $listWidth, minPosition: 220, maxPosition: 380)

            detailPane
                .frame(maxWidth: .infinity)
        }
        .onChange(of: appState.selectedSession) {
            showTimeline = false
        }
    }

    // MARK: - Sessions List Pane

    private var sessionsListPane: some View {
        VStack(spacing: 0) {
            sessionsListHeader
            sessionsListSearchBar
            Divider().opacity(0.3)

            if appState.isLoadingProjects {
                loadingState
            } else if filteredProjects.isEmpty {
                emptySearchState
            } else {
                ScrollViewReader { _ in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredProjects) { project in
                                SessionsProjectSection(
                                    project: project,
                                    searchQuery: listSearchQuery,
                                    isCollapsed: collapsedProjects.contains(project.id),
                                    showAgentSessions: appState.showAgentSessions,
                                    onToggleCollapse: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if collapsedProjects.contains(project.id) {
                                                collapsedProjects.remove(project.id)
                                            } else {
                                                collapsedProjects.insert(project.id)
                                            }
                                        }
                                    }
                                )
                                .id(project.id)
                            }
                        }
                        .padding(.vertical, PoirotTheme.Spacing.xs)
                    }
                }
            }
        }
        .background(PoirotTheme.Colors.bgSidebar)
    }

    private var sessionsListHeader: some View {
        HStack {
            Label("All Sessions", systemImage: "rectangle.stack.fill")
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)

            Spacer()

            let total = filteredProjects.reduce(0) { $0 + $1.sessions.count }
            Text("\(total)")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(PoirotTheme.Colors.bgCard)
                )

            agentSessionsToggle
            refreshButton
            sortMenu
        }
        .padding(.horizontal, PoirotTheme.Spacing.md)
        .padding(.vertical, PoirotTheme.Spacing.sm)
    }

    // MARK: - Agent Sessions Toggle

    private var agentSessionsToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.showAgentSessions.toggle()
            }
        } label: {
            Image(systemName: appState.showAgentSessions ? "person.2.wave.2" : "person.2")
                .font(PoirotTheme.Typography.microMedium)
                .foregroundStyle(
                    appState.showAgentSessions
                        ? PoirotTheme.Colors.accent
                        : PoirotTheme.Colors.textTertiary
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(appState.showAgentSessions ? "Hide agent sessions" : "Show agent sessions")
    }

    // MARK: - Refresh Button

    @ViewBuilder
    private var refreshButton: some View {
        if appState.isLoadingMoreProjects {
            ProgressView()
                .controlSize(.mini)
                .tint(PoirotTheme.Colors.textTertiary)
        } else {
            Button {
                appState.refreshID = UUID()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(PoirotTheme.Typography.microMedium)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Refresh sessions")
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(ProjectSortOption.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState.projectSortOption = option
                    }
                } label: {
                    if appState.projectSortOption == option {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(PoirotTheme.Typography.microMedium)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort projects")
    }

    private var sessionsListSearchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(PoirotTheme.Typography.small)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)

            TextField("Search sessions\u{2026}", text: $listSearchQuery)
                .textFieldStyle(.plain)
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)

            if !listSearchQuery.isEmpty {
                Button {
                    listSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(PoirotTheme.Typography.small)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, PoirotTheme.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                .fill(PoirotTheme.Colors.bgCard)
        )
        .padding(.horizontal, PoirotTheme.Spacing.md)
        .padding(.bottom, PoirotTheme.Spacing.sm)
    }

    private var loadingState: some View {
        VStack(spacing: PoirotTheme.Spacing.sm) {
            ProgressView()
                .controlSize(.small)
                .tint(PoirotTheme.Colors.textTertiary)
            Text("Loading sessions\u{2026}")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptySearchState: some View {
        VStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .symbolRenderingMode(.hierarchical)

            Text("No sessions found")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let session = appState.selectedSession {
            if showTimeline, let group = sessionGroup(for: session) {
                SessionTimelineView(group: group)
                    .transition(.opacity)
                    .overlay(alignment: .topTrailing) {
                        timelineToggleButton
                            .padding(PoirotTheme.Spacing.md)
                    }
            } else if appState.isShowingFileHistory {
                FileHistoryView(session: session)
                    .transition(.opacity)
            } else if appState.isLoadingSession || (session.messages.isEmpty && session.fileURL != nil) {
                SessionSkeletonView()
                    .transition(.opacity)
            } else {
                SessionDetailView(session: session)
                    .transition(.opacity)
                    .overlay(alignment: .topTrailing) {
                        if sessionGroup(for: session) != nil {
                            timelineToggleButton
                                .padding(PoirotTheme.Spacing.md)
                        }
                    }
            }
        } else if let project = appState.currentProject {
            ProjectSessionsView(project: project)
                .transition(.opacity)
        } else {
            noSessionSelectedState
        }
    }

    @ViewBuilder
    private var timelineToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showTimeline.toggle()
            }
        } label: {
            Image(systemName: showTimeline ? "text.bubble" : "chart.bar.xaxis")
                .font(PoirotTheme.Typography.small)
                .foregroundStyle(showTimeline ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(PoirotTheme.Colors.border)
                        )
                )
        }
        .buttonStyle(.plain)
        .help(showTimeline ? "Show transcript" : "Show timeline")
    }

    private var noSessionSelectedState: some View {
        VStack(spacing: PoirotTheme.Spacing.lg) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .symbolRenderingMode(.hierarchical)

            Text("Select a Session")
                .font(PoirotTheme.Typography.heading)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)

            Text("Choose a session from the list to view its content")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PoirotTheme.Colors.bgApp)
    }
}

// MARK: - Project Section

private struct SessionsProjectSection: View {
    let project: Project
    var searchQuery: String = ""
    let isCollapsed: Bool
    let showAgentSessions: Bool
    let onToggleCollapse: () -> Void

    @Environment(AppState.self)
    private var appState

    @State
    private var expandedGroups: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            projectHeader

            if !isCollapsed {
                if showAgentSessions {
                    let groups = SessionGroup.group(sessions: project.sessions)
                    ForEach(groups) { group in
                        if group.agents.isEmpty {
                            SessionsListRow(session: group.parent, searchQuery: searchQuery)
                        } else {
                            SessionGroupRow(
                                group: group,
                                searchQuery: searchQuery,
                                isExpanded: expandedGroups.contains(group.id),
                                onToggleExpand: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedGroups.contains(group.id) {
                                            expandedGroups.remove(group.id)
                                        } else {
                                            expandedGroups.insert(group.id)
                                        }
                                    }
                                }
                            )
                        }
                    }
                } else {
                    ForEach(project.sessions) { session in
                        SessionsListRow(session: session, searchQuery: searchQuery)
                    }
                }
            }
        }
    }

    private var projectHeader: some View {
        HStack(spacing: PoirotTheme.Spacing.xs) {
            Button {
                onToggleCollapse()
            } label: {
                Image(systemName: "chevron.right")
                    .font(PoirotTheme.Typography.picoSemibold)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .frame(width: 12, height: 18)
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand project" : "Collapse project")

            Button {
                appState.selectedSession = nil
                appState.selectedProject = project.id
            } label: {
                HStack(spacing: PoirotTheme.Spacing.xs) {
                    Image(systemName: "shippingbox")
                        .font(PoirotTheme.Typography.small)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .symbolRenderingMode(.hierarchical)

                    Text(project.name)
                        .font(PoirotTheme.Typography.subheading)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(project.sessions.count)")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(PoirotTheme.Colors.bgCard)
                        )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(project.name)
        }
        .padding(.horizontal, PoirotTheme.Spacing.md)
        .padding(.vertical, PoirotTheme.Spacing.sm)
    }
}

// MARK: - Split Divider

private struct PoirotSplitDivider: View {
    @Binding
    var position: Double
    let minPosition: Double
    let maxPosition: Double

    @State
    private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(PoirotTheme.Colors.border.opacity(isDragging ? 0.8 : 0.3))
            .frame(width: 1)
            .contentShape(Rectangle().inset(by: -3))
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let new = position + value.translation.width
                        position = max(minPosition, min(new, maxPosition))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

// MARK: - Session Group Row

private struct SessionGroupRow: View {
    let group: SessionGroup
    var searchQuery: String = ""
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @Environment(AppState.self)
    private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Parent row with agent badge
            SessionsListRow(
                session: group.parent,
                searchQuery: searchQuery,
                agentCount: group.agentCount,
                isAgentExpanded: isExpanded,
                onToggleAgents: onToggleExpand
            )

            if isExpanded {
                ForEach(group.agents) { agent in
                    AgentSessionRow(session: agent, searchQuery: searchQuery)
                }
            }
        }
    }
}

// MARK: - Agent Session Row

private struct AgentSessionRow: View {
    let session: Session
    var searchQuery: String = ""

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
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                HStack(spacing: PoirotTheme.Spacing.xs) {
                    Image(systemName: Self.iconForAgentType(session.agentType))
                        .font(.system(size: 10))
                        .foregroundStyle(Self.colorForAgentType(session.agentType))

                    if let agentType = session.agentType {
                        Text(agentType)
                            .font(PoirotTheme.Typography.small)
                            .foregroundStyle(Self.colorForAgentType(session.agentType))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Self.colorForAgentType(session.agentType).opacity(0.15))
                            )
                    }

                    if let desc = session.agentDescription, !desc.isEmpty {
                        Text(desc)
                            .font(PoirotTheme.Typography.caption)
                            .foregroundStyle(
                                isSelected
                                    ? PoirotTheme.Colors.accent
                                    : PoirotTheme.Colors.textSecondary
                            )
                            .lineLimit(2)
                    } else {
                        Text(HighlightedText.fuzzyAttributedString(session.title, query: searchQuery))
                            .font(PoirotTheme.Typography.caption)
                            .foregroundStyle(
                                isSelected
                                    ? PoirotTheme.Colors.accent
                                    : PoirotTheme.Colors.textSecondary
                            )
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(session.timeAgo)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }

                if session.totalTokens > 0 {
                    HStack(spacing: PoirotTheme.Spacing.xs) {
                        Text("\(SessionsListRow.formatTokens(session.totalTokens)) tk")
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.blue)

                        Text("\(session.turnCount) \(session.turnCount == 1 ? "turn" : "turns")")
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.md)
            .padding(.vertical, PoirotTheme.Spacing.xs)
            .padding(.leading, PoirotTheme.Spacing.xl + PoirotTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                    .fill(
                        isSelected
                            ? PoirotTheme.Colors.accentDim
                            : isHovered ? PoirotTheme.Colors.bgCardHover : .clear
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(session.title)
        .onHover { isHovered = $0 }
    }

    static func iconForAgentType(_ type: String?) -> String {
        switch type?.lowercased() {
        case "explore": "magnifyingglass"
        case "plan": "map"
        case "general-purpose": "cpu"
        default: "cpu"
        }
    }

    static func colorForAgentType(_ type: String?) -> Color {
        switch type?.lowercased() {
        case "explore": PoirotTheme.Colors.blue
        case "plan": PoirotTheme.Colors.green
        default: PoirotTheme.Colors.purple
        }
    }
}

// MARK: - Session Row

private struct SessionsListRow: View {
    let session: Session
    var searchQuery: String = ""
    var agentCount: Int = 0
    var isAgentExpanded: Bool = false
    var onToggleAgents: (() -> Void)?

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
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                HStack(spacing: PoirotTheme.Spacing.xs) {
                    if session.isSidechain {
                        Image(systemName: "cpu")
                            .font(.system(size: 9))
                            .foregroundStyle(PoirotTheme.Colors.purple)
                    }

                    Text(HighlightedText.fuzzyAttributedString(session.title, query: searchQuery))
                        .font(PoirotTheme.Typography.bodyMedium)
                        .foregroundStyle(
                            isSelected
                                ? PoirotTheme.Colors.accent
                                : PoirotTheme.Colors.textPrimary
                        )
                        .lineLimit(2)

                    Spacer()

                    if agentCount > 0, let onToggleAgents {
                        Button(action: onToggleAgents) {
                            HStack(spacing: 4) {
                                Image(systemName: "cpu")
                                    .font(.system(size: 10))
                                Text("\(agentCount)")
                                    .font(PoirotTheme.Typography.tiny)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 7, weight: .semibold))
                                    .rotationEffect(.degrees(isAgentExpanded ? 90 : 0))
                            }
                            .foregroundStyle(PoirotTheme.Colors.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(PoirotTheme.Colors.purple.opacity(0.15)))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help(isAgentExpanded ? "Hide agent sessions" : "Show agent sessions")
                    }

                    Text(session.timeAgo)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }

                HStack(spacing: PoirotTheme.Spacing.xs) {
                    if let model = session.model {
                        Text(Self.formatModel(model))
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(PoirotTheme.Colors.accentDim)
                            )
                    }

                    if session.totalTokens > 0 {
                        Text("\(Self.formatTokens(session.totalTokens)) tk")
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(PoirotTheme.Colors.blue.opacity(0.15))
                            )
                    }

                    Text("\(session.turnCount) \(session.turnCount == 1 ? "turn" : "turns")")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }

                if let firstPrompt = session.firstPrompt, !firstPrompt.isEmpty {
                    Text(firstPrompt)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.md)
            .padding(.vertical, PoirotTheme.Spacing.sm)
            .padding(.leading, PoirotTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                    .fill(
                        isSelected
                            ? PoirotTheme.Colors.accentDim
                            : isHovered ? PoirotTheme.Colors.bgCardHover : .clear
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(session.title)
        .onHover { isHovered = $0 }
    }

    private static func formatModel(_ model: String) -> String {
        let name = model.replacingOccurrences(of: "claude-", with: "")
        if name.hasPrefix("opus-") {
            let version = name.dropFirst("opus-".count).prefix(while: { $0 != "-" && $0 != "_" })
            return "Opus \(version)"
        } else if name.hasPrefix("sonnet-") {
            let version = name.dropFirst("sonnet-".count).prefix(while: { $0 != "-" && $0 != "_" })
            return "Sonnet \(version)"
        } else if name.hasPrefix("haiku-") {
            let version = name.dropFirst("haiku-".count).prefix(while: { $0 != "-" && $0 != "_" })
            return "Haiku \(version)"
        }
        return model
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))k"
                : String(format: "%.1fk", k)
        }
        return "\(count)"
    }
}
