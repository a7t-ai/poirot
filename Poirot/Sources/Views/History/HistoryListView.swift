import SwiftUI

struct HistoryListView: View {
    @Environment(AppState.self)
    private var appState

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @Environment(\.historyLoader)
    private var historyLoader

    @State
    private var entries: [HistoryEntry] = []

    @State
    private var isLoaded = false

    @State
    private var isRevealed = false

    @State
    private var filterQuery = ""

    @State
    private var selectedProject: String?

    @State
    private var fileWatcher: FileWatcher?

    @State
    private var clearOlderThanDays: Int?

    private static let screenID = NavigationItem.history.id
    private static let pageSize = 30

    @State
    private var visibleCount: Int = HistoryListView.pageSize

    // MARK: - Computed

    private var allProjects: [String] {
        var seen = Set<String>()
        var projects: [String] = []
        for entry in entries where seen.insert(entry.project).inserted {
            projects.append(entry.project)
        }
        return projects
    }

    private var filteredEntries: [HistoryEntry] {
        var result = entries

        // Filter by project
        if let project = selectedProject {
            result = result.filter { $0.project == project }
        }

        // Filter by search query
        let q = filterQuery.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            result = result
                .compactMap { entry -> (HistoryEntry, Int)? in
                    let displayScore = HighlightedText.fuzzyMatch(entry.display, query: q)?.score ?? 0
                    let projectScore = HighlightedText.fuzzyMatch(entry.projectName, query: q)?.score ?? 0
                    let best = max(displayScore, projectScore)
                    return best > 0 ? (entry, best) : nil
                }
                .sorted { $0.1 > $1.1 }
                .map(\.0)
        }

