@preconcurrency import MarkdownUI
import SwiftUI

struct MemoryListView: View {
    let item: ConfigurationItem
    @State
    private var memoryFiles: [MemoryFile] = []
    @State
    private var sources: [MemorySource] = []
    @State
    private var selectedSourceID: String?
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
    @Environment(MemorySourcesStore.self)
    private var memorySources

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
        .onChange(of: memorySources.folders) {
            // A folder was added/removed in Settings — refresh sources, files, count and watchers.
            reloadSources()
            reloadMemoryFiles()
            syncSidebarCount()
            restartWatching()
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
            } else if sources.isEmpty {
                ConfigEmptyState(
                    icon: "brain.head.profile",
                    message: "No memory files found",
                    hint: "Add a folder in Settings › Memory, or use ~/.claude/projects/<project>/memory/"
                )
            } else if memoryFiles.isEmpty, selectedSourceID != nil {
                ConfigEmptyState(
                    icon: "brain.head.profile",
                    message: "No memory files in this source",
                    hint: "Select a different source"
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
            reloadSources()
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
        if let id = selectedSourceID,
           let source = sources.first(where: { $0.id == id }) {
            return "\(count) \(fileWord) in \(source.name)"
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
                    name: "All",
                    count: sources.reduce(0) { $0 + $1.count },
                    isSelected: selectedSourceID == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSourceID = nil
                    }
                    reloadMemoryFiles()
                }

                ForEach(sources) { source in
                    ProjectChip(
                        name: source.name,
                        count: source.count,
                        isSelected: selectedSourceID == source.id,
                        icon: source.isCustom ? "folder" : nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSourceID = source.id
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

    private func reloadSources() {
        let projects = appState.projects
        let projectSources = ClaudeConfigLoader.projectsWithMemory()
            .map { dirName, count -> MemorySource in
                let name = projects.first(where: { $0.id == dirName })?.name ?? decodeProjectName(dirName)
                return MemorySource(id: dirName, name: name, count: count, isCustom: false, folderURL: nil)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let customSources = memorySources.folders.map { url -> MemorySource in
            MemorySource(
                id: "\(MemoryFile.customSourcePrefix)\(url.path)",
                name: url.lastPathComponent,
                count: ClaudeConfigLoader.customMemoryFileCount(folder: url),
                isCustom: true,
                folderURL: url
            )
        }

        sources = projectSources + customSources
        // Drop a stale selection if the source disappeared (e.g. a removed folder).
        if let id = selectedSourceID, !sources.contains(where: { $0.id == id }) {
            selectedSourceID = nil
        }
    }

    private func reloadMemoryFiles() {
        if let id = selectedSourceID, let source = sources.first(where: { $0.id == id }) {
            memoryFiles = source.folderURL.map { ClaudeConfigLoader.loadMemoryFiles(customFolder: $0) }
                ?? ClaudeConfigLoader.loadMemoryFiles(projectDirName: source.id)
        } else {
            // Load from every source: project memory dirs plus user-added folders.
            let projectFiles = ClaudeConfigLoader.projectsWithMemory()
                .flatMap { dirName, _ in ClaudeConfigLoader.loadMemoryFiles(projectDirName: dirName) }
            let customFiles = memorySources.folders
                .flatMap { ClaudeConfigLoader.loadMemoryFiles(customFolder: $0) }
            memoryFiles = (projectFiles + customFiles)
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
                reloadSources()
                reloadMemoryFiles()
                appState?.sidebarCounts[NavigationItem.memory.id] = ClaudeConfigLoader.totalMemoryFileCount()
            }

        // Watch projects dir for new project memory directories
        let projectsWatcher = FileWatcher(onChange: onFilesChanged)
        projectsWatcher.start(path: claudeDir.appendingPathComponent("projects").path)
        fileWatchers.append(projectsWatcher)

        // Watch each project's memory directory for file changes
        for source in sources where !source.isCustom {
            let memoryPath = claudeDir
                .appendingPathComponent("projects")
                .appendingPathComponent(source.id)
                .appendingPathComponent("memory").path
            let memoryWatcher = FileWatcher(onChange: onFilesChanged)
            memoryWatcher.start(path: memoryPath)
            fileWatchers.append(memoryWatcher)
        }

        // Watch each user-added folder for file changes
        for url in memorySources.folders {
            let folderWatcher = FileWatcher(onChange: onFilesChanged)
            folderWatcher.start(path: url.path)
            fileWatchers.append(folderWatcher)
        }
    }

    /// Tear down and re-arm the file watchers — used after the source set changes so newly
    /// added folders are watched and removed ones are dropped.
    private func restartWatching() {
        for watcher in fileWatchers { watcher.stop() }
        fileWatchers.removeAll()
        startWatching()
    }

    private func decodeProjectName(_ encoded: String) -> String {
        // Convert encoded dir name to readable name
        // e.g. "-Users-leo-Dev-git-myapp" -> "myapp"
        let parts = encoded.split(separator: "-", omittingEmptySubsequences: true)
        return parts.last.map(String.init) ?? encoded
    }
}

// MARK: - Project Chip

private struct MemorySource: Identifiable, Equatable {
    /// Project directory hash, or `custom:<path>` for a user-added folder.
    let id: String
    let name: String
    let count: Int
    let isCustom: Bool
    /// The folder to read, for custom sources; `nil` for project sources.
    let folderURL: URL?
}

private struct ProjectChip: View {
    let name: String
    let count: Int
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void

    @State
    private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: PoirotTheme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(PoirotTheme.Typography.pico)
                        .foregroundStyle(
                            isSelected ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textTertiary
                        )
                }

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
        if let label = memory.sourceLabel { return label }
        return appState.projects.first(where: { $0.id == memory.projectID })?.name
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
