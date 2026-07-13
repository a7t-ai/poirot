@preconcurrency import MarkdownUI
import SwiftUI

struct MemoryListView: View {
    let item: ConfigurationItem
    @State
    private var memoryFiles: [MemoryFile] = []
    @State
    private var projectsWithMemory: [(dirName: String, projectName: String, count: Int)] = []
    @State
    private var selectedProjectDir: String?
    @State
    private var isRevealed = false
    @State
    private var isLoaded = false
    @State
    private var selectedMemory: MemoryFile?
    @State
    private var filterQuery = ""
    @State
    private var fileWatchers: [FileWatcher] = []

    @Environment(AppState.self)
    private var appState

    private var filteredMemoryFiles: [MemoryFile] {
        let q = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return memoryFiles }
        return memoryFiles
            .compactMap { file -> (MemoryFile, Int)? in
                if let m = HighlightedText.fuzzyMatch(file.name, query: q) { return (file, m.score) }
                if file.content.localizedCaseInsensitiveContains(q) { return (file, 1) }
                return nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        Group {
            if let memory = selectedMemory {
                MemoryDetailView(memory: memory)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                listView
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .task(id: appState.activeConfigDetail?.filePath) {
            if memoryFiles.isEmpty { reloadMemoryFiles() }
            if let detail = appState.activeConfigDetail,
               selectedMemory?.fileURL.path != detail.filePath,
               let match = memoryFiles.first(where: { $0.fileURL.path == detail.filePath }) {
                selectedMemory = match
            }
        }
        .onChange(of: appState.activeConfigDetail) {
            if let detail = appState.activeConfigDetail {
                if selectedMemory?.fileURL.path != detail.filePath {
                    let match = memoryFiles.first(where: { $0.fileURL.path == detail.filePath })
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMemory = match
                    }
                }
            } else if selectedMemory != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedMemory = nil
                }
                reloadMemoryFiles()
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            ConfigScreenHeader(
                item: item,
                dynamicCount: memoryCountLabel
            )

            if !isLoaded {
                ConfigSkeletonView(
                    layout: appState.configLayout(for: item.id)
                )
            } else if projectsWithMemory.isEmpty {
                ConfigEmptyState(
                    icon: "brain.head.profile",
                    message: "No memory files found",
                    hint: "~/.claude/projects/<project>/memory/"
                )
            } else if memoryFiles.isEmpty, selectedProjectDir != nil {
                ConfigEmptyState(
                    icon: "brain.head.profile",
                    message: "No memory files in this project",
                    hint: "Select a different project"
                )
            } else if filteredMemoryFiles.isEmpty {
                ConfigEmptyState(
                    icon: "magnifyingglass",
                    message: "No memories match \"\(filterQuery)\"",
                    hint: "Try a different search term"
                )
            } else {
                configContent
            }
        }
        .background(PoirotTheme.Colors.bgApp)
        .toolbar {
            ConfigLayoutToolbar(
                screenID: item.id,
                filterQuery: $filterQuery,
                placeholder: "Find in Memory\u{2026}"
            )
        }
        .task {
            reloadProjects()
            reloadMemoryFiles()
            syncSidebarCount()
            startWatching()
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
        .onDisappear {
            for watcher in fileWatchers { watcher.stop() }
            fileWatchers.removeAll()
        }
    }

    // MARK: - Project Picker

    private var memoryCountLabel: String {
        let count = memoryFiles.count
        let fileWord = count == 1 ? "file" : "files"
        if let dir = selectedProjectDir,
           let proj = projectsWithMemory.first(where: { $0.dirName == dir }) {
            return "\(count) \(fileWord) in \(proj.projectName)"
        }
        return "\(count) \(fileWord)"
    }

    // MARK: - Content

    @ViewBuilder
    private var configContent: some View {
        VStack(spacing: 0) {
            memoryProjectBar
                .overlay(alignment: .bottom) {
                    Divider().opacity(0.3)
                }

            if appState.configLayout(for: item.id) == .grid {
                configGrid
            } else {
                configList
            }
        }
    }

    private var memoryProjectBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                ProjectChip(
                    name: "All Projects",
                    count: projectsWithMemory.reduce(0) { $0 + $1.count },
                    isSelected: selectedProjectDir == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProjectDir = nil
                    }
                    reloadMemoryFiles()
                }

