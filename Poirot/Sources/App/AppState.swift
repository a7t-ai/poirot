import Observation
import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: AttributedString
    let icon: String?
    let style: ToastStyle
    let url: URL?
    let animateIcon: Bool

    enum ToastStyle {
        case success, error, info

        var color: Color {
            switch self {
            case .success: PoirotTheme.Colors.green
            case .error: PoirotTheme.Colors.red
            case .info: PoirotTheme.Colors.blue
            }
        }

        var defaultIcon: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error: "xmark.circle.fill"
            case .info: "info.circle.fill"
            }
        }
    }
}

enum SessionLayout: String {
    case grid
    case list
}

enum ConfigLayout: String {
    case grid
    case list
}

struct ConfigDetailInfo: Equatable {
    let name: String
    let markdownContent: String
    let filePath: String
    let scope: ConfigScope?
}

enum NavigationEntry: Equatable {
    case session(Session)
    case configList(navItemID: String)
    case configDetail(navItemID: String, detail: ConfigDetailInfo)
}

enum ProjectSortOption: String, CaseIterable {
    case recentActivity
    case name
    case sessionCount

    var label: String {
        switch self {
        case .recentActivity: String(localized: "Recent Activity")
        case .name: String(localized: "Name")
        case .sessionCount: String(localized: "Session Count")
        }
    }
}

