import SwiftUI

// MARK: - Search Models

private enum SearchCategory: Int, CaseIterable, Hashable {
    case sessions
    case debugLogs
    case facets
    case fileChanges
    case todos
    case history
    case commands
    case skills
    case plans
    case memory
    case mcpServers
    case plugins
    case outputStyles
    case hooks
    case models
    case subAgents

    var label: String {
        switch self {
        case .sessions: "SESSIONS"
        case .debugLogs: "DEBUG LOGS"
        case .facets: "AI SUMMARIES"
        case .fileChanges: "FILE CHANGES"
        case .todos: "TODOS"
        case .history: "HISTORY"
        case .commands: "COMMANDS"
        case .skills: "SKILLS"
        case .plans: "PLANS"
        case .memory: "MEMORY"
        case .hooks: "HOOKS"
        case .mcpServers: "MCP SERVERS"
        case .plugins: "PLUGINS"
        case .outputStyles: "OUTPUT STYLES"
        case .models: "MODELS"
        case .subAgents: "SUB-AGENTS"
        }
    }

    var navItem: NavigationItem {
        switch self {
        case .sessions: .sessions
        case .debugLogs: .sessions
        case .facets: .sessions
        case .fileChanges: .sessions
        case .todos: .todos
        case .history: .history
        case .commands: .commands
        case .skills: .skills
        case .plans: .plans
        case .memory: .memory
        case .hooks: .hooks
        case .mcpServers: .mcpServers
        case .plugins: .plugins
        case .outputStyles: .outputStyles
        case .models: .models
        case .subAgents: .subAgents
        }
    }
}

private enum SearchAction {
    case openSession(Session, projectId: String)
    case openDebugLog(sessionId: String, projectId: String)
    case navigateTo(NavigationItem)
    case openDetail(NavigationItem, ConfigDetailInfo)
    case toggleMenuBar
    case addMCPServer
}

private struct SearchResult: Identifiable {
    let id: String
    let category: SearchCategory
    let icon: String
    let title: String
    let subtitle: String
    let trailing: String
    let score: Int
    let action: SearchAction
}

private struct SearchGroup {
    let category: SearchCategory
    let results: [SearchResult]
}

/// How ⌘K search matches text. Fuzzy allows scattered subsequence hits (typo-tolerant but noisy —
/// "ssh" also matches "se**ss**ion"); Match Word requires the query as a contiguous substring.
private enum SearchMode: String, CaseIterable, Identifiable {
    case fuzzy
    case matchWord

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fuzzy: "Fuzzy"
        case .matchWord: "Match Word"
        }
    }

    var icon: String {
        switch self {
        case .fuzzy: "wand.and.stars"
        case .matchWord: "text.magnifyingglass"
        }
    }
}

// MARK: - SearchOverlayView

struct SearchOverlayView: View {
    @Environment(AppState.self)
    private var appState
    @Environment(\.provider)
    private var provider
    @State
    private var query = ""
    @State
    private var selectedIndex = 0
    @State
    private var debouncedQuery = ""
    @State
    private var debounceTask: Task<Void, Never>?
    @State
    private var searchResults: [SearchGroup] = []
    @State
    private var searchTask: Task<Void, Never>?
    @State
    private var isSearching = false
    @State
    private var escMonitor: Any?
    @FocusState
    private var isFocused: Bool
    @AppStorage("globalSearchMode")
    private var searchModeRaw = SearchMode.fuzzy.rawValue

    private var searchMode: SearchMode {
        SearchMode(rawValue: searchModeRaw) ?? .fuzzy
    }

    /// Cached config items
    @State
    private var commands: [ClaudeCommand] = []
    @State
    private var skills: [ClaudeSkill] = []
    @State
    private var plans: [Plan] = []
    @State
    private var mcpServers: [MCPServer] = []
    @State
    private var plugins: [ClaudePlugin] = []
    @State
    private var outputStyles: [OutputStyle] = []
    @State
    private var hookEntries: [HookEntry] = []
    @State
    private var memoryFiles: [MemoryFile] = []
    @State
    private var todoEntries: [(sessionId: String, todos: [SessionTodo])] = []
    @State
    private var debugLogSessionIds: Set<String> = []
    @State
    private var historyEntries: [HistoryEntry] = []
    @State
    private var allFacets: [String: SessionFacets] = [:]
    @State
    private var fileHistorySessionFiles: [(sessionId: String, fileNames: [String])] = []

