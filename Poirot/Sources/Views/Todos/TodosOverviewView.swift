import SwiftUI

struct TodosOverviewView: View {
    @Environment(AppState.self)
    private var appState

    @Environment(\.sessionLoader)
    private var sessionLoader

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State
    private var sessionEntries: [TodoSessionEntry] = []

    @State
    private var isLoaded = false

    @State
    private var isRevealed = false

    @State
    private var filterQuery = ""

    @State
    private var fileWatcher: FileWatcher?

    /// Session ID currently being loaded on-demand from disk, or `nil`.
    @State
    private var loadingSessionId: String?

    /// Session ID for the "not found" alert, or `nil`.
    @State
    private var notFoundSessionId: String?

    private static let pageSize = 20
    private static let screenID = NavigationItem.todos.id

    @State
    private var visibleCount: Int = TodosOverviewView.pageSize

    private var totalCount: Int {
        sessionEntries.reduce(0) { $0 + $1.todos.count }
    }

    private var filteredEntries: [TodoSessionEntry] {
        let q = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return sessionEntries }
        return sessionEntries
            .compactMap { entry -> (TodoSessionEntry, Int)? in
                let titleScore = sessionTitle(for: entry.sessionId).flatMap {
                    HighlightedText.fuzzyMatch($0, query: q)?.score
                } ?? 0
                let todoScore = entry.todos
                    .compactMap { HighlightedText.fuzzyMatch($0.content, query: q)?.score }
                    .max() ?? 0
                let best = max(titleScore, todoScore)
                return best > 0 ? (entry, best) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !isLoaded {
                ConfigSkeletonView(layout: appState.configLayout(for: Self.screenID))
            } else if sessionEntries.isEmpty {
                ConfigEmptyState(
                    icon: "checklist",
                    message: "No TODOs found",
                    hint: "TODOs from Claude Code sessions will appear here"
                )
            } else if filteredEntries.isEmpty {
                ConfigEmptyState(
                    icon: "magnifyingglass",
                    message: "No TODOs match \"\(filterQuery)\"",
                    hint: "Try a different search term"
                )
            } else {
                todoContent
            }
        }
        .background(PoirotTheme.Colors.bgApp)
        .toolbar {
            ConfigLayoutToolbar(
                screenID: Self.screenID,
                filterQuery: $filterQuery,
                placeholder: "Find in TODOs\u{2026}"
            )
        }
        .task {
            await loadTodos()
        }
        .alert(
            "Session not found",
            isPresented: Binding(
                get: { notFoundSessionId != nil },
                set: { if !$0 { notFoundSessionId = nil } }
            )
        ) {
            Button("Delete TODOs", role: .destructive) {
                if let sessionId = notFoundSessionId {
                    deleteTodoEntry(for: sessionId)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The session transcript could not be found on disk. Would you like to delete these TODOs?")
        }
        .onAppear {
            guard fileWatcher == nil else { return }
            let todosPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/todos").path
            let watcher = FileWatcher {
                Task {
                    await loadTodos()
                }
            }
            watcher.start(path: todosPath)
            fileWatcher = watcher
        }
        .onDisappear {
            fileWatcher?.stop()
            fileWatcher = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        let countText =
            "\(totalCount) \(totalCount == 1 ? "todo" : "todos") · \(sessionEntries.count) \(sessionEntries.count == 1 ? "session" : "sessions")"

        return VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.md) {
                Image(systemName: "checklist")
                    .font(PoirotTheme.Typography.headingSmall)
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                            .fill(PoirotTheme.Colors.accent.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                    Text("TODOs")
                        .font(PoirotTheme.Typography.heading)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)

                    Text(countText)
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

            Text("TODOs tracked across your Claude Code sessions")
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

    // MARK: - Content

    @ViewBuilder
    private var todoContent: some View {
        if appState.configLayout(for: Self.screenID) == .grid {
            todoGrid
        } else {
            todoList
        }
    }

    private var todoGrid: some View {
        ScrollView {
            let visible = Array(filteredEntries.prefix(visibleCount).enumerated())
            let columns = balancedColumns(from: visible)

            HStack(alignment: .top, spacing: PoirotTheme.Spacing.lg) {
                ForEach(0 ..< 2, id: \.self) { column in
                    LazyVStack(spacing: PoirotTheme.Spacing.lg) {
                        ForEach(columns[column], id: \.element.id) { index, entry in
                            todoCard(entry: entry, index: index)
                                .shimmerReveal(
                                    isRevealed: isRevealed,
                                    delay: Double(min(index, 7)) * 0.04,
                                    cornerRadius: PoirotTheme.Radius.md
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.xxxl)
            .padding(.top, PoirotTheme.Spacing.lg)
            .padding(.bottom, PoirotTheme.Spacing.xxl)
        }
        .scrollIndicators(.never)
    }

    /// Distributes entries across two columns, balancing by estimated card height.
    private func balancedColumns(
        from visible: [(offset: Int, element: TodoSessionEntry)]
    ) -> [[(offset: Int, element: TodoSessionEntry)]] {
        var columns: [[(offset: Int, element: TodoSessionEntry)]] = [[], []]
        var heights: [Int] = [0, 0]

        for item in visible {
            // Estimate: header ≈ 2 rows + 1 row per todo
            let weight = 2 + item.element.todos.count
            let shorter = heights[0] <= heights[1] ? 0 : 1
            columns[shorter].append(item)
            heights[shorter] += weight
        }

        return columns
    }

    private var todoList: some View {
        ScrollView {
            let visible = Array(filteredEntries.prefix(visibleCount).enumerated())

            LazyVStack(spacing: PoirotTheme.Spacing.md) {
                ForEach(visible, id: \.element.id) { index, entry in
                    todoCard(entry: entry, index: index)
                        .shimmerReveal(
                            isRevealed: isRevealed,
                            delay: Double(min(index, 9)) * 0.03,
                            cornerRadius: PoirotTheme.Radius.md
                        )
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.xxxl)
            .padding(.top, PoirotTheme.Spacing.lg)
            .padding(.bottom, PoirotTheme.Spacing.xxl)
        }
        .scrollIndicators(.never)
    }

    private func todoCard(entry: TodoSessionEntry, index: Int) -> some View {
        SessionTodoCard(
            sessionId: entry.sessionId,
            sessionTitle: sessionTitle(for: entry.sessionId),
            todos: entry.todos,
            filterQuery: filterQuery,
            isLoadingSession: loadingSessionId == entry.sessionId,
            isGoToDisabled: loadingSessionId != nil,
            onGoToSession: { navigateToSession(entry.sessionId) }
        )
        .onAppear {
            loadMoreIfNeeded(at: index)
        }
    }

    private func loadMoreIfNeeded(at index: Int) {
        guard index >= visibleCount - 3,
              visibleCount < filteredEntries.count
        else { return }
        visibleCount += Self.pageSize
    }

    // MARK: - Loading

    private func loadTodos() async {
        let allTodos = await Task.detached {
            TodoLoader().loadAllTodos()
        }.value

        // Filter out sessions with no todos, sort active sessions first
        let filtered = allTodos.filter { !$0.value.isEmpty }
        let sorted = filtered.sorted { lhs, rhs in
            let lhsActive = lhs.value.contains { $0.status != .completed }
            let rhsActive = rhs.value.contains { $0.status != .completed }
            if lhsActive != rhsActive { return lhsActive }
            return lhs.key < rhs.key
        }

        sessionEntries = sorted.map { TodoSessionEntry(sessionId: $0.key, todos: $0.value) }
        syncSidebarCount()

        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(.easeOut(duration: 0.35)) {
            isLoaded = true
        }

        isRevealed = false
        try? await Task.sleep(for: .milliseconds(50))
        withAnimation(.easeOut(duration: 0.4)) {
            isRevealed = true
        }
    }

    // MARK: - Navigation

    private func findSessionInMemory(_ sessionId: String) -> (project: Project, session: Session)? {
        for project in appState.projects {
            if let session = project.sessions.first(where: { $0.id == sessionId }) {
                return (project, session)
            }
        }
        return nil
    }

    private func navigateToSession(_ sessionId: String) {
        if let match = findSessionInMemory(sessionId) {
            appState.selectedNav = .sessions
            appState.selectedProject = match.project.id
            appState.selectedSession = match.session
        } else {
            loadingSessionId = sessionId
            let projectsPath = sessionLoader.claudeProjectsPath
            Task {
                let result = await Task.detached {
                    Self.findSessionOnDisk(sessionId: sessionId, projectsPath: projectsPath)
                }.value

                if let result {
                    appState.selectedNav = .sessions
                    appState.selectedProject = result.projectId
                    appState.selectedSession = result.session
                } else {
                    notFoundSessionId = sessionId
                }
                loadingSessionId = nil
            }
        }
    }

    nonisolated private static func findSessionOnDisk(
        sessionId: String,
        projectsPath: String
    ) -> (projectId: String, session: Session)? {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: projectsPath),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let parser = TranscriptParser()
        for dir in dirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            let fileURL = dir.appendingPathComponent("\(sessionId).jsonl")
            guard fm.fileExists(atPath: fileURL.path) else { continue }

            let dirName = dir.lastPathComponent
            let projectPath: String
            let indexURL = dir.appendingPathComponent("sessions-index.json")
            if let data = try? Data(contentsOf: indexURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let original = json["originalPath"] as? String {
                projectPath = original
            } else {
                projectPath = "/" + dirName.replacingOccurrences(of: "-", with: "/")
            }

            if let session = parser.parseSummary(
                fileURL: fileURL,
                projectPath: projectPath,
                sessionId: sessionId,
                indexStartedAt: nil
            ) {
                return (dirName, session)
            }
        }
        return nil
    }

    // MARK: - Deletion

    private func deleteTodoEntry(for sessionId: String) {
        TodoLoader().deleteTodos(for: sessionId)
        withAnimation(.easeOut(duration: 0.25)) {
            sessionEntries.removeAll { $0.sessionId == sessionId }
        }
        syncSidebarCount()
    }

    private func syncSidebarCount() {
        appState.sidebarCounts[NavigationItem.todos.id] = totalCount
    }

    // MARK: - Helpers

    private func sessionTitle(for sessionId: String) -> String? {
        findSessionInMemory(sessionId)?.session.title
    }
}

// MARK: - Entry Model

private struct TodoSessionEntry: Identifiable {
    let sessionId: String
    let todos: [SessionTodo]
    var id: String { sessionId }
}

// MARK: - Session Todo Card

private struct SessionTodoCard: View {
    let sessionId: String
    let sessionTitle: String?
    let todos: [SessionTodo]
    var filterQuery: String = ""
    let isLoadingSession: Bool
    let isGoToDisabled: Bool
    let onGoToSession: () -> Void

    @State
    private var isExpanded = true

    @State
    private var isHovered = false

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var completedCount: Int { todos.filter { $0.status == .completed }.count }
    private var inProgressCount: Int { todos.filter { $0.status == .inProgress }.count }
    private var pendingCount: Int { todos.filter { $0.status == .pending }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            groupHeader

            if isExpanded {
                Divider().opacity(0.3)

                ForEach(Array(todos.enumerated()), id: \.element.id) { index, todo in
                    todoRow(todo)

                    if index < todos.count - 1 {
                        Divider()
                            .opacity(0.15)
                            .padding(.leading, PoirotTheme.Spacing.xxxl)
                    }
                }
            }
        }
        .cardChrome(isHovered: isHovered)
        .clipShape(RoundedRectangle(cornerRadius: PoirotTheme.Radius.md))
        .onHover { isHovered = $0 }
    }

    private var groupHeader: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: PoirotTheme.Spacing.sm) {
                Image(systemName: "rectangle.stack")
                    .font(PoirotTheme.Typography.small)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(PoirotTheme.Colors.accent)

                Text(HighlightedText.fuzzyAttributedString(sessionTitle ?? sessionId, query: filterQuery))
                    .font(PoirotTheme.Typography.bodyMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .lineLimit(3)

                statusSummary

                Spacer()

                goToSessionButton

                Text("\(todos.count)")
                    .font(PoirotTheme.Typography.microSemibold)
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .padding(.horizontal, PoirotTheme.Spacing.sm)
                    .padding(.vertical, PoirotTheme.Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                            .fill(PoirotTheme.Colors.accentDim)
                    )

                expandChevron
            }

            if sessionTitle != nil {
                Text(sessionId)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, PoirotTheme.Spacing.lg)
        .padding(.vertical, PoirotTheme.Spacing.md)
    }

    private var expandChevron: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: "chevron.right")
                .font(PoirotTheme.Typography.nanoSemibold)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isExpanded ? "Collapse todos" : "Expand todos")
    }

    private var goToSessionButton: some View {
        Button {
            onGoToSession()
        } label: {
            Group {
                if isLoadingSession {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.right.circle")
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(
                            isGoToDisabled
                                ? PoirotTheme.Colors.textTertiary.opacity(0.3)
                                : PoirotTheme.Colors.textTertiary
                        )
                }
            }
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isGoToDisabled)
        .help("Go to session")
    }

    private var statusSummary: some View {
        HStack(spacing: PoirotTheme.Spacing.xs) {
            if completedCount > 0 {
                statusPill(count: completedCount, color: PoirotTheme.Colors.green)
            }
            if inProgressCount > 0 {
                statusPill(count: inProgressCount, color: PoirotTheme.Colors.accent)
            }
            if pendingCount > 0 {
                statusPill(count: pendingCount, color: PoirotTheme.Colors.textTertiary)
            }
        }
    }

    private func statusPill(count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(PoirotTheme.Typography.micro)
            .foregroundStyle(color)
            .padding(.horizontal, PoirotTheme.Spacing.xs)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                    .fill(color.opacity(0.1))
            )
    }

    private func todoRow(_ todo: SessionTodo) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PoirotTheme.Spacing.md) {
            statusIcon(for: todo.status)

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                Text(HighlightedText.fuzzyAttributedString(todo.content, query: filterQuery))
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(
                        todo.status == .completed
                            ? PoirotTheme.Colors.textTertiary
                            : PoirotTheme.Colors.textPrimary
                    )
                    .strikethrough(todo.status == .completed, color: PoirotTheme.Colors.textTertiary)

                if todo.status == .inProgress {
                    Text(todo.activeForm)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.accent)
                }
            }

            Spacer()
        }
        .padding(.horizontal, PoirotTheme.Spacing.lg)
        .padding(.vertical, PoirotTheme.Spacing.sm)
    }

    private func statusIcon(for status: SessionTodo.Status) -> some View {
        Group {
            switch status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(PoirotTheme.Colors.green)
                    .symbolEffect(.bounce, value: status)
            case .inProgress:
                Image(systemName: "circle.dotted")
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .symbolEffect(.breathe, isActive: !reduceMotion)
            case .pending:
                Image(systemName: "circle")
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
        .font(PoirotTheme.Typography.caption)
    }
}
