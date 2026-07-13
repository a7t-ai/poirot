import SwiftUI

struct PluginsListView: View {
    let item: ConfigurationItem
    @State
    private var plugins: [ClaudePlugin] = []
    @State
    private var isRevealed = false
    @State
    private var isLoaded = false
    @State
    private var filterQuery = ""

    @Environment(AppState.self)
    private var appState

    private var filteredPlugins: [ClaudePlugin] {
        let q = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return plugins }
        return plugins
            .compactMap { plugin -> (ClaudePlugin, Int)? in
                let best = max(
                    HighlightedText.fuzzyMatch(plugin.name, query: q)?.score ?? 0,
                    HighlightedText.fuzzyMatch(plugin.author, query: q)?.score ?? 0
                )
                return best > 0 ? (plugin, best) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ConfigScreenHeader(
                item: item,
                dynamicCount: "\(plugins.count) \(plugins.count == 1 ? "plugin" : "plugins")"
            )

            if !isLoaded {
                ConfigSkeletonView(
                    layout: appState.configLayout(for: item.id)
                )
            } else if plugins.isEmpty {
                ConfigEmptyState(
                    icon: "puzzlepiece",
                    message: "No plugins installed",
                    hint: "~/.claude/plugins/"
                )
            } else if filteredPlugins.isEmpty {
                ConfigEmptyState(
                    icon: "magnifyingglass",
                    message: "No plugins match \"\(filterQuery)\"",
                    hint: "Try a different search term"
                )
            } else {
                configContent
            }
        }
        .background(PoirotTheme.Colors.bgApp)
        .toolbar {
            ConfigLayoutToolbar(screenID: item.id, filterQuery: $filterQuery, placeholder: "Find in Plugins\u{2026}")
        }
        .task {
            reloadPlugins()
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
            VStack(spacing: 0) {
                infoBanner

                HStack(alignment: .top, spacing: PoirotTheme.Spacing.lg) {
                    ForEach(0 ..< 2, id: \.self) { column in
                        LazyVStack(spacing: PoirotTheme.Spacing.lg) {
                            ForEach(pluginsForColumn(column), id: \.element.id) { index, plugin in
                                PluginCard(
                                    plugin: plugin,
                                    filterQuery: filterQuery,
                                    onToggle: { togglePlugin(plugin) },
                                    onRemove: { removePlugin(plugin) }
                                )
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
        }
        .scrollIndicators(.never)
    }

    private func pluginsForColumn(_ column: Int) -> [(offset: Int, element: ClaudePlugin)] {
        Array(filteredPlugins.enumerated()).filter { $0.offset % 2 == column }
    }

    private var configList: some View {
        ScrollView {
            VStack(spacing: 0) {
                infoBanner

                LazyVStack(spacing: PoirotTheme.Spacing.md) {
                    ForEach(Array(filteredPlugins.enumerated()), id: \.element.id) { index, plugin in
                        PluginCard(
                            plugin: plugin,
                            filterQuery: filterQuery,
                            onToggle: { togglePlugin(plugin) },
                            onRemove: { removePlugin(plugin) }
                        )
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
        }
        .scrollIndicators(.never)
    }

    private var infoBanner: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: "info.circle")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.blue)

            Text("Install plugins via the CLI with `claude plugin add` or place them in ~/.claude/plugins/")
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PoirotTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .fill(PoirotTheme.Colors.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                        .strokeBorder(PoirotTheme.Colors.blue.opacity(0.1))
                )
        )
        .padding(.horizontal, PoirotTheme.Spacing.xxxl)
        .padding(.top, PoirotTheme.Spacing.lg)
        .padding(.bottom, PoirotTheme.Spacing.sm)
    }

    private func togglePlugin(_ plugin: ClaudePlugin) {
        let newState = !plugin.isEnabled
        Task.detached {
            SettingsWriter.togglePlugin(key: plugin.id, enabled: newState)
            await MainActor.run {
                reloadPlugins()
                appState.showToast(
                    "\(plugin.name) \(newState ? "enabled" : "disabled")",
                    icon: newState ? "checkmark.circle.fill" : "xmark.circle.fill",
                    style: newState ? .success : .info
                )
            }
        }
    }

    private func removePlugin(_ plugin: ClaudePlugin) {
        Task.detached {
            SettingsWriter.removePlugin(key: plugin.id)
            await MainActor.run {
                reloadPlugins()
                appState.showToast("Removed \(plugin.name)", icon: "trash", style: .info)
            }
        }
    }

    private func reloadPlugins() {
        plugins = ClaudeConfigLoader.loadPlugins()
    }
}

// MARK: - Plugin Card

private struct PluginCard: View {
    let plugin: ClaudePlugin
    var filterQuery: String = ""
    let onToggle: () -> Void
    let onRemove: () -> Void
    @State
    private var isHovered = false
    @State
    private var showDeleteConfirmation = false
    @State
    private var showTogglePopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Text(HighlightedText.fuzzyAttributedString(plugin.name, query: filterQuery))
                    .font(PoirotTheme.Typography.bodyMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)

                if !plugin.author.isEmpty {
                    Text(HighlightedText.fuzzyAttributedString("by \(plugin.author)", query: filterQuery))
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }

                Spacer()

                Button {
                    showTogglePopover = true
                } label: {
                    HStack(spacing: PoirotTheme.Spacing.xs) {
                        let pillColor = plugin.isEnabled
                            ? PoirotTheme.Colors.green
                            : PoirotTheme.Colors.textTertiary.opacity(0.5)
                        Circle()
                            .fill(pillColor)
                            .frame(width: 6, height: 6)
                        Text(plugin.isEnabled ? "Enabled" : "Disabled")
                            .font(PoirotTheme.Typography.tiny)
                    }
                    .foregroundStyle(plugin.isEnabled ? PoirotTheme.Colors.green : PoirotTheme.Colors.textTertiary)
                    .padding(.horizontal, PoirotTheme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(
                            plugin.isEnabled
                                ? PoirotTheme.Colors.green.opacity(0.12)
                                : PoirotTheme.Colors.textTertiary.opacity(0.1)
                        )
                    )
                }
                .buttonStyle(.plain)
                .help(plugin.isEnabled ? "Disable plugin" : "Enable plugin")
                .popover(isPresented: $showTogglePopover) {
                    Button {
                        showTogglePopover = false
                        onToggle()
                    } label: {
                        Label(
                            plugin.isEnabled ? "Disable" : "Enable",
                            systemImage: plugin.isEnabled ? "xmark.circle" : "checkmark.circle"
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(PoirotTheme.Spacing.md)
                }

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Remove plugin")
            }

            HStack(spacing: PoirotTheme.Spacing.sm) {
                ConfigBadge(
                    text: "v\(plugin.version)",
                    fg: PoirotTheme.Colors.blue,
                    bg: PoirotTheme.Colors.blue.opacity(0.15)
                )

                if let date = formatDate(plugin.installedAt) {
                    Text("Installed \(date)")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PoirotTheme.Spacing.lg)
        .cardChrome(isHovered: isHovered)
        .onHover { isHovered = $0 }
        .confirmationDialog(
            "Remove \(plugin.name)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("This will remove the plugin from your enabled plugins in settings.json.")
        }
    }

    private func formatDate(_ iso: String) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return nil }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return relative.localizedString(for: date, relativeTo: Date())
    }
}