                ForEach(projectsWithMemory, id: \.dirName) { project in
                    ProjectChip(
                        name: project.projectName,
                        count: project.count,
                        isSelected: selectedProjectDir == project.dirName
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProjectDir = project.dirName
                        }
                        reloadMemoryFiles()
                    }
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.xxxl)
            .padding(.vertical, PoirotTheme.Spacing.sm)
        }
    }

    private var configGrid: some View {
        ScrollView {
            HStack(alignment: .top, spacing: PoirotTheme.Spacing.lg) {
                ForEach(0 ..< 2, id: \.self) { column in
                    LazyVStack(spacing: PoirotTheme.Spacing.lg) {
                        ForEach(filesForColumn(column), id: \.element.id) { index, file in
                            MemoryCard(memory: file, filterQuery: filterQuery) {
                                selectMemory(file)
                            }
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

    private func filesForColumn(_ column: Int) -> [(offset: Int, element: MemoryFile)] {
        Array(filteredMemoryFiles.enumerated()).filter { $0.offset % 2 == column }
    }

    private var configList: some View {
        ScrollView {
            LazyVStack(spacing: PoirotTheme.Spacing.md) {
                ForEach(Array(filteredMemoryFiles.enumerated()), id: \.element.id) { index, file in
                    MemoryCard(memory: file, filterQuery: filterQuery) {
                        selectMemory(file)
                    }
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

    // MARK: - Actions

    private func selectMemory(_ memory: MemoryFile) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedMemory = memory
        }
        let detail = ConfigDetailInfo(
            name: memory.name,
            markdownContent: memory.content,
            filePath: memory.fileURL.path,
            scope: nil
        )
        appState.activeConfigDetail = detail
        appState.pushConfigDetail(navItemID: NavigationItem.memory.id, detail: detail)
    }

    private func reloadProjects() {
        let projects = appState.projects
        let mapped = ClaudeConfigLoader.projectsWithMemory()
            .compactMap { dirName, count in
                let name = projects.first(where: { $0.id == dirName })?.name ?? decodeProjectName(dirName)
                return (dirName: dirName, projectName: name, count: count)
            }
        projectsWithMemory = mapped
            .sorted { $0.projectName.localizedCaseInsensitiveCompare($1.projectName) == .orderedAscending }
    }

    private func reloadMemoryFiles() {
        if let dir = selectedProjectDir {
            memoryFiles = ClaudeConfigLoader.loadMemoryFiles(projectDirName: dir)
        } else {
            // Load from all projects
            let allFiles = ClaudeConfigLoader.projectsWithMemory()
                .flatMap { dirName, _ in
                    ClaudeConfigLoader.loadMemoryFiles(projectDirName: dirName)
                }
            memoryFiles = allFiles
                .sorted { lhs, rhs in
                    if lhs.isMain != rhs.isMain { return lhs.isMain }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
        }
    }

    private func syncSidebarCount() {
        appState.sidebarCounts[NavigationItem.memory.id] = ClaudeConfigLoader.totalMemoryFileCount()
    }

    private func startWatching() {
        guard fileWatchers.isEmpty else { return }
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")

        let onFilesChanged: @MainActor ()
            -> Void = { [weak appState] in
                reloadProjects()
                reloadMemoryFiles()
                appState?.sidebarCounts[NavigationItem.memory.id] = ClaudeConfigLoader.totalMemoryFileCount()
            }

        // Watch projects dir for new project memory directories
        let projectsWatcher = FileWatcher(onChange: onFilesChanged)
        projectsWatcher.start(path: claudeDir.appendingPathComponent("projects").path)
        fileWatchers.append(projectsWatcher)

        // Watch each project's memory directory for file changes
        for project in projectsWithMemory {
            let memoryPath = claudeDir
                .appendingPathComponent("projects")
                .appendingPathComponent(project.dirName)
                .appendingPathComponent("memory").path
            let memoryWatcher = FileWatcher(onChange: onFilesChanged)
            memoryWatcher.start(path: memoryPath)
            fileWatchers.append(memoryWatcher)
        }
    }

    private func decodeProjectName(_ encoded: String) -> String {
        // Convert encoded dir name to readable name
        // e.g. "-Users-leo-Dev-git-myapp" -> "myapp"
        let parts = encoded.split(separator: "-", omittingEmptySubsequences: true)
        return parts.last.map(String.init) ?? encoded
    }
}

// MARK: - Project Chip

private struct ProjectChip: View {
    let name: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State
    private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: PoirotTheme.Spacing.xs) {
                Text(name)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(
                        isSelected ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textSecondary
                    )
                    .lineLimit(1)

                Text("\(count)")
                    .font(PoirotTheme.Typography.pico)
                    .foregroundStyle(
                        isSelected ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textTertiary
                    )
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(
                            isSelected
                                ? PoirotTheme.Colors.accentDim
                                : PoirotTheme.Colors.bgElevated
                        )
                    )
            }
            .padding(.horizontal, PoirotTheme.Spacing.md)
            .padding(.vertical, PoirotTheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                    .fill(
                        isSelected
                            ? PoirotTheme.Colors.accentDim
                            : isHovered
                            ? PoirotTheme.Colors.bgCardHover
                            : PoirotTheme.Colors.bgCard
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                    .strokeBorder(
                        isSelected
                            ? PoirotTheme.Colors.accent.opacity(0.3)
                            : PoirotTheme.Colors.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .help("Filter by \(name)")
        .onHover { isHovered = $0 }
    }
}

// MARK: - Memory Card

private struct MemoryCard: View {
    let memory: MemoryFile
    var filterQuery: String = ""
    let onTap: () -> Void

    @State
    private var isHovered = false
    @State
    private var copyTapped = false

    @Environment(AppState.self)
    private var appState

    private var snippet: String {
        let lines = memory.content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        return lines.prefix(3).joined(separator: " ")
    }

    private var projectName: String {
        appState.projects.first(where: { $0.id == memory.projectID })?.name
            ?? memory.projectID.split(separator: "-").last.map(String.init)
            ?? memory.projectID
    }

    var body: some View {
        Button { onTap() } label: {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
                HStack(spacing: PoirotTheme.Spacing.sm) {
                    if memory.isMain {
                        Image(systemName: "star.fill")
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.accent)
                            .symbolEffect(.breathe, isActive: isHovered)
                    }

                    Text(HighlightedText.fuzzyAttributedString(memory.name, query: filterQuery))
                        .font(PoirotTheme.Typography.bodyMedium)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)

                    Spacer()

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(memory.content, forType: .string)
                        appState.showToast("Copied content to clipboard")
                        copyTapped = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copyTapped = false }
                    } label: {
                        Image(systemName: copyTapped ? "checkmark" : "doc.on.doc")
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .help("Copy Content")
                }

                if !snippet.isEmpty {
                    Text(HighlightedText.fuzzyAttributedString(snippet, query: filterQuery))
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: PoirotTheme.Spacing.sm) {
                    if memory.isMain {
                        ConfigBadge(
                            text: "Entrypoint",
                            fg: PoirotTheme.Colors.accent,
                            bg: PoirotTheme.Colors.accentDim
                        )
                    }

                    Text(projectName)
                        .font(PoirotTheme.Typography.pico)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .padding(.horizontal, PoirotTheme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(PoirotTheme.Colors.textTertiary.opacity(0.08))
                        )

                    Text(memory.filename)
                        .font(PoirotTheme.Typography.code)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .padding(.horizontal, PoirotTheme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .fill(PoirotTheme.Colors.bgElevated)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PoirotTheme.Spacing.lg)
            .cardChrome(isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .help("Open memory file")
        .onHover { isHovered = $0 }
    }
}
