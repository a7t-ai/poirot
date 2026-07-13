import SwiftUI

struct HooksListView: View {
    let item: ConfigurationItem
    @State
    private var hooks: [HookEntry] = []
    @State
    private var isRevealed = false
    @State
    private var isLoaded = false
    @State
    private var filterQuery = ""
    @State
    private var showForm = false
    @State
    private var editingEntry: HookEntry?
    @State
    private var deleteTarget: HookEntry?
    @State
    private var showDeleteConfirmation = false
    @State
    private var fileWatcher: FileWatcher?

    @Environment(AppState.self)
    private var appState

    private var filteredHooks: [HookEntry] {
        let q = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return hooks }
        return hooks
            .compactMap { entry -> (HookEntry, Int)? in
                let best = max(
                    HighlightedText.fuzzyMatch(entry.event.label, query: q)?.score ?? 0,
                    HighlightedText.fuzzyMatch(entry.matcher ?? "", query: q)?.score ?? 0,
                    HighlightedText.fuzzyMatch(
                        entry.firstHandler?.displayCommand ?? "", query: q
                    )?.score ?? 0
                )
                return best > 0 ? (entry, best) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private var groupedHooks: [(event: HookEvent, entries: [HookEntry])] {
        let dict = Dictionary(grouping: filteredHooks) { $0.event }
        return HookEvent.allCases.compactMap { event in
            guard let entries = dict[event], !entries.isEmpty else { return nil }
            return (event: event, entries: entries)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ConfigScreenHeader(
                item: item,
                dynamicCount: "\(hooks.count) \(hooks.count == 1 ? "hook" : "hooks")"
            )

            if !isLoaded {
                ConfigSkeletonView(
                    layout: appState.configLayout(for: item.id)
                )
            } else if hooks.isEmpty {
                ConfigEmptyState(
                    icon: "arrow.triangle.branch",
                    message: "No hooks configured",
                    hint: "Add hooks to automate tasks during Claude Code events"
                )
            } else if filteredHooks.isEmpty {
                ConfigEmptyState(
                    icon: "magnifyingglass",
                    message: "No hooks match \"\(filterQuery)\"",
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
                placeholder: "Find in Hooks\u{2026}",
                showProjectPicker: true,
                showAddButton: true
            )
        }
        .task {
            reloadHooks()
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
        .onChange(of: appState.configAddTrigger) {
            editingEntry = nil
            showForm = true
        }
        .onChange(of: appState.configProjectPath) {
            reloadHooks()
        }
        .sheet(isPresented: $showForm) {
            HookFormView(
                scope: .global,
                projectPath: appState.effectiveConfigProjectPath,
                editingEntry: editingEntry,
                onSave: {
                    showForm = false
                    editingEntry = nil
                    reloadHooks()
                },
                onCancel: {
                    showForm = false
                    editingEntry = nil
                }
            )
        }
        .confirmationDialog(
            "Delete Hook",
            isPresented: $showDeleteConfirmation,
            presenting: deleteTarget
        ) { entry in
            Button("Delete", role: .destructive) {
                SettingsWriter.deleteHook(
                    event: entry.event,
                    matcherIndex: entry.matcherGroupIndex,
                    scope: entry.scope,
                    projectPath: appState.effectiveConfigProjectPath
                )
                appState.showToast("Hook deleted", icon: "trash.fill", style: .info)
                reloadHooks()
            }
        } message: { entry in
            Text("Delete the \(entry.event.label) hook\(entry.matcher.map { " matching \"\($0)\"" } ?? "")?")
        }
        .onAppear { startWatcher() }
        .onDisappear {
            fileWatcher?.stop()
            fileWatcher = nil
        }
    }

    @ViewBuilder
    private var configContent: some View {
        if appState.configLayout(for: item.id) == .grid {
            configGrid
        } else {
            configList
        }
    }

    private var configGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xl) {
                ForEach(groupedHooks, id: \.event) { group in
                    eventSection(group.event, entries: group.entries, isGrid: true)
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.xxxl)
            .padding(.top, PoirotTheme.Spacing.lg)
            .padding(.bottom, PoirotTheme.Spacing.xxl)
        }
        .scrollIndicators(.never)
    }