    // MARK: - Search Logic

    private var flatResults: [SearchResult] {
        searchResults.flatMap(\.results)
    }

    private func flatIndex(
        forGroup groupIdx: Int, offset: Int
    ) -> Int {
        var idx = 0
        for i in 0 ..< groupIdx {
            idx += searchResults[i].results.count
        }
        return idx + offset
    }

    private func triggerSearch() {
        searchTask?.cancel()
        let q = debouncedQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        searchTask = Task {
            let results = buildSearchResults(query: q)
            guard !Task.isCancelled else { return }
            searchResults = results
            isSearching = false
        }
    }

    // MARK: - Search Builder

    // swiftlint:disable function_body_length
    private func buildSearchResults(
        query q: String
    ) -> [SearchGroup] {
        func score(_ text: String) -> Int {
            switch searchMode {
            case .fuzzy: HighlightedText.fuzzyMatch(text, query: q)?.score ?? 0
            case .matchWord: HighlightedText.substringMatch(text, query: q) ?? 0
            }
        }

        let loweredQuery = q.lowercased()

        var all: [SearchResult] = []

        // Sessions
        for project in appState.projects {
            for session in project.sessions {
                if session.isSidechain, !appState.showAgentSessions { continue }
                // Match on metadata first; fall back to a content match so sessions surface by
                // what was discussed inside them, not just their title (mirrors Memory below).
                let metaBest = max(score(session.title), score(project.name), score(session.id))
                let best = metaBest > 0
                    ? metaBest
                    : (session.searchableText.contains(loweredQuery) ? 1 : 0)
                guard best > 0 else { continue }
                all.append(SearchResult(
                    id: "session-\(session.id)",
                    category: .sessions,
                    icon: "text.bubble",
                    title: session.title,
                    subtitle: project.name,
                    trailing: session.timeAgo,
                    score: best,
                    action: .openSession(session, projectId: project.id)
                ))
            }
        }

        // Debug logs
        for project in appState.projects {
            for session in project.sessions {
                guard debugLogSessionIds.contains(session.id) else { continue }
                let best = max(score(session.title), score("debug log"))
                guard best > 0 else { continue }
                all.append(SearchResult(
                    id: "debuglog-\(session.id)",
                    category: .debugLogs,
                    icon: "ladybug",
                    title: session.title,
                    subtitle: "Debug Log",
                    trailing: project.name,
                    score: best,
                    action: .openDebugLog(sessionId: session.id, projectId: project.id)
                ))
            }
        }

        // File Changes
        for entry in fileHistorySessionFiles {
            for fileName in entry.fileNames {
                let nameOnly = (fileName as NSString).lastPathComponent
                let best = max(score(nameOnly), score(fileName), score("file changes"))
                guard best > 0 else { continue }

                let sessionMatch = appState.projects
                    .compactMap { project in
                        project.sessions.first { $0.id == entry.sessionId }
                            .map { (project, $0) }
                    }.first

                let action: SearchAction = if let (project, session) = sessionMatch {
                    .openSession(session, projectId: project.id)
                } else {
                    .navigateTo(.sessions)
                }

                all.append(SearchResult(
                    id: "filechange-\(entry.sessionId)-\(fileName)",
                    category: .fileChanges,
                    icon: "clock.arrow.2.circlepath",
                    title: nameOnly,
                    subtitle: fileName,
                    trailing: sessionMatch?.1.timeAgo ?? "",
                    score: best,
                    action: action
                ))
            }
        }

        // TODOs
        for entry in todoEntries {
            for todo in entry.todos {
                let best = max(score(todo.content), score(todo.activeForm))
                guard best > 0 else { continue }
                all.append(SearchResult(
                    id: "todo-\(entry.sessionId)-\(todo.id)",
                    category: .todos,
                    icon: NavigationItem.todos.systemImage,
                    title: todo.content,
                    subtitle: entry.sessionId,
                    trailing: todo.status.rawValue,
                    score: best,
                    action: .navigateTo(.todos)
                ))
            }
        }

        // History
        for entry in historyEntries {
            let best = max(score(entry.display), score(entry.projectName))
            guard best > 0 else { continue }
            all.append(SearchResult(
                id: "history-\(entry.id)",
                category: .history,
                icon: NavigationItem.history.systemImage,
                title: entry.snippet,
                subtitle: entry.projectName,
                trailing: entry.timeAgo,
                score: best,
                action: .navigateTo(.history)
            ))
        }

        // Commands
        for cmd in commands {
            let best = max(score(cmd.name), score(cmd.description))
            guard best > 0 else { continue }
            all.append(SearchResult(
                id: "cmd-\(cmd.id)",
                category: .commands,
                icon: NavigationItem.commands.systemImage,
                title: cmd.name,
                subtitle: cmd.description,
                trailing: cmd.argumentHint ?? "",
                score: best,
                action: .openDetail(.commands, ConfigDetailInfo(
                    name: cmd.name,
                    markdownContent: cmd.body,
                    filePath: cmd.filePath,
                    scope: cmd.scope
                ))
            ))
        }

        // Skills
        for skill in skills {
            let best = max(score(skill.name), score(skill.description))
            guard best > 0 else { continue }
            all.append(SearchResult(
                id: "skill-\(skill.id)",
                category: .skills,
                icon: NavigationItem.skills.systemImage,
                title: skill.name,
                subtitle: skill.description,
                trailing: skill.model ?? "",
                score: best,
                action: .openDetail(.skills, ConfigDetailInfo(
                    name: skill.name,
                    markdownContent: skill.body,
                    filePath: skill.filePath,
                    scope: skill.scope
                ))
            ))
        }

        // Plans
        for plan in plans {
            let best = max(score(plan.name), score(String(plan.content.prefix(200))))
            guard best > 0 else { continue }
            all.append(SearchResult(
                id: "plan-\(plan.id)",
                category: .plans,
                icon: NavigationItem.plans.systemImage,
                title: plan.name,
                subtitle: plan.fileURL.lastPathComponent,
                trailing: "",
                score: best,
                action: .openDetail(.plans, ConfigDetailInfo(
                    name: plan.name,
                    markdownContent: plan.content,
                    filePath: plan.fileURL.path,
                    scope: nil
                ))
            ))
        }

        // MCP Servers
        for server in mcpServers {
            let toolScore = server.tools.map { score($0) }.max() ?? 0
            let best = max(score(server.name), max(toolScore, score(server.status.label)))
            guard best > 0 else { continue }
            let toolLabel = server.isWildcard ? "All tools" : "\(server.tools.count) tools"
            all.append(SearchResult(
                id: "mcp-\(server.id)",
                category: .mcpServers,
                icon: NavigationItem.mcpServers.systemImage,
                title: server.name,
                subtitle: server.tools.prefix(3).joined(separator: ", "),
                trailing: "\(server.status.label) · \(toolLabel)",
                score: best,
                action: .navigateTo(.mcpServers)
            ))
        }

        // Plugins
        for plugin in plugins {
            let best = max(score(plugin.name), score(plugin.author))
            guard best > 0 else { continue }
            all.append(SearchResult(
                id: "plugin-\(plugin.id)",
                category: .plugins,
                icon: NavigationItem.plugins.systemImage,
                title: plugin.name,
                subtitle: "by \(plugin.author)",
                trailing: "v\(plugin.version)",
                score: best,
                action: .navigateTo(.plugins)
            ))
        }

        // Output Styles
        for style in outputStyles {
            let best = max(score(style.name), score(style.description))
            guard best > 0 else { continue }
            all.append(SearchResult(
                id: "style-\(style.id)",
                category: .outputStyles,
                icon: NavigationItem.outputStyles.systemImage,
                title: style.name,
                subtitle: style.description,
                trailing: "",
                score: best,
                action: .openDetail(.outputStyles, ConfigDetailInfo(
                    name: style.name,
                    markdownContent: style.body,
                    filePath: style.filePath,
                    scope: style.scope
                ))
            ))
        }

        // Models
        for model in provider.supportedModels {
            let s = score(model)
            guard s > 0 else { continue }
            let isDefault = model == provider.defaultModelName
            all.append(SearchResult(
                id: "model-\(model)",
                category: .models,
                icon: NavigationItem.models.systemImage,
                title: model,
                subtitle: isDefault ? "Default model" : "AI Model",
                trailing: isDefault ? "Default" : "",
                score: s,
                action: .navigateTo(.models)
            ))
        }

        // Hooks
        for hook in hookEntries {
            let cmdScore = score(hook.firstHandler?.displayCommand ?? "")
            let matcherScore = score(hook.matcher ?? "")
            let eventScore = score(hook.event.label)
            let best = max(cmdScore, matcherScore, eventScore)
            guard best > 0 else { continue }
            all.append(SearchResult(
                id: "hook-\(hook.id)",
                category: .hooks,
                icon: hook.event.icon,
                title: hook.firstHandler?.displayCommand ?? hook.event.label,
                subtitle: hook.event.label + (hook.matcher.map { " · \($0)" } ?? ""),
                trailing: hook.firstHandler?.type.label ?? "",
                score: best,
                action: .navigateTo(.hooks)
            ))
        }

        // Sub-agents (built-in + custom)
        let allAgents = SubAgent.builtIn + ClaudeConfigLoader.loadCustomAgents()
        for agent in allAgents {
            let best = max(score(agent.name), score(agent.description))
            guard best > 0 else { continue }
            all.append(SearchResult(
                id: "agent-\(agent.id)",
                category: .subAgents,
                icon: agent.icon,
                title: agent.name,
                subtitle: agent.description,
                trailing: "\(agent.tools.count) tools",
                score: best,
                action: .navigateTo(.subAgents)
            ))
        }

        // Quick Actions
        let menuBarLabel = "Toggle Menu Bar Icon"
        let menuBarScore = score(menuBarLabel)
        if menuBarScore > 0 {
            all.append(SearchResult(
                id: "action-toggle-menubar",
                category: .commands,
                icon: "menubar.rectangle",
                title: menuBarLabel,
                subtitle: "Show or hide the menu bar icon",
                trailing: "",
                score: menuBarScore,
                action: .toggleMenuBar
            ))
        }

        let addMCPLabel = "Add MCP Server"
        let addMCPScore = score(addMCPLabel)
        if addMCPScore > 0 {
            all.append(SearchResult(
                id: "action-add-mcp-server",
                category: .mcpServers,
                icon: "plus.circle",
                title: addMCPLabel,
                subtitle: "Open the MCP server setup wizard",
                trailing: "",
                score: addMCPScore,
                action: .addMCPServer
            ))
        }

        // Facets (AI Summaries)
        for (sessionId, facets) in allFacets {
            let goalScore = score(facets.underlyingGoal)
            let summaryScore = score(facets.briefSummary)
            let categoryScore = facets.goalCategories.keys
                .map { score($0) }.max() ?? 0
            let typeScore = score(facets.sessionType)
            let best = max(goalScore, summaryScore, categoryScore, typeScore)
            guard best > 0 else { continue }

            let sessionMatch = appState.projects
                .compactMap { project in
                    project.sessions.first { $0.id == sessionId }
                        .map { (project, $0) }
                }.first

            let action: SearchAction = if let (project, session) = sessionMatch {
                .openSession(session, projectId: project.id)
            } else {
                .navigateTo(.sessions)
            }

            all.append(SearchResult(
                id: "facets-\(sessionId)",
                category: .facets,
                icon: "sparkles",
                title: facets.briefSummary.isEmpty
                    ? facets.underlyingGoal
                    : facets.briefSummary,
                subtitle: facets.underlyingGoal,
                trailing: facets.outcomeLabel,
                score: best,
                action: action
            ))
        }

        // Memory
        for memory in memoryFiles {
            let nameScore = score(memory.name)
            let best = nameScore > 0
                ? nameScore
                : (memory.content.localizedCaseInsensitiveContains(q) ? 1 : 0)
            guard best > 0 else { continue }
            all.append(SearchResult(
                id: "memory-\(memory.id)",
                category: .memory,
                icon: memory.isMain
                    ? "brain.head.profile.fill"
                    : "doc.text.fill",
                title: memory.name,
                subtitle: memory.filename,
                trailing: memory.isMain ? "Entrypoint" : "",
                score: best,
                action: .openDetail(
                    .memory,
                    ConfigDetailInfo(
                        name: memory.name,
                        markdownContent: memory.content,
                        filePath: memory.fileURL.path,
                        scope: nil
                    )
                )
            ))
        }

        let grouped = Dictionary(grouping: all) { $0.category }
        let maxPerGroup = 5
        return SearchCategory.allCases.compactMap { cat in
            guard var items = grouped[cat], !items.isEmpty
            else { return nil }
            items.sort { $0.score > $1.score }
            return SearchGroup(
                category: cat,
                results: Array(items.prefix(maxPerGroup))
            )
        }
    }

