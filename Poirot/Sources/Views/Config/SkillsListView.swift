@preconcurrency import MarkdownUI
import SwiftUI

struct SkillsListView: View {
    let item: ConfigurationItem
    @State
    private var skills: [ClaudeSkill] = []
    @State
    private var isRevealed = false
    @State
    private var isLoaded = false
    @State
    private var selectedSkill: ClaudeSkill?
    @State
    private var filterQuery = ""

    @AppStorage("textEditor")
    private var textEditor = PreferredEditor.vscode.rawValue

    @Environment(AppState.self)
    private var appState

    private var editor: PreferredEditor {
        PreferredEditor(rawValue: textEditor) ?? .vscode
    }

    private var filteredSkills: [ClaudeSkill] {
        let q = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return skills }
        return skills
            .compactMap { skill -> (ClaudeSkill, Int)? in
                let best = max(
                    HighlightedText.fuzzyMatch(skill.name, query: q)?.score ?? 0,
                    HighlightedText.fuzzyMatch(skill.description, query: q)?.score ?? 0
                )
                return best > 0 ? (skill, best) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        Group {
            if let skill = selectedSkill {
                ConfigItemDetailView(
                    title: skill.name,
                    icon: "bolt.fill",
                    iconColor: PoirotTheme.Colors.accent,
                    markdownBody: skill.body,
                    filePath: skill.filePath,
                    scope: skill.scope
                ) {
                    HStack(spacing: PoirotTheme.Spacing.sm) {
                        if let model = skill.model {
                            ConfigBadge(
                                text: ConfigHelpers.formatModel(model),
                                fg: PoirotTheme.Colors.accent,
                                bg: PoirotTheme.Colors.accentDim
                            )
                        }
                        if let tools = skill.allowedTools, !tools.isEmpty {
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
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                listView
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .task(id: appState.activeConfigDetail?.filePath) {
            if skills.isEmpty { reloadSkills() }
            if let detail = appState.activeConfigDetail,
               selectedSkill?.filePath != detail.filePath,
               let match = skills.first(where: { $0.filePath == detail.filePath }) {
                selectedSkill = match
            }
        }
        .onChange(of: appState.activeConfigDetail) {
            if let detail = appState.activeConfigDetail {
                if selectedSkill?.filePath != detail.filePath {
                    let match = skills.first(where: { $0.filePath == detail.filePath })
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSkill = match
                    }
                }
            } else if selectedSkill != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedSkill = nil
                }
                reloadSkills()
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            ConfigScreenHeader(
                item: item,
                dynamicCount: "\(skills.count) \(skills.count == 1 ? "skill" : "skills")"
            )

            if !isLoaded {
                ConfigSkeletonView(
                    layout: appState.configLayout(for: item.id)
                )
            } else if skills.isEmpty {
                ConfigEmptyState(
                    icon: "bolt",
                    message: "No skills found",
                    hint: "~/.claude/skills/"
                )
            } else if filteredSkills.isEmpty {
                ConfigEmptyState(
                    icon: "magnifyingglass",
                    message: "No skills match \"\(filterQuery)\"",
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
            placeholder: "Find in Skills\u{2026}",
            showProjectPicker: true,
            showAddButton: true
        )
        }
        .task {
            reloadSkills()
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
            reloadSkills()
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
                        ForEach(skillsForColumn(column), id: \.element.id) { index, skill in
                            SkillCard(skill: skill, filterQuery: filterQuery) {
                                selectSkill(skill)
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

    private func skillsForColumn(_ column: Int) -> [(offset: Int, element: ClaudeSkill)] {
        Array(filteredSkills.enumerated()).filter { $0.offset % 2 == column }
    }

    private var configList: some View {
        ScrollView {
            LazyVStack(spacing: PoirotTheme.Spacing.md) {
                ForEach(Array(filteredSkills.enumerated()), id: \.element.id) { index, skill in
                    SkillCard(skill: skill, filterQuery: filterQuery) {
                        selectSkill(skill)
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

    private func selectSkill(_ skill: ClaudeSkill) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedSkill = skill
        }
        let detail = ConfigDetailInfo(
            name: skill.name,
            markdownContent: skill.body,
            filePath: skill.filePath,
            scope: skill.scope
        )
        appState.activeConfigDetail = detail
        appState.pushConfigDetail(navItemID: NavigationItem.skills.id, detail: detail)
    }

    private func createAndOpen() {
        Task.detached {
            if let path = ClaudeConfigLoader.createSkillTemplate() {
                await MainActor.run {
                    EditorLauncher.open(filePath: path, editor: editor)
                    reloadSkills()
                    appState.showToast("Created new skill template", icon: "plus.circle.fill")
                }
            }
        }
    }

    private func reloadSkills() {
        skills = ClaudeConfigLoader.loadSkills(projectPath: appState.effectiveConfigProjectPath)
    }
}

// MARK: - Skill Card

private struct SkillCard: View {
    let skill: ClaudeSkill
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
                HStack(alignment: .top) {
                    Text(HighlightedText.fuzzyAttributedString(skill.name, query: filterQuery))
                        .font(PoirotTheme.Typography.bodyMedium)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)

                    Spacer()

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(skill.name, forType: .string)
                        copyTapped = true
                        appState.showToast("Copied \(skill.name) to clipboard")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copyTapped = false }
                    } label: {
                        Image(systemName: copyTapped ? "checkmark" : "doc.on.doc")
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .help("Copy Skill Name")
                }

                if !skill.description.isEmpty {
                    Text(HighlightedText.fuzzyAttributedString(skill.description, query: filterQuery))
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: PoirotTheme.Spacing.sm) {
                    ConfigScopeBadge(scope: skill.scope)

                    if let model = skill.model {
                        ConfigBadge(
                            text: ConfigHelpers.formatModel(model),
                            fg: PoirotTheme.Colors.accent,
                            bg: PoirotTheme.Colors.accentDim
                        )
                    }
                    if let tools = skill.allowedTools, !tools.isEmpty {
                        ConfigBadge(
                            text: "\(tools.split(separator: ",").count) tools",
                            fg: PoirotTheme.Colors.blue,
                            bg: PoirotTheme.Colors.blue.opacity(0.15)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PoirotTheme.Spacing.lg)
            .cardChrome(isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .help("Open skill")
        .onHover { isHovered = $0 }
    }
}
