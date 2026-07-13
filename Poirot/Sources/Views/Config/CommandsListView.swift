@preconcurrency import MarkdownUI
import SwiftUI

struct CommandsListView: View {
    let item: ConfigurationItem
    @State
    private var commands: [ClaudeCommand] = []
    @State
    private var isRevealed = false
    @State
    private var isLoaded = false
    @State
    private var selectedCommand: ClaudeCommand?
    @State
    private var filterQuery = ""

    @AppStorage("textEditor")
    private var textEditor = PreferredEditor.vscode.rawValue

    @Environment(AppState.self)
    private var appState

    private var editor: PreferredEditor {
        PreferredEditor(rawValue: textEditor) ?? .vscode
    }

    private var filteredCommands: [ClaudeCommand] {
        let q = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return commands }
        return commands
            .compactMap { cmd -> (ClaudeCommand, Int)? in
                let best = max(
                    HighlightedText.fuzzyMatch(cmd.name, query: q)?.score ?? 0,
                    HighlightedText.fuzzyMatch(cmd.description, query: q)?.score ?? 0
                )
                return best > 0 ? (cmd, best) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        Group {
            if let command = selectedCommand {
                ConfigItemDetailView(
                    title: command.name,
                    icon: "apple.terminal.fill",
                    iconColor: PoirotTheme.Colors.blue,
                    markdownBody: command.body,
                    filePath: command.filePath,
                    scope: command.scope
                ) {
                    HStack(spacing: PoirotTheme.Spacing.sm) {
                        if let model = command.model {
                            ConfigBadge(
                                text: ConfigHelpers.formatModel(model),
                                fg: PoirotTheme.Colors.accent,
                                bg: PoirotTheme.Colors.accentDim
                            )
                        }
                        if let tools = command.allowedTools, !tools.isEmpty {
                            let toolNames = tools.split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                            ForEach(toolNames, id: \.self) { tool in
                                ConfigBadge(
                                    text: tool,
                                    fg: PoirotTheme.Colors.blue,
                                    bg: PoirotTheme.Colors.blue.opacity(0.15)
                                )
                            }
                        }
                        if let hint = command.argumentHint, !hint.isEmpty {
                            Text(hint)
                                .font(PoirotTheme.Typography.code)
                                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        }
                        if let style = command.outputStyle, !style.isEmpty {
                            ConfigBadge(
                                text: style,
                                fg: PoirotTheme.Colors.purple,
                                bg: PoirotTheme.Colors.purple.opacity(0.15)
                            )
                        }
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                listView
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .task(id: appState.activeConfigDetail?.filePath) {
            if commands.isEmpty { reloadCommands() }
            if let detail = appState.activeConfigDetail,
               selectedCommand?.filePath != detail.filePath,
               let match = commands.first(where: { $0.filePath == detail.filePath }) {
                selectedCommand = match
            }
        }
        .onChange(of: appState.activeConfigDetail) {
            if let detail = appState.activeConfigDetail {
                if selectedCommand?.filePath != detail.filePath {
                    let match = commands.first(where: { $0.filePath == detail.filePath })
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCommand = match
                    }
                }
            } else if selectedCommand != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedCommand = nil
                }
                reloadCommands()
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            ConfigScreenHeader(
                item: item,
                dynamicCount: "\(commands.count) \(commands.count == 1 ? "command" : "commands")"
            )

            if !isLoaded {
                ConfigSkeletonView(
                    layout: appState.configLayout(for: item.id)
                )
            } else if commands.isEmpty {
                ConfigEmptyState(
                    icon: "apple.terminal",
                    message: "No commands found",
                    hint: "~/.claude/commands/"
                )
            } else if filteredCommands.isEmpty {
                ConfigEmptyState(
                    icon: "magnifyingglass",
                    message: "No commands match \"\(filterQuery)\"",
                    hint: "Try a different search term"
                )
            } else {
                configContent
            }
        }
        .background(PoirotTheme.Colors.bgApp)
        .toolbar { ConfigLayoutToolbar(
            screenID: item.id,
            filterQuery: $filterQuery,
            placeholder: "Find in Commands\u{2026}",
            showProjectPicker: true,
            showAddButton: true
        )
        }
        .task {
            reloadCommands()
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
            createAndOpen()
        }
        .onChange(of: appState.configProjectPath) {
            reloadCommands()
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
            HStack(alignment: .top, spacing: PoirotTheme.Spacing.lg) {
                ForEach(0 ..< 2, id: \.self) { column in
                    LazyVStack(spacing: PoirotTheme.Spacing.lg) {
                        ForEach(commandsForColumn(column), id: \.element.id) { index, command in
                            CommandCard(command: command, filterQuery: filterQuery) {
                                selectCommand(command)
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

    private func commandsForColumn(_ column: Int) -> [(offset: Int, element: ClaudeCommand)] {
        Array(filteredCommands.enumerated()).filter { $0.offset % 2 == column }
    }

    private var configList: some View {
        ScrollView {
            LazyVStack(spacing: PoirotTheme.Spacing.md) {
                ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                    CommandCard(command: command, filterQuery: filterQuery) {
                        selectCommand(command)
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

    private func selectCommand(_ command: ClaudeCommand) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedCommand = command
        }
        let detail = ConfigDetailInfo(
            name: command.name,
            markdownContent: command.body,
            filePath: command.filePath,
            scope: command.scope
        )
        appState.activeConfigDetail = detail
        appState.pushConfigDetail(navItemID: NavigationItem.commands.id, detail: detail)
    }

    private func createAndOpen() {
        Task.detached {
            if let path = ClaudeConfigLoader.createCommandTemplate() {
                await MainActor.run {
                    EditorLauncher.open(filePath: path, editor: editor)
                    reloadCommands()
                    appState.showToast("Created new command template", icon: "plus.circle.fill")
                }
            }
        }
    }

    private func reloadCommands() {
        commands = ClaudeConfigLoader.loadCommands(projectPath: appState.effectiveConfigProjectPath)
    }
}

// MARK: - Command Card

private struct CommandCard: View {
    let command: ClaudeCommand
    var filterQuery: String = ""
    let onTap: () -> Void

    @Environment(AppState.self)
    private var appState

    @State
    private var isHovered = false

    @State
    private var copyTapped = false

    var body: some View {
        Button { onTap() } label: {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(HighlightedText.fuzzyAttributedString(command.name, query: filterQuery))
                        .font(PoirotTheme.Typography.bodyMedium)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)

                    if let hint = command.argumentHint, !hint.isEmpty {
                        Text(hint)
                            .font(PoirotTheme.Typography.code)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    }

                    Spacer()

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("/\(command.name)", forType: .string)
                        copyTapped = true
                        appState.showToast("Copied /\(command.name) to clipboard")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copyTapped = false }
                    } label: {
                        Image(systemName: copyTapped ? "checkmark" : "doc.on.doc")
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .help("Copy Command")
                }

                if !command.description.isEmpty {
                    Text(HighlightedText.fuzzyAttributedString(command.description, query: filterQuery))
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: PoirotTheme.Spacing.sm) {
                    ConfigScopeBadge(scope: command.scope)

                    if let model = command.model {
                        ConfigBadge(
                            text: ConfigHelpers.formatModel(model),
                            fg: PoirotTheme.Colors.accent,
                            bg: PoirotTheme.Colors.accentDim
                        )
                    }
                    if let tools = command.allowedTools, !tools.isEmpty {
                        ConfigBadge(
                            text: "\(tools.split(separator: ",").count) tools",
                            fg: PoirotTheme.Colors.blue,
                            bg: PoirotTheme.Colors.blue.opacity(0.15)
                        )
                    }
                    if let style = command.outputStyle, !style.isEmpty {
                        ConfigBadge(
                            text: style,
                            fg: PoirotTheme.Colors.purple,
                            bg: PoirotTheme.Colors.purple.opacity(0.15)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PoirotTheme.Spacing.lg)
            .cardChrome(isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .help("Open command")
        .onHover { isHovered = $0 }
    }
}