@Observable
final class AppState {
    var fontScale: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: "fontScale")
        return stored > 0 ? CGFloat(stored) : 1.0
    }() {
        didSet {
            UserDefaults.standard.set(Double(fontScale), forKey: "fontScale")
            PoirotTheme.Typography.scale = fontScale
        }
    }

    var selectedNav: NavigationItem = .sessions {
        didSet {
            guard !isNavigatingHistory else { return }
            activeConfigDetail = nil
            if selectedNav.id != NavigationItem.sessions.id {
                selectedSession = nil
            }
        }
    }

    var selectedSession: Session? {
        didSet {
            isShowingFileHistory = false
            guard !isNavigatingHistory else { return }
            // Push to history when user navigates to a new session
            if let session = selectedSession {
                // Skip if this session is already at the current history position
                // (e.g. ContentView re-set it with a cached/loaded version)
                if navigationHistoryIndex >= 0,
                   navigationHistoryIndex < navigationHistory.count,
                   case let .session(existing) = navigationHistory[navigationHistoryIndex],
                   existing.id == session.id {
                    // Update the entry in-place (may have loaded messages now)
                    navigationHistory[navigationHistoryIndex] = .session(session)
                    return
                }
                // Trim forward history if we navigated back then chose a new session
                if navigationHistoryIndex < navigationHistory.count - 1 {
                    navigationHistory.removeSubrange((navigationHistoryIndex + 1)...)
                }
                // Avoid duplicates at the top
                if case let .session(last) = navigationHistory.last, last.id == session.id {
                    // skip
                } else {
                    navigationHistory.append(.session(session))
                    navigationHistoryIndex = navigationHistory.count - 1
                }
            }
        }
    }

    var selectedProject: String?

    // MARK: - Navigation History

    private(set) var navigationHistory: [NavigationEntry] = []
    private(set) var navigationHistoryIndex: Int = -1
    private var isNavigatingHistory = false

    var canNavigateBack: Bool {
        navigationHistoryIndex > 0
    }

    var canNavigateForward: Bool {
        navigationHistoryIndex < navigationHistory.count - 1
    }

    func navigateBack() {
        guard canNavigateBack else { return }
        isNavigatingHistory = true
        navigationHistoryIndex -= 1
        restoreEntry(navigationHistory[navigationHistoryIndex])
        isNavigatingHistory = false
    }

    func navigateForward() {
        guard canNavigateForward else { return }
        isNavigatingHistory = true
        navigationHistoryIndex += 1
        restoreEntry(navigationHistory[navigationHistoryIndex])
        isNavigatingHistory = false
    }

    func pushConfigDetail(navItemID: String, detail: ConfigDetailInfo) {
        guard !isNavigatingHistory else { return }
        if navigationHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((navigationHistoryIndex + 1)...)
        }
        // Push a list entry first so the back button has somewhere to go
        let currentEntry = navigationHistoryIndex >= 0 ? navigationHistory[navigationHistoryIndex] : nil
        if currentEntry != .configList(navItemID: navItemID) {
            navigationHistory.append(.configList(navItemID: navItemID))
            navigationHistoryIndex = navigationHistory.count - 1
        }
        let entry = NavigationEntry.configDetail(navItemID: navItemID, detail: detail)
        navigationHistory.append(entry)
        navigationHistoryIndex = navigationHistory.count - 1
    }

    private func restoreEntry(_ entry: NavigationEntry) {
        switch entry {
        case let .session(session):
            selectedNav = .sessions
            activeConfigDetail = nil
            selectedSession = session
        case let .configList(navItemID):
            if let navItem = NavigationItem.allItems.first(where: { $0.id == navItemID }) {
                selectedNav = navItem
            }
            selectedSession = nil
            activeConfigDetail = nil
        case let .configDetail(navItemID, detail):
            if let navItem = NavigationItem.allItems.first(where: { $0.id == navItemID }) {
                selectedNav = navItem
            }
            selectedSession = nil
            activeConfigDetail = detail
        }
    }

    var toastQueue: [Toast] = []
    var isSearchPresented: Bool = false
    var isShortcutHelpPresented: Bool = false
    var sidebarKeyboardIndex: Int = -1
    var sessionSearchQuery: String = ""
    var isSessionSearchActive: Bool = false
    var isShowingFileHistory: Bool = false
    var isToolFilterActive: Bool = false
    var activeToolFilters: Set<String> = []
    var projects: [Project] = []
    var isLoadingProjects: Bool = true
    var isLoadingMoreProjects: Bool = true
    var isLoadingSession: Bool = false
    var sessionLayout: SessionLayout = {
        if let stored = UserDefaults.standard.string(forKey: "sessionLayout"),
           let layout = SessionLayout(rawValue: stored) {
            return layout
        }
        return .grid
    }() {
        didSet {
            UserDefaults.standard.set(sessionLayout.rawValue, forKey: "sessionLayout")
        }
    }

    var activeConfigDetail: ConfigDetailInfo?
    var configDetailFormatted: Bool = true
    var showDebugLogSessionId: String?
    var configAddTrigger = UUID()
    var sidebarCounts: [String: Int] = [:]

    var configProjectPath: String? = {
        guard let stored = UserDefaults.standard.string(forKey: "configProjectPath") else { return nil }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: stored, isDirectory: &isDir), isDir.boolValue else { return nil }
        return stored
    }() {
        didSet {
            if let path = configProjectPath {
                UserDefaults.standard.set(path, forKey: "configProjectPath")
            } else {
                UserDefaults.standard.removeObject(forKey: "configProjectPath")
            }
        }
    }

    var configProjectName: String? {
        guard let path = configProjectPath else { return nil }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var effectiveConfigProjectPath: String? {
        configProjectPath ?? currentProject?.path
    }

    nonisolated static func computeSidebarCounts(
        supportedModelsCount: Int,
        projectPath: String? = nil
    ) -> [String: Int] {
        let todoCount = TodoLoader().loadAllTodos().values.reduce(0) { $0 + $1.count }
        let historyCount = HistoryLoader().entryCount()

        return [
            "todos": todoCount,
            "history": historyCount,
            "commands": ClaudeConfigLoader.loadCommands(projectPath: projectPath).count,
            "skills": ClaudeConfigLoader.loadSkills(projectPath: projectPath).count,
            "plans": ClaudeConfigLoader.loadPlans().count,
            "memory": ClaudeConfigLoader.totalMemoryFileCount(),
            "mcpServers": ClaudeConfigLoader.loadMCPServers(projectPath: projectPath).count,
            "models": supportedModelsCount,
            "hooks": ClaudeConfigLoader.loadHooks(projectPath: projectPath).count,
            "subAgents": SubAgent.builtIn.count + ClaudeConfigLoader.loadCustomAgents().count,
            "plugins": ClaudeConfigLoader.loadPlugins().count,
            "outputStyles": ClaudeConfigLoader.loadOutputStyles(projectPath: projectPath).count,
        ]
    }

    var configLayouts: [String: ConfigLayout] = {
        guard let data = UserDefaults.standard.data(forKey: "configLayouts"),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict.compactMapValues { ConfigLayout(rawValue: $0) }
    }() {
        didSet {
            let raw = configLayouts.mapValues(\.rawValue)
            if let data = try? JSONEncoder().encode(raw) {
                UserDefaults.standard.set(data, forKey: "configLayouts")
            }
        }
    }

    func configLayout(for screenID: String) -> ConfigLayout {
        configLayouts[screenID] ?? .list
    }

    func toggleConfigLayout(for screenID: String) {
        let current = configLayout(for: screenID)
        configLayouts[screenID] = current == .grid ? .list : .grid
    }

    var showAgentSessions: Bool = UserDefaults.standard.bool(forKey: "showAgentSessions") {
        didSet {
            UserDefaults.standard.set(showAgentSessions, forKey: "showAgentSessions")
        }
    }

    var projectSortOption: ProjectSortOption = .recentActivity
    var sidebarSearchQuery: String = ""
    var allBlocksExpanded = false
    var refreshID: UUID = .init()
    private(set) var sessionCache: [String: Session] = [:]

    var currentProject: Project? {
        guard let id = selectedProject else { return nil }
        return projects.first { $0.id == id }
    }

    var filteredSortedProjects: [Project] {
        let visible: [Project] = if showAgentSessions {
            projects
        } else {
            projects.compactMap { project in
                let filtered = project.sessions.filter { !$0.isSidechain }
                guard !filtered.isEmpty else { return nil }
                if filtered.count == project.sessions.count { return project }
                return project.withSessions(filtered)
            }
        }
        let nonEmpty = visible.filter { !$0.sessions.isEmpty }
        let searched: [Project]
        let trimmed = sidebarSearchQuery.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            searched = nonEmpty
        } else {
            searched = nonEmpty.compactMap { project in
                if HighlightedText.fuzzyMatch(project.name, query: trimmed) != nil { return project }
                let matchingSessions = project.sessions.filter {
                    HighlightedText.fuzzyMatch($0.title, query: trimmed) != nil
                        || HighlightedText.fuzzyMatch($0.id, query: trimmed) != nil
                }
                if matchingSessions.isEmpty { return nil }
                return project.withSessions(matchingSessions)
            }
        }

        if !trimmed.isEmpty {
            return searched.sorted {
                HighlightedText.bestScore(
                    projectName: $0.name, sessionTitles: $0.sessions.map(\.title), query: trimmed
                ) > HighlightedText.bestScore(
                    projectName: $1.name, sessionTitles: $1.sessions.map(\.title), query: trimmed
                )
            }
        }

        switch projectSortOption {
        case .recentActivity:
            return searched.sorted {
                ($0.recentSession?.startedAt ?? .distantPast) > ($1.recentSession?.startedAt ?? .distantPast)
            }
        case .name:
            return searched.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .sessionCount:
            return searched.sorted {
                $0.sessions.count + $0.unloadedSessionCount > $1.sessions.count + $1.unloadedSessionCount
            }
        }
    }

    func cacheSession(_ session: Session) {
        sessionCache[session.id] = session
    }

    func cachedSession(for id: String) -> Session? {
        sessionCache[id]
    }

    func clearCache() {
        sessionCache.removeAll()
    }

    func projectDirectoryURL(for project: Project) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return URL(fileURLWithPath: "\(home)/.claude/projects/\(project.id)")
    }

    func deleteProject(_ project: Project) {
        // Clear selection if current session belongs to this project
        if let selected = selectedSession, project.sessions.contains(where: { $0.id == selected.id }) {
            selectedSession = nil
        }

        // Remove sessions from cache
        for session in project.sessions {
            sessionCache.removeValue(forKey: session.id)
        }

        // Remove the folder
        let dirURL = projectDirectoryURL(for: project)
        try? FileManager.default.removeItem(at: dirURL)

        // Remove from state
        projects.removeAll { $0.id == project.id }
        availableProjectCount = max(0, availableProjectCount - 1)
        loadedSessionLimits[project.id] = nil
        sessionLimits[project.id] = nil
    }

    // MARK: - Lazy Loading

    /// How many project folders, and sessions per project, load at a time.
    var loadBatchSize: LoadBatchSize = AppState.storedLoadBatchSize {
        didSet {
            UserDefaults.standard.set(loadBatchSize.rawValue, forKey: "loadBatchSize")
            // Start over with one batch of the new size
            projectLoadTarget = loadBatchSize.limit
            sessionLimits = [:]
        }
    }

    /// How many project folders, most recently active first, the session list holds. Grows by a
    /// batch each time the list scrolls to its end.
    private(set) var projectLoadTarget = AppState.storedLoadBatchSize.limit

    /// Project folders found on disk by the last scan.
    var availableProjectCount = 0

    /// Session limits raised with "Show more", by project ID. Other projects use the batch size.
    private(set) var sessionLimits: [String: Int] = [:]

    /// The session limit each loaded project was parsed with, by project ID.
    private var loadedSessionLimits: [String: Int] = [:]

    var hasMoreProjects: Bool {
        projectLoadTarget < availableProjectCount
    }

    func sessionLimit(for projectID: String) -> Int {
        sessionLimits[projectID] ?? loadBatchSize.limit
    }

    /// True while a project's "Show more" request is waiting for its sessions to load.
    func isLoadingSessions(for projectID: String) -> Bool {
        guard let loaded = loadedSessionLimits[projectID] else { return false }
        return loaded != sessionLimit(for: projectID)
    }

    /// Asks for the next batch of project folders. Ignored while a load is running, so a list end
    /// that stays on screen asks again once the current batch lands.
    func loadMoreProjects() {
        guard hasMoreProjects, !isLoadingMoreProjects else { return }
        projectLoadTarget = Self.adding(loadBatchSize.limit, to: projectLoadTarget)
    }

    /// Asks for the next batch of sessions in one project.
    func loadMoreSessions(for projectID: String) {
        sessionLimits[projectID] = Self.adding(loadBatchSize.limit, to: sessionLimit(for: projectID))
    }

    /// The folders a load pass parses, most recently active first. A refresh re-parses every
    /// folder in the loaded window; otherwise only folders not loaded yet, or loaded with a
    /// different session limit.
    func projectDirectoriesToLoad(from directories: [URL], isRefresh: Bool) -> [URL] {
        directories.prefix(projectLoadTarget).filter { url in
            let id = url.lastPathComponent
            return isRefresh || loadedSessionLimits[id] != sessionLimit(for: id)
        }
    }

    /// Adds or replaces a project parsed by a load pass.
    func storeLoadedProject(_ project: Project, sessionLimit: Int) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
        loadedSessionLimits[project.id] = sessionLimit
    }

    /// Drops projects whose folders were deleted or fell outside the loaded window.
    func trimLoadedProjects(to directories: [URL]) {
        let window = Set(directories.prefix(projectLoadTarget).map(\.lastPathComponent))
        projects.removeAll { !window.contains($0.id) }
        loadedSessionLimits = loadedSessionLimits.filter { window.contains($0.key) }
    }

    /// `count` plus `batch`, capped at `Int.max` (the limit for "All").
    private static func adding(_ batch: Int, to count: Int) -> Int {
        count > Int.max - batch ? .max : count + batch
    }

    private static var storedLoadBatchSize: LoadBatchSize {
        guard let raw = UserDefaults.standard.object(forKey: "loadBatchSize") as? Int,
              let size = LoadBatchSize(rawValue: raw)
        else { return .default }
        return size
    }

    // MARK: - Toast

    func showToast(
        _ message: String,
        icon: String? = nil,
        style: Toast.ToastStyle = .success,
        url: URL? = nil,
        animateIcon: Bool = false
    ) {
        let lines = message.components(separatedBy: "\n")
        var result = (try? AttributedString(markdown: lines[0])) ?? AttributedString(lines[0])
        for line in lines.dropFirst() {
            result.append(AttributedString("\n"))
            let parsed = (try? AttributedString(markdown: line)) ?? AttributedString(line)
            result.append(parsed)
        }
        let toast = Toast(message: result, icon: icon, style: style, url: url, animateIcon: animateIcon)
        withAnimation(.easeInOut(duration: 0.25)) {
            toastQueue.append(toast)
        }
    }

    func dismissCurrentToast() {
        guard !toastQueue.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            _ = toastQueue.removeFirst()
        }
    }

    init() {
        PoirotTheme.Typography.scale = fontScale
    }

    func increaseFontScale() {
        fontScale = min(fontScale + 0.05, 1.5)
    }

    func decreaseFontScale() {
        fontScale = max(fontScale - 0.05, 0.75)
    }

    func resetFontScale() {
        fontScale = 1.0
    }

    func deleteSession(_ session: Session) {
        // Remove the file
        if let url = session.fileURL {
            try? FileManager.default.removeItem(at: url)
        }

        // Clear selection if needed
        if selectedSession == session {
            selectedSession = nil
        }

        // Remove from cache
        sessionCache.removeValue(forKey: session.id)

        // Remove from projects
        var emptiedProjectHasOlderSessions = false
        projects = projects.compactMap { project in
            let remaining = project.sessions.filter { $0.id != session.id }
            if remaining.isEmpty {
                if !project.sessions.isEmpty, project.unloadedSessionCount > 0 {
                    emptiedProjectHasOlderSessions = true
                }
                return nil
            }
            if remaining.count == project.sessions.count { return project }
            return project.withSessions(remaining)
        }

        // The deleted session was the last one loaded; reload so the older ones take its place
        if emptiedProjectHasOlderSessions {
            refreshID = UUID()
        }
    }
}
