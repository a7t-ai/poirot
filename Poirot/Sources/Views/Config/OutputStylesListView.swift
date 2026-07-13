@preconcurrency import MarkdownUI
import SwiftUI

struct OutputStylesListView: View {
    let item: ConfigurationItem
    @State
    private var styles: [OutputStyle] = []
    @State
    private var isRevealed = false
    @State
    private var isLoaded = false
    @State
    private var selectedStyle: OutputStyle?
    @State
    private var filterQuery = ""

    @AppStorage("textEditor")
    private var textEditor = PreferredEditor.vscode.rawValue

    @Environment(AppState.self)
    private var appState

    private var editor: PreferredEditor {
        PreferredEditor(rawValue: textEditor) ?? .vscode
    }

    private var filteredStyles: [OutputStyle] {
        let q = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return styles }
        return styles
            .compactMap { style -> (OutputStyle, Int)? in
                let best = max(
                    HighlightedText.fuzzyMatch(style.name, query: q)?.score ?? 0,
                    HighlightedText.fuzzyMatch(style.description, query: q)?.score ?? 0
                )
                return best > 0 ? (style, best) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        Group {
            if let style = selectedStyle {
                ConfigItemDetailView(
                    title: style.name,
                    icon: "speaker.wave.3.fill",
                    iconColor: PoirotTheme.Colors.red,
                    markdownBody: style.body,
                    filePath: style.filePath,
                    scope: style.scope
                ) {
                    HStack(spacing: PoirotTheme.Spacing.sm) {
                        if !style.description.isEmpty {
                            Text(style.description)
                                .font(PoirotTheme.Typography.caption)
                                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                                .lineLimit(2)
                        }

                        Text(style.filename)
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
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                listView
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .task(id: appState.activeConfigDetail?.filePath) {
            if styles.isEmpty { reloadStyles() }
            if let detail = appState.activeConfigDetail,
               selectedStyle?.filePath != detail.filePath,
               let match = styles.first(where: { $0.filePath == detail.filePath }) {
                selectedStyle = match
            }
        }
        .onChange(of: appState.activeConfigDetail) {
            if let detail = appState.activeConfigDetail {
                if selectedStyle?.filePath != detail.filePath {
                    let match = styles.first(where: { $0.filePath == detail.filePath })
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStyle = match
                    }
                }
            } else if selectedStyle != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedStyle = nil
                }
                reloadStyles()
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            ConfigScreenHeader(
                item: item,
                dynamicCount: "\(styles.count) \(styles.count == 1 ? "style" : "styles")"
            )

            if !isLoaded {
                ConfigSkeletonView(
                    layout: appState.configLayout(for: item.id)
                )
            } else if styles.isEmpty {
                ConfigEmptyState(
                    icon: "speaker.wave.3",
                    message: "No output styles found",
                    hint: "~/.claude/output-styles/"
                )
            } else if filteredStyles.isEmpty {
                ConfigEmptyState(
                    icon: "magnifyingglass",
                    message: "No styles match \"\(filterQuery)\"",
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
            placeholder: "Find in Output Styles\u{2026}",
            showProjectPicker: true,
            showAddButton: true
        )
        }
        .task {
            reloadStyles()
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
            reloadStyles()
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
                        ForEach(stylesForColumn(column), id: \.element.id) { index, style in
                            OutputStyleCard(style: style, filterQuery: filterQuery) {
                                selectStyle(style)
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

    private func stylesForColumn(_ column: Int) -> [(offset: Int, element: OutputStyle)] {
        Array(filteredStyles.enumerated()).filter { $0.offset % 2 == column }
    }

    private var configList: some View {
        ScrollView {
            LazyVStack(spacing: PoirotTheme.Spacing.md) {
                ForEach(Array(filteredStyles.enumerated()), id: \.element.id) { index, style in
                    OutputStyleCard(style: style, filterQuery: filterQuery) {
                        selectStyle(style)
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

    private func selectStyle(_ style: OutputStyle) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedStyle = style
        }
        let detail = ConfigDetailInfo(
            name: style.name,
            markdownContent: style.body,
            filePath: style.filePath,
            scope: style.scope
        )
        appState.activeConfigDetail = detail
        appState.pushConfigDetail(navItemID: NavigationItem.outputStyles.id, detail: detail)
    }

    private func createAndOpen() {
        Task.detached {
            if let path = ClaudeConfigLoader.createOutputStyleTemplate() {
                await MainActor.run {
                    EditorLauncher.open(filePath: path, editor: editor)
                    reloadStyles()
                    appState.showToast("Created new output style template", icon: "plus.circle.fill")
                }
            }
        }
    }

    private func reloadStyles() {
        styles = ClaudeConfigLoader.loadOutputStyles(projectPath: appState.effectiveConfigProjectPath)
    }
}

// MARK: - Output Style Card

private struct OutputStyleCard: View {
    let style: OutputStyle
    var filterQuery: String = ""
    let onTap: () -> Void
    @State
    private var isHovered = false

    var body: some View {
        Button { onTap() } label: {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
                Text(HighlightedText.fuzzyAttributedString(style.name, query: filterQuery))
                    .font(PoirotTheme.Typography.bodyMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)

                if !style.description.isEmpty {
                    Text(HighlightedText.fuzzyAttributedString(style.description, query: filterQuery))
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: PoirotTheme.Spacing.sm) {
                    ConfigScopeBadge(scope: style.scope)

                    Text(style.filename)
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
        .help("Open output style")
        .onHover { isHovered = $0 }
    }
}
