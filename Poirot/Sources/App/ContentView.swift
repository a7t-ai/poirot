import SwiftUI

struct ContentView: View {
    @Environment(AppState.self)
    private var appState
    @Environment(\.provider)
    private var provider
    @Environment(\.sessionLoader)
    private var sessionLoader

    @State
    private var sidebarVisibility: NavigationSplitViewVisibility = .automatic
    @State
    private var sessionLoadTask: Task<Void, Never>?
    @State
    private var fileWatcher: FileWatcher?
    @State
    private var debugFileWatcher: FileWatcher?
    @State
    private var facetsWatcher: FileWatcher?
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false
    @AppStorage("colorTheme")
    private var colorThemeRaw = ColorTheme.default.rawValue
    private var sidebarNavItems: [NavigationItem] {
        provider.navigationItems
    }

    var body: some View {
        splitView
            .sheet(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { if !$0 { hasCompletedOnboarding = true } }
            )) {
                OnboardingView()
                    .interactiveDismissDisabled()
            }
            .keyboardShortcut(for: .search) {
                appState.isSearchPresented.toggle()
            }
            .keyboardShortcut(for: "[") {
                appState.navigateBack()
            }
            .keyboardShortcut(for: "]") {
                appState.navigateForward()
            }
            .keyboardShortcut(for: "t") {
                if appState.selectedSession != nil {
                    appState.isToolFilterActive.toggle()
                    if !appState.isToolFilterActive {
                        appState.activeToolFilters.removeAll()
                    }
                }
            }
            .onChange(of: appState.selectedSession) { _, newSession in
                handleSessionChange(newSession)
            }
            .onChange(of: colorThemeRaw) {
                if let theme = ColorTheme(rawValue: colorThemeRaw) {
                    ColorThemeStorage.current = theme
                }
            }
            .keyboardNavigation(
                sidebarItemCount: sidebarNavItems.count,
                onSidebarActivate: { activateSidebarItem() }
            )
            .sheet(isPresented: Binding(
                get: { appState.isShortcutHelpPresented },
                set: { appState.isShortcutHelpPresented = $0 }
            )) {
                ShortcutHelpView()
            }
    }

    private func activateSidebarItem() {
        let items = sidebarNavItems
        let index = appState.sidebarKeyboardIndex
        guard index >= 0, index < items.count else { return }
        appState.selectedNav = items[index]
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } detail: {
            detailView
                .animation(.easeOut(duration: 0.35), value: appState.isLoadingSession)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .toolbar {
            toolbarNavigation
        }
        .toolbar {
            toolbarContextual
        }
        .frame(minWidth: 900, minHeight: 600)
        .id("\(appState.fontScale)-\(colorThemeRaw)")
        .overlay(alignment: .top) {
            ToastOverlay()
        }
        .overlay {
            if appState.isSearchPresented {
                SearchOverlayView()
            }
        }
        .task(id: appState.refreshID) {
            await loadProjectsInBatches()
        }
        .onAppear {
            guard fileWatcher == nil else { return }
            let watcher = FileWatcher { [weak appState] in
                appState?.refreshID = UUID()
            }
            watcher.start(path: sessionLoader.claudeProjectsPath)
            fileWatcher = watcher

            // Watch facets directory for live updates
            if facetsWatcher == nil {
                let fWatcher = FileWatcher { [weak appState] in
                    appState?.refreshID = UUID()
                }
                let facetsPath = FacetsLoader().claudeFacetsPath
                // Ensure directory exists before watching
                let fm = FileManager.default
                if fm.fileExists(atPath: facetsPath) {
                    fWatcher.start(path: facetsPath)
                    facetsWatcher = fWatcher
                }
            }
        }
        .onDisappear {
            fileWatcher?.stop()
            fileWatcher = nil
            debugFileWatcher?.stop()
            debugFileWatcher = nil
            facetsWatcher?.stop()
            facetsWatcher = nil
        }
        .sheet(item: Binding(
            get: { appState.showDebugLogSessionId.map(DebugLogSheetId.init) },
            set: { appState.showDebugLogSessionId = $0?.sessionId }
        )) { item in
            DebugLogView(sessionId: item.sessionId)
        }
        .onAppear {
            startDebugFileWatcher()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            fileWatcher?.stop()
            fileWatcher = nil
            debugFileWatcher?.stop()
            debugFileWatcher = nil
            facetsWatcher?.stop()
            facetsWatcher = nil
        }
    }

    private func handleSessionChange(_ newSession: Session?) {
        appState.isSessionSearchActive = false
        appState.sessionSearchQuery = ""
        appState.isToolFilterActive = false
        appState.activeToolFilters.removeAll()

        sessionLoadTask?.cancel()
        sessionLoadTask = nil

        guard let session = newSession,
              session.messages.isEmpty,
              let url = session.fileURL
        else {
            appState.isLoadingSession = false
            return
        }

        if let cached = appState.cachedSession(for: session.id) {
            appState.selectedSession = cached
            appState.isLoadingSession = false
            return
        }

        appState.isLoadingSession = true
        let projectPath = session.projectPath
        let sessionId = session.id
        let startedAt = session.startedAt
        sessionLoadTask = Task {
            defer {
                if appState.selectedSession?.id == sessionId {
                    appState.isLoadingSession = false
                }
            }

            let isSidechain = appState.selectedSession?.isSidechain ?? false
            let full = await Task.detached {
                TranscriptParser().parse(
                    fileURL: url,
                    projectPath: projectPath,
                    sessionId: sessionId,
                    indexStartedAt: startedAt,
                    isSidechain: isSidechain
                )
            }.value

            guard !Task.isCancelled else { return }
            guard appState.selectedSession?.id == sessionId else { return }

            if let full {
                appState.cacheSession(full)
                appState.selectedSession = full
            }
        }
    }

    // MARK: - Toolbar

    private enum ToolbarMode {
        case session(Session)
        case configDetail
        case none
    }

    private var toolbarMode: ToolbarMode {
        if appState.selectedNav.id == NavigationItem.sessions.id {
            if let session = appState.selectedSession, !session.messages.isEmpty {
                return .session(session)
            }
        } else {
            if appState.activeConfigDetail != nil {
                return .configDetail
            }
        }
        return .none
    }

    @ToolbarContentBuilder
    private var toolbarNavigation: some ToolbarContent { // swiftlint:disable:this attributes
        ToolbarItemGroup(placement: .navigation) {
            Button { appState.navigateBack() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!appState.canNavigateBack)
            .help("Back (⌘[)")

            Button { appState.navigateForward() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!appState.canNavigateForward)
            .help("Forward (⌘])")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContextual: some ToolbarContent { // swiftlint:disable:this attributes
        switch toolbarMode {
        case let .session(session):
            SessionToolbar(session: session)
        case .configDetail:
            ToolbarItemGroup(placement: .principal) {
                Spacer()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                ConfigToolbarActions()
                ConfigToolbarDelete()
                ConfigToolbarClose()
            }
        case .none:
            ToolbarItem(placement: .automatic) { EmptyView() }
        }
    }

    // MARK: - Batch Loading

    private func loadProjectsInBatches() async {
        let isInitialLoad = appState.projects.isEmpty
        if isInitialLoad {
            appState.isLoadingProjects = true
        }
        appState.isLoadingMoreProjects = true

        do {
            // Phase 1: fast directory scan off main thread
            let directories = try await Task.detached {
                try SessionLoader.projectDirectoryURLs(
                    at: SessionLoader().claudeProjectsPath
                )
            }.value

            // Phase 2: build projects in batches, yielding to UI between each
            let batchSize = 5
            var loadedIds = Set(appState.projects.map(\.id))

            for batchStart in stride(from: 0, to: directories.count, by: batchSize) {
                guard !Task.isCancelled else { return }

                let batchEnd = min(batchStart + batchSize, directories.count)
                let batch = Array(directories[batchStart ..< batchEnd])

                let projects = await Task.detached {
                    batch.compactMap { SessionLoader.loadProject(at: $0) }
                }.value

                guard !Task.isCancelled else { return }

                var newProjects: [Project] = []
                var updatedProjects: [(index: Int, project: Project)] = []

                for project in projects {
                    if loadedIds.contains(project.id) {
                        if let idx = appState.projects.firstIndex(where: { $0.id == project.id }) {
                            updatedProjects.append((idx, project))
                        }
                    } else {
                        newProjects.append(project)
                        loadedIds.insert(project.id)
                    }
                }

                withAnimation(.easeInOut(duration: 0.3)) {
                    for update in updatedProjects {
                        appState.projects[update.index] = update.project
                    }
                    appState.projects.append(contentsOf: newProjects)
                    if isInitialLoad, appState.isLoadingProjects {
                        appState.isLoadingProjects = false
                    }
                }

                if batchEnd < directories.count {
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }

            guard !Task.isCancelled else { return }

            // Remove projects whose directories no longer exist
            let directoryNames = Set(directories.map(\.lastPathComponent))
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.projects.removeAll { !directoryNames.contains($0.id) }
            }
        } catch {
            print("Failed to load projects: \(error)")
        }

        if appState.isLoadingProjects {
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.isLoadingProjects = false
            }
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            appState.isLoadingMoreProjects = false
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedNav.id {
        case NavigationItem.sessions.id:
            SessionsNavigationView()
        case NavigationItem.todos.id:
            TodosOverviewView()
                .transition(.opacity)
        case NavigationItem.history.id:
            HistoryListView()
                .transition(.opacity)
        case NavigationItem.analytics.id:
            AnalyticsDashboardView()
        default:
            if let configItem = provider.configurationItems
                .first(where: { $0.id == appState.selectedNav.id }) {
                configDetailView(for: configItem)
            } else {
                Text(appState.selectedNav.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func configDetailView(for item: ConfigurationItem) -> some View {
        switch item.id {
        case NavigationItem.commands.id:
            CommandsListView(item: item)
        case NavigationItem.skills.id:
            SkillsListView(item: item)
        case NavigationItem.plans.id:
            PlansListView(item: item)
        case NavigationItem.mcpServers.id:
            MCPServersListView(item: item)
        case NavigationItem.models.id:
            ModelsListView(item: item)
        case NavigationItem.subAgents.id:
            SubAgentsListView(item: item)
        case NavigationItem.memory.id:
            MemoryListView(item: item)
        case NavigationItem.hooks.id:
            HooksListView(item: item)
        case NavigationItem.plugins.id:
            PluginsListView(item: item)
        case NavigationItem.outputStyles.id:
            OutputStylesListView(item: item)
        default:
            ConfigScreenHeader(item: item)
        }
    }
}

// MARK: - Debug File Watcher

extension ContentView {
    func startDebugFileWatcher() {
        guard debugFileWatcher == nil else { return }
        let debugPath = DebugLogLoader().claudeDebugPath
        let fm = FileManager.default
        // Create the directory if it doesn't exist so the watcher can attach
        if !fm.fileExists(atPath: debugPath) {
            try? fm.createDirectory(
                atPath: debugPath,
                withIntermediateDirectories: true
            )
        }
        let watcher = FileWatcher { [weak appState] in
            appState?.refreshID = UUID()
        }
        watcher.start(path: debugPath)
        debugFileWatcher = watcher
    }
}

// MARK: - Debug Log Sheet ID

private struct DebugLogSheetId: Identifiable {
    let sessionId: String
    var id: String { sessionId }
}

// MARK: - Keyboard Shortcut Helper

private extension View {
    func keyboardShortcut(for shortcut: KeyEquivalent, action: @escaping () -> Void) -> some View {
        background {
            Button("") { action() }
                .keyboardShortcut(shortcut, modifiers: .command)
                .hidden()
        }
    }

    func keyboardShortcut(for shortcut: SearchShortcut, action: @escaping () -> Void) -> some View {
        background {
            Button("") { action() }
                .keyboardShortcut(shortcut.key, modifiers: .command)
                .hidden()
        }
    }
}

private enum SearchShortcut {
    case search

    var key: KeyEquivalent {
        switch self {
        case .search: "k"
        }
    }
}