    // swiftlint:enable function_body_length

    // MARK: - Empty State Data

    private var configNavItems: [NavigationItem] {
        NavigationItem.allItems.filter {
            $0.id != "sessions"
        }
    }

    private var recentSessions: [(Project, Session)] {
        Array(
            appState.projects
                .flatMap { p in p.sessions.map { (p, $0) } }
                .sorted { $0.1.startedAt > $1.1.startedAt }
                .prefix(5)
        )
    }

    private var emptyItemCount: Int {
        configNavItems.count + recentSessions.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                searchInput
                Divider().opacity(0.3)
                searchResultsList
            }
            .frame(width: 580)
            .background(
                RoundedRectangle(
                    cornerRadius: PoirotTheme.Radius.lg
                )
                .fill(PoirotTheme.Colors.bgCard)
                .stroke(PoirotTheme.Colors.border)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PoirotTheme.Radius.lg
                )
            )
            .shadow(color: .black.opacity(0.4), radius: 30)
            .padding(.top, 80)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            isFocused = true
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    dismiss()
                    return nil
                }
                return event
            }
        }
        .task { await loadConfigItems() }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            let maxIdx = query.isEmpty
                ? emptyItemCount - 1
                : flatResults.count - 1
            if selectedIndex < maxIdx {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            if query.isEmpty {
                navigateEmptyState(at: selectedIndex)
            } else {
                let flat = flatResults
                guard selectedIndex < flat.count
                else { return .ignored }
                navigate(to: flat[selectedIndex])
            }
            return .handled
        }
        .onChange(of: query) {
            selectedIndex = 0
            if !query.isEmpty { isSearching = true }
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                debouncedQuery = query
            }
        }
        .onChange(of: debouncedQuery) {
            triggerSearch()
        }
        .onChange(of: searchModeRaw) {
            triggerSearch()
        }
        .onDisappear {
            debounceTask?.cancel()
            searchTask?.cancel()
            if let escMonitor {
                NSEvent.removeMonitor(escMonitor)
            }
            escMonitor = nil
        }
    }

    // MARK: - Search Input

    private var searchInput: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(PoirotTheme.Typography.large)
                .foregroundStyle(
                    PoirotTheme.Colors.textTertiary
                )

            TextField(
                "Search sessions, history, commands, memory, plans...",
                text: $query
            )
            .textFieldStyle(.plain)
            .font(PoirotTheme.Typography.subheading)
            .foregroundStyle(PoirotTheme.Colors.textPrimary)
            .focused($isFocused)

            if !query.isEmpty {
                let count = flatResults.count
                Text("\(count) results")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(
                        PoirotTheme.Colors.textTertiary
                    )
                    .contentTransition(.numericText())
            }

            searchModeMenu

            Text("ESC")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(
                    PoirotTheme.Colors.textTertiary
                )
                .padding(.horizontal, 6)
                .padding(.vertical, PoirotTheme.Spacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PoirotTheme.Colors.bgElevated)
                )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var searchModeMenu: some View {
        Menu {
            Picker("Match mode", selection: Binding(
                get: { searchMode },
                set: { searchModeRaw = $0.rawValue }
            )) {
                ForEach(SearchMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.icon).tag(mode)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: searchMode.icon)
                Text(searchMode.label)
                Image(systemName: "chevron.down")
                    .font(PoirotTheme.Typography.nano)
            }
            .font(PoirotTheme.Typography.tiny)
            .foregroundStyle(PoirotTheme.Colors.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                    .fill(PoirotTheme.Colors.bgElevated)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Search matching mode")
    }

    // MARK: - Results List

    private var searchResultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                    if query.isEmpty {
                        emptyStateContent
                    } else if isSearching, flatResults.isEmpty {
                        searchShimmer
                    } else if flatResults.isEmpty {
                        noResultsView
                    } else {
                        groupedSearchResults
                    }
                }
                .padding(PoirotTheme.Spacing.sm)
            }
            .frame(maxHeight: 400)
            .onChange(of: selectedIndex) {
                proxy.scrollTo(
                    selectedIndex, anchor: .center
                )
            }
        }
    }

    // MARK: - Grouped Search Results

    private var groupedSearchResults: some View {
        let groups = searchResults
        return ForEach(
            Array(groups.enumerated()),
            id: \.element.category
        ) { groupIdx, group in
            sectionHeader(group.category.label)

            ForEach(
                Array(group.results.enumerated()),
                id: \.element.id
            ) { offset, result in
                let idx = flatIndex(
                    forGroup: groupIdx, offset: offset
                )
                UniversalResultRow(
                    result: result,
                    query: query,
                    isSelected: idx == selectedIndex,
                    useExactHighlight: searchMode == .matchWord
                )
                .id(idx)
                .onTapGesture { navigate(to: result) }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
            sectionHeader("SCREENS")

            ForEach(
                Array(configNavItems.enumerated()),
                id: \.element.id
            ) { index, navItem in
                NavShortcutRow(
                    navItem: navItem,
                    count: appState.sidebarCounts[navItem.id],
                    isSelected: index == selectedIndex
                )
                .id(index)
                .onTapGesture {
                    appState.selectedNav = navItem
                    dismiss()
                }
            }

            if !recentSessions.isEmpty {
                sectionHeader("RECENT")

                ForEach(
                    Array(recentSessions.enumerated()),
                    id: \.element.1.id
                ) { index, pair in
                    let idx = configNavItems.count + index
                    RecentSessionRow(
                        session: pair.1,
                        projectName: pair.0.name,
                        isSelected: idx == selectedIndex
                    )
                    .id(idx)
                    .onTapGesture {
                        appState.selectedProject = pair.0.id
                        appState.selectedSession = pair.1
                        appState.selectedNav = .sessions
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(
                    PoirotTheme.Colors.textTertiary
                )
            Text("No results for \"\(query)\"")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(
                    PoirotTheme.Colors.textTertiary
                )
        }
        .frame(maxWidth: .infinity)
        .padding(PoirotTheme.Spacing.xl)
    }

    // MARK: - Search Shimmer

    private var searchShimmer: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
            ForEach(0 ..< 5, id: \.self) { _ in
                HStack(spacing: PoirotTheme.Spacing.sm) {
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .frame(width: 20, height: 14)

                    VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                            .fill(PoirotTheme.Colors.bgElevated)
                            .frame(width: CGFloat.random(in: 120 ... 220), height: 12)
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                            .fill(PoirotTheme.Colors.bgElevated)
                            .frame(width: CGFloat.random(in: 80 ... 160), height: 10)
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .frame(width: 50, height: 10)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, PoirotTheme.Spacing.sm)
                .shimmer(cornerRadius: PoirotTheme.Radius.sm)
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(
        _ title: String
    ) -> some View {
        Text(title)
            .font(PoirotTheme.Typography.sectionHeader)
            .foregroundStyle(
                PoirotTheme.Colors.textTertiary
            )
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.top, PoirotTheme.Spacing.sm)
            .padding(.bottom, PoirotTheme.Spacing.xxs)
    }

    // MARK: - Actions

    private func dismiss() {
        @Bindable
        var state = appState
        state.isSearchPresented = false
    }

    private func navigate(to result: SearchResult) {
        switch result.action {
        case let .openSession(session, projectId):
            appState.selectedProject = projectId
            appState.selectedSession = session
            appState.selectedNav = .sessions

        case let .openDebugLog(sessionId, projectId):
            appState.selectedProject = projectId
            appState.selectedNav = .sessions
            appState.showDebugLogSessionId = sessionId

        case let .navigateTo(navItem):
            appState.selectedNav = navItem

        case let .openDetail(navItem, detail):
            appState.selectedNav = navItem
            appState.activeConfigDetail = detail
            appState.pushConfigDetail(
                navItemID: navItem.id, detail: detail
            )

        case .toggleMenuBar:
            let key = "showMenuBarIcon"
            let current = UserDefaults.standard.object(forKey: key) as? Bool ?? true
            UserDefaults.standard.set(!current, forKey: key)

        case .addMCPServer:
            appState.selectedNav = .mcpServers
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                appState.configAddTrigger = UUID()
            }
        }
        dismiss()
    }

    private func navigateEmptyState(at index: Int) {
        let navItems = configNavItems
        if index < navItems.count {
            appState.selectedNav = navItems[index]
            dismiss()
        } else {
            let sessionIdx = index - navItems.count
            let recent = recentSessions
            guard sessionIdx < recent.count
            else { return }
            let (project, session) = recent[sessionIdx]
            appState.selectedProject = project.id
            appState.selectedSession = session
            appState.selectedNav = .sessions
            dismiss()
        }
    }

    private func loadConfigItems() async {
        let projectPath = appState.effectiveConfigProjectPath
        let result = await Task.detached {
            let rawServers = ClaudeConfigLoader.loadMCPServers(
                projectPath: projectPath
            )
            return (
                ClaudeConfigLoader.loadCommands(projectPath: projectPath),
                ClaudeConfigLoader.loadSkills(projectPath: projectPath),
                ClaudeConfigLoader.loadPlans(),
                MCPServerStatusChecker.resolveStatuses(for: rawServers),
                ClaudeConfigLoader.loadPlugins(),
                ClaudeConfigLoader.loadOutputStyles(projectPath: projectPath),
                TodoLoader().loadAllTodos(),
                Set(DebugLogLoader().allSessionIds()),
                HistoryLoader().loadAll(),
                ClaudeConfigLoader.projectsWithMemory().flatMap { dirName, _ in
                    ClaudeConfigLoader.loadMemoryFiles(projectDirName: dirName)
                }
            )
        }.value
        commands = result.0
        skills = result.1
        plans = result.2
        mcpServers = result.3
        plugins = result.4
        outputStyles = result.5
        let allTodos = result.6
        todoEntries = allTodos.filter { !$0.value.isEmpty }
            .map { (sessionId: $0.key, todos: $0.value) }
        debugLogSessionIds = result.7
        historyEntries = result.8
        memoryFiles = result.9
        hookEntries = await Task.detached {
            ClaudeConfigLoader.loadHooks(projectPath: projectPath)
        }.value
        allFacets = await Task.detached {
            FacetsLoader().loadAllFacets()
        }.value
        fileHistorySessionFiles = await Task.detached {
            Self.scanFileHistorySessions()
        }.value
    }

    /// Scans ~/.claude/file-history/ for session directories and collects file names
    /// from the corresponding session JSONL files.
    nonisolated private static func scanFileHistorySessions() -> [(sessionId: String, fileNames: [String])] {
        let loader = FileHistoryLoader()
        let fm = FileManager.default
        let historyPath = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/file-history")

        guard let sessionDirs = try? fm.contentsOfDirectory(
            at: historyPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [(sessionId: String, fileNames: [String])] = []
        for dir in sessionDirs.prefix(50) {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let sessionId = dir.lastPathComponent
            let entries = loader.loadFileHistory(for: sessionId, projectPath: "")
            if !entries.isEmpty {
                results.append((sessionId: sessionId, fileNames: entries.map(\.fileName)))
            }
        }
        return results
    }
}

// MARK: - Universal Result Row

private struct UniversalResultRow: View {
    let result: SearchResult
    let query: String
    let isSelected: Bool
    var useExactHighlight = false

    @State
    private var isHovered = false

    private var highlightedTitle: AttributedString {
        useExactHighlight
            ? HighlightedText.attributedString(result.title, query: query)
            : HighlightedText.fuzzyAttributedString(result.title, query: query)
    }

    var body: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: result.icon)
                .font(PoirotTheme.Typography.small)
                .foregroundStyle(
                    PoirotTheme.Colors.textTertiary
                )
                .frame(width: 20)

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                Text(highlightedTitle)
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(
                    PoirotTheme.Colors.textPrimary
                )
                .lineLimit(1)

                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(
                            PoirotTheme.Colors.textTertiary
                        )
                        .lineLimit(1)
                }
            }

            Spacer()

            if !result.trailing.isEmpty {
                Text(result.trailing)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(
                        PoirotTheme.Colors.textTertiary
                    )
            }

            if isSelected {
                Text("↵")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(
                        PoirotTheme.Colors.textTertiary
                    )
                    .padding(.horizontal, PoirotTheme.Spacing.xs)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                            .fill(
                                PoirotTheme.Colors
                                    .bgElevated
                            )
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, PoirotTheme.Spacing.sm)
        .background(
            RoundedRectangle(
                cornerRadius: PoirotTheme.Radius.sm
            )
            .fill(
                isSelected || isHovered
                    ? PoirotTheme.Colors.bgElevated
                    : .clear
            )
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Navigation Shortcut Row

private struct NavShortcutRow: View {
    let navItem: NavigationItem
    let count: Int?
    let isSelected: Bool

    @State
    private var isHovered = false

    var body: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: navItem.systemImage)
                .font(PoirotTheme.Typography.small)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(PoirotTheme.Colors.accent)
                .frame(width: 20)

            Text(navItem.title)
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(
                    PoirotTheme.Colors.textPrimary
                )

            Spacer()

            if let count {
                Text("\(count)")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(
                        PoirotTheme.Colors.textTertiary
                    )
            }

            Image(systemName: "chevron.right")
                .font(PoirotTheme.Typography.nanoSemibold)
                .foregroundStyle(
                    PoirotTheme.Colors.textTertiary
                )

            if isSelected {
                Text("↵")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(
                        PoirotTheme.Colors.textTertiary
                    )
                    .padding(.horizontal, PoirotTheme.Spacing.xs)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                            .fill(
                                PoirotTheme.Colors
                                    .bgElevated
                            )
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, PoirotTheme.Spacing.sm)
        .background(
            RoundedRectangle(
                cornerRadius: PoirotTheme.Radius.sm
            )
            .fill(
                isSelected || isHovered
                    ? PoirotTheme.Colors.bgElevated
                    : .clear
            )
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Recent Session Row

private struct RecentSessionRow: View {
    let session: Session
    let projectName: String
    let isSelected: Bool

    @State
    private var isHovered = false

    var body: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: "text.bubble")
                .font(PoirotTheme.Typography.small)
                .foregroundStyle(
                    PoirotTheme.Colors.textTertiary
                )
                .frame(width: 20)

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                Text(session.title)
                    .font(
                        PoirotTheme.Typography.captionMedium
                    )
                    .foregroundStyle(
                        PoirotTheme.Colors.textPrimary
                    )
                    .lineLimit(1)

                Text(projectName)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(
                        PoirotTheme.Colors.textTertiary
                    )
                    .lineLimit(1)
            }

            Spacer()

            Text(session.timeAgo)
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(
                    PoirotTheme.Colors.textTertiary
                )

            if isSelected {
                Text("↵")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(
                        PoirotTheme.Colors.textTertiary
                    )
                    .padding(.horizontal, PoirotTheme.Spacing.xs)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                            .fill(
                                PoirotTheme.Colors
                                    .bgElevated
                            )
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, PoirotTheme.Spacing.sm)
        .background(
            RoundedRectangle(
                cornerRadius: PoirotTheme.Radius.sm
            )
            .fill(
                isSelected || isHovered
                    ? PoirotTheme.Colors.bgElevated
                    : .clear
            )
        )
        .onHover { isHovered = $0 }
    }
}