        return result
    }

    private var groupedEntries: [(group: HistoryDateGroup, entries: [HistoryEntry])] {
        let visible = Array(filteredEntries.prefix(visibleCount))
        let grouped = Dictionary(grouping: visible) { HistoryDateGroup.group(for: $0.timestamp) }

        return HistoryDateGroup.allCases.compactMap { group in
            guard let items = grouped[group], !items.isEmpty else { return nil }
            return (group: group, entries: items)
        }
    }

    private var countText: String {
        let total = entries.count
        let filtered = filteredEntries.count
        if selectedProject != nil || !filterQuery.isEmpty {
            return "\(filtered) of \(total) \(total == 1 ? "prompt" : "prompts")"
        }
        return "\(total) \(total == 1 ? "prompt" : "prompts")"
    }

    // MARK: - Body

    var body: some View {
        listContent
    }

    // MARK: - List Content

    private var listContent: some View {
        VStack(spacing: 0) {
            header

            if !isLoaded {
                ConfigSkeletonView(layout: appState.configLayout(for: Self.screenID))
            } else if entries.isEmpty {
                ConfigEmptyState(
                    icon: "clock.arrow.circlepath",
                    message: "No history found",
                    hint: "~/.claude/history.jsonl"
                )
            } else if filteredEntries.isEmpty {
                ConfigEmptyState(
                    icon: "magnifyingglass",
                    message: "No prompts match your search",
                    hint: "Try a different search term or project"
                )
            } else {
                historyContent
            }
        }
        .background(PoirotTheme.Colors.bgApp)
        .toolbar {
            HistoryToolbarContent(
                screenID: Self.screenID,
                filterQuery: $filterQuery,
                selectedProject: $selectedProject,
                allProjects: allProjects,
                clearOlderThanDays: $clearOlderThanDays,
                hasEntries: !entries.isEmpty
            )
        }
        .task {
            await loadHistory()
        }
        .onAppear {
            guard fileWatcher == nil else { return }
            let historyPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/history.jsonl").path
            let watcher = FileWatcher {
                Task {
                    await loadHistory()
                }
            }
            watcher.start(path: historyPath)
            fileWatcher = watcher
        }
        .onDisappear {
            fileWatcher?.stop()
            fileWatcher = nil
        }
        .confirmationDialog(
            clearConfirmationTitle,
            isPresented: Binding(
                get: { clearOlderThanDays != nil },
                set: { if !$0 { clearOlderThanDays = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let days = clearOlderThanDays {
                    clearHistory(olderThanDays: days)
                }
                clearOlderThanDays = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.md) {
                Image(systemName: NavigationItem.history.systemImage)
                    .font(PoirotTheme.Typography.headingSmall)
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                            .fill(PoirotTheme.Colors.accent.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                    Text("History")
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

            Text("Your Claude Code prompt history across all projects")
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
    private var historyContent: some View {
        if appState.configLayout(for: Self.screenID) == .grid {
            historyGrid
        } else {
            historyList
        }
    }

    private var historyGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PoirotTheme.Spacing.lg) {
                ForEach(groupedEntries, id: \.group) { group, groupEntries in
                    dateGroupHeader(group)

                    let enumerated = Array(groupEntries.enumerated())
                    let columns = balancedColumns(from: enumerated)

                    HStack(alignment: .top, spacing: PoirotTheme.Spacing.lg) {
                        ForEach(0 ..< 2, id: \.self) { column in
                            LazyVStack(spacing: PoirotTheme.Spacing.md) {
                                ForEach(columns[column], id: \.element.id) { index, entry in
                                    HistoryCard(
                                        entry: entry,
                                        filterQuery: filterQuery,
                                        onCopy: { copyPrompt(entry) },
                                        onDelete: { deleteEntry(entry) }
                                    )
                                    .shimmerReveal(
                                        isRevealed: isRevealed,
                                        delay: Double(min(index, 7)) * 0.04,
                                        cornerRadius: PoirotTheme.Radius.md
                                    )
                                    .onAppear {
                                        loadMoreIfNeeded(entry: entry)
                                    }
                                }
                            }
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

    private var historyList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
                ForEach(groupedEntries, id: \.group) { group, groupEntries in
                    dateGroupHeader(group)

                    ForEach(Array(groupEntries.enumerated()), id: \.element.id) { index, entry in
                        HistoryCard(
                            entry: entry,
                            filterQuery: filterQuery,
                            onCopy: { copyPrompt(entry) },
                            onDelete: { deleteEntry(entry) }
                        )
                        .shimmerReveal(
                            isRevealed: isRevealed,
                            delay: Double(min(index, 9)) * 0.03,
                            cornerRadius: PoirotTheme.Radius.md
                        )
                        .onAppear {
                            loadMoreIfNeeded(entry: entry)
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

    private func dateGroupHeader(_ group: HistoryDateGroup) -> some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Text(group.title.uppercased())
                .font(PoirotTheme.Typography.sectionHeader)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .tracking(0.5)

            Rectangle()
                .fill(PoirotTheme.Colors.border)
                .frame(height: 1)
        }
        .padding(.top, PoirotTheme.Spacing.md)
        .padding(.bottom, PoirotTheme.Spacing.xs)
    }

    // MARK: - Helpers

    private func balancedColumns(
        from items: [(offset: Int, element: HistoryEntry)]
    ) -> [[(offset: Int, element: HistoryEntry)]] {
        var columns: [[(offset: Int, element: HistoryEntry)]] = [[], []]
        var heights: [Int] = [0, 0]

        for item in items {
            let lineCount = item.element.display.components(separatedBy: .newlines).count
            let weight = max(2, min(lineCount, 5))
            let shorter = heights[0] <= heights[1] ? 0 : 1
            columns[shorter].append(item)
            heights[shorter] += weight
        }

        return columns
    }

    private func copyPrompt(_ entry: HistoryEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.display, forType: .string)
        appState.showToast("Copied prompt to clipboard")
    }

    private func deleteEntry(_ entry: HistoryEntry) {
        historyLoader.delete(entry: entry)
        withAnimation(.easeInOut(duration: 0.25)) {
            entries.removeAll { $0.id == entry.id }
        }
        syncSidebarCount()
        appState.showToast("Prompt deleted", icon: "trash")
    }

    private func loadMoreIfNeeded(entry: HistoryEntry) {
        let allFiltered = filteredEntries
        guard let index = allFiltered.firstIndex(of: entry) else { return }
        guard index >= visibleCount - 5,
              visibleCount < allFiltered.count
        else { return }
        visibleCount += Self.pageSize
    }

    private func loadHistory() async {
        let loader = historyLoader
        let result = await Task.detached {
            loader.loadAll()
        }.value

        entries = result
        syncSidebarCount()

        if !isLoaded {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.35)) {
                isLoaded = true
            }
        }

        isRevealed = false
        try? await Task.sleep(for: .milliseconds(50))
        withAnimation(.easeOut(duration: 0.4)) {
            isRevealed = true
        }
    }

    private var clearConfirmationTitle: String {
        guard let days = clearOlderThanDays else { return "Delete old prompts?" }
        let label = Self.clearOptionLabel(for: days)
        return "Delete prompts older than \(label)?"
    }

    private static func clearOptionLabel(for days: Int) -> String {
        switch days {
        case 14: "2 weeks"
        case 30: "1 month"
        case 90: "3 months"
        case 180: "6 months"
        default: "\(days) days"
        }
    }

    private func clearHistory(olderThanDays days: Int) {
        let removed = historyLoader.deleteOlderThan(days: days)
        guard removed > 0 else {
            appState.showToast("No prompts older than \(Self.clearOptionLabel(for: days))")
            return
        }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        withAnimation(.easeInOut(duration: 0.25)) {
            entries.removeAll { $0.timestamp < cutoff }
        }
        syncSidebarCount()
        let label = Self.clearOptionLabel(for: days)
        appState.showToast(
            "Deleted \(removed) \(removed == 1 ? "prompt" : "prompts") older than \(label)",
            icon: "trash"
        )
    }

    private func syncSidebarCount() {
        appState.sidebarCounts[NavigationItem.history.id] = entries.count
    }
}

// MARK: - History Card

private struct HistoryCard: View {
    let entry: HistoryEntry
    var filterQuery: String = ""
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State
    private var isHovered = false

    @State
    private var copyTapped = false

    @State
    private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: PoirotTheme.Spacing.sm) {
                Text(HighlightedText.fuzzyAttributedString(entry.snippet, query: filterQuery))
                    .font(PoirotTheme.Typography.bodyMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Spacer()

                Button {
                    onCopy()
                    copyTapped = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copyTapped = false }
                } label: {
                    Image(systemName: copyTapped ? "checkmark" : "doc.on.doc")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help("Copy Prompt")

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Delete Prompt")
            }

            HStack(spacing: PoirotTheme.Spacing.sm) {
                Label {
                    Text(HighlightedText.fuzzyAttributedString(entry.projectName, query: filterQuery))
                } icon: {
                    Image(systemName: "shippingbox")
                }
                .font(PoirotTheme.Typography.code)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .lineLimit(1)
                .padding(.horizontal, PoirotTheme.Spacing.sm)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                )

                Spacer()

                Text(entry.timeAgo)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PoirotTheme.Spacing.lg)
        .cardChrome(isHovered: isHovered)
        .onHover { isHovered = $0 }
        .confirmationDialog(
            "Delete this prompt?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - History Toolbar

private struct HistoryToolbarContent: ToolbarContent {
    let screenID: String
    @Binding
    var filterQuery: String
    @Binding
    var selectedProject: String?
    let allProjects: [String]
    @Binding
    var clearOlderThanDays: Int?
    let hasEntries: Bool

    @Environment(AppState.self)
    private var appState

    private static let clearOptions: [(label: String, days: Int)] = [
        ("Older than 2 weeks", 14),
        ("Older than 1 month", 30),
        ("Older than 3 months", 90),
        ("Older than 6 months", 180),
    ]

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            projectPicker
                .frame(width: 260)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            ConfigFilterField(searchQuery: $filterQuery, placeholder: "Search prompts\u{2026}")
                .frame(width: 200)

            clearMenu

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    appState.toggleConfigLayout(for: screenID)
                }
            } label: {
                Image(systemName: appState.configLayout(for: screenID) == .grid ? "list.bullet" : "square.grid.2x2")
                    .frame(width: 16, height: 16)
                    .contentTransition(.symbolEffect(.replace))
            }
            .help("Toggle layout")
        }
    }

    private var clearMenu: some View {
        Menu {
            Section("Clear History") {
                ForEach(Self.clearOptions, id: \.days) { option in
                    Button(option.label) {
                        clearOlderThanDays = option.days
                    }
                }
            }
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 24)
        .disabled(!hasEntries)
        .help("Clear old prompts")
    }

    private var projectPicker: some View {
        Menu {
            Button {
                selectedProject = nil
            } label: {
                if selectedProject == nil {
                    Label("All Projects", systemImage: "checkmark")
                } else {
                    Text("All Projects")
                }
            }

            Divider()

            ForEach(allProjects, id: \.self) { project in
                Button {
                    selectedProject = project
                } label: {
                    let name = (project as NSString).lastPathComponent
                    if selectedProject == project {
                        Label(name, systemImage: "checkmark")
                    } else {
                        Text(name)
                    }
                }
            }
        } label: {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(
                        selectedProject != nil
                            ? PoirotTheme.Colors.accent
                            : PoirotTheme.Colors.textTertiary
                    )

                Text(selectedProject.map { ($0 as NSString).lastPathComponent } ?? "All Projects")
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, PoirotTheme.Spacing.md)
            .padding(.vertical, PoirotTheme.Spacing.sm)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Filter by project")
    }
}