    private var configList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xl) {
                ForEach(groupedHooks, id: \.event) { group in
                    eventSection(group.event, entries: group.entries, isGrid: false)
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.xxxl)
            .padding(.top, PoirotTheme.Spacing.lg)
            .padding(.bottom, PoirotTheme.Spacing.xxl)
        }
        .scrollIndicators(.never)
    }

    private func eventSection(
        _ event: HookEvent, entries: [HookEntry], isGrid: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Image(systemName: event.icon)
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.orange)

                Text(event.label)
                    .font(PoirotTheme.Typography.sectionHeader)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .tracking(0.5)

                Text("\(entries.count)")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .padding(.horizontal, PoirotTheme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                            .fill(PoirotTheme.Colors.bgElevated)
                    )
            }

            if isGrid {
                HStack(alignment: .top, spacing: PoirotTheme.Spacing.lg) {
                    ForEach(0 ..< 2, id: \.self) { column in
                        LazyVStack(spacing: PoirotTheme.Spacing.lg) {
                            ForEach(
                                Array(entries.enumerated().filter { $0.offset % 2 == column }),
                                id: \.element.id
                            ) { index, entry in
                                hookCard(entry)
                                    .shimmerReveal(
                                        isRevealed: isRevealed,
                                        delay: Double(min(index, 7)) * 0.04,
                                        cornerRadius: PoirotTheme.Radius.md
                                    )
                            }
                        }
                    }
                }
            } else {
                LazyVStack(spacing: PoirotTheme.Spacing.md) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        hookCard(entry)
                            .shimmerReveal(
                                isRevealed: isRevealed,
                                delay: Double(min(index, 9)) * 0.03,
                                cornerRadius: PoirotTheme.Radius.md
                            )
                    }
                }
            }
        }
    }

    private func hookCard(_ entry: HookEntry) -> some View {
        HookCard(entry: entry, filterQuery: filterQuery) {
            editingEntry = entry
            showForm = true
        } onDelete: {
            deleteTarget = entry
            showDeleteConfirmation = true
        } onExport: {
            exportHook(entry)
        }
    }

    private func reloadHooks() {
        hooks = ClaudeConfigLoader.loadHooks(projectPath: appState.effectiveConfigProjectPath)
    }

    private func startWatcher() {
        guard fileWatcher == nil else { return }
        let watcher = FileWatcher { [weak appState] in
            appState?.refreshID = UUID()
        }
        let settingsPath = SettingsWriter.settingsFileURL()
            .deletingLastPathComponent().path
        watcher.start(path: settingsPath)
        fileWatcher = watcher
    }

    private func exportHook(_ entry: HookEntry) {
        guard let data = SettingsWriter.exportHooksAsJSON([entry]),
              let jsonString = String(data: data, encoding: .utf8)
        else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(jsonString, forType: .string)
        appState.showToast("Hook JSON copied to clipboard", icon: "doc.on.clipboard.fill")
    }
}

// MARK: - Hook Card

private struct HookCard: View {
    let entry: HookEntry
    var filterQuery: String = ""
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    @State
    private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                if let handler = entry.firstHandler {
                    Image(systemName: handler.type == .command ? "terminal" : "globe")
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)

                    Text(HighlightedText.fuzzyAttributedString(
                        handler.displayCommand, query: filterQuery
                    ))
                    .font(PoirotTheme.Typography.bodyMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .lineLimit(1)
                }

                Spacer()

                menuButton
            }

            if let matcher = entry.matcher, !matcher.isEmpty {
                HStack(spacing: PoirotTheme.Spacing.xs) {
                    Text("matcher:")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)

                    Text(HighlightedText.fuzzyAttributedString(matcher, query: filterQuery))
                        .font(PoirotTheme.Typography.codeSmall)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                }
            }

            HStack(spacing: PoirotTheme.Spacing.sm) {
                ConfigScopeBadge(scope: entry.scope)

                if let handler = entry.firstHandler {
                    ConfigBadge(
                        text: handler.type.label,
                        fg: handler.type == .command ? PoirotTheme.Colors.blue : PoirotTheme.Colors.green,
                        bg: (handler.type == .command ? PoirotTheme.Colors.blue : PoirotTheme.Colors.green)
                            .opacity(0.15)
                    )

                    if let timeout = handler.timeout {
                        ConfigBadge(
                            text: "\(timeout)s",
                            fg: PoirotTheme.Colors.textTertiary,
                            bg: PoirotTheme.Colors.bgElevated
                        )
                    }
                }

                if entry.handlerCount > 1 {
                    ConfigBadge(
                        text: "\(entry.handlerCount) handlers",
                        fg: PoirotTheme.Colors.orange,
                        bg: PoirotTheme.Colors.orange.opacity(0.15)
                    )
                }
            }

            if let msg = entry.firstHandler?.statusMessage, !msg.isEmpty {
                Text(msg)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PoirotTheme.Spacing.lg)
        .cardChrome(isHovered: isHovered)
        .onHover { isHovered = $0 }
    }

    private var menuButton: some View {
        Menu {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button { onExport() } label: {
                Label("Export JSON", systemImage: "doc.on.clipboard")
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Hook actions")
        .frame(width: 20)
    }
}
