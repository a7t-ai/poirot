import SwiftUI

struct ModelsListView: View {
    let item: ConfigurationItem
    @Environment(\.provider)
    private var provider
    @Environment(AppState.self)
    private var appState
    @State
    private var isRevealed = false
    @State
    private var currentDefault: String?
    @State
    private var projectModel: String?
    @State
    private var filterQuery = ""

    private var filteredModels: [String] {
        let q = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return provider.supportedModels }
        return provider.supportedModels
            .compactMap { model -> (String, Int)? in
                guard let m = HighlightedText.fuzzyMatch(model, query: q) else { return nil }
                return (model, m.score)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ConfigScreenHeader(
                item: item,
                dynamicCount: "\(provider.supportedModels.count) \(provider.supportedModels.count == 1 ? "model" : "models")"
            )

            if filteredModels.isEmpty, !filterQuery.isEmpty {
                ConfigEmptyState(
                    icon: "magnifyingglass",
                    message: "No models match \"\(filterQuery)\"",
                    hint: "Try a different search term"
                )
            } else {
                configContent
            }
        }
        .background(PoirotTheme.Colors.bgApp)
        .toolbar {
            ConfigLayoutToolbar(screenID: item.id, filterQuery: $filterQuery, placeholder: "Find in Models\u{2026}")
        }
        .task {
            currentDefault = provider.defaultModelName
            loadProjectModel()
            isRevealed = false
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeOut(duration: 0.4)) {
                isRevealed = true
            }
        }
        .onChange(of: appState.configProjectPath) {
            loadProjectModel()
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
                            ForEach(modelsForColumn(column), id: \.element) { index, model in
                                ModelCard(
                                    name: model,
                                    filterQuery: filterQuery,
                                    isDefault: model == (currentDefault ?? provider.defaultModelName),
                                    isProjectDefault: model == projectModel,
                                    hasProject: appState.configProjectPath != nil,
                                    onSetDefault: { setDefault(model) },
                                    onSetProjectDefault: { setProjectDefault(model) },
                                    onClearProjectDefault: { clearProjectDefault() }
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

    private func modelsForColumn(_ column: Int) -> [(offset: Int, element: String)] {
        Array(filteredModels.enumerated()).filter { $0.offset % 2 == column }
    }

    private var configList: some View {
        ScrollView {
            VStack(spacing: 0) {
                infoBanner

                LazyVStack(spacing: PoirotTheme.Spacing.md) {
                    ForEach(Array(filteredModels.enumerated()), id: \.element) { index, model in
                        ModelCard(
                            name: model,
                            filterQuery: filterQuery,
                            isDefault: model == (currentDefault ?? provider.defaultModelName),
                            isProjectDefault: model == projectModel,
                            hasProject: appState.configProjectPath != nil,
                            onSetDefault: { setDefault(model) },
                            onSetProjectDefault: { setProjectDefault(model) },
                            onClearProjectDefault: { clearProjectDefault() }
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

            Text(
                // swiftlint:disable:next line_length
                "The default model can also be set via the `ANTHROPIC_MODEL` environment variable, which takes precedence over ~/.claude/settings.json."
            )
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

    private func loadProjectModel() {
        guard let path = appState.configProjectPath else {
            projectModel = nil
            return
        }
        projectModel = ClaudeConfigLoader.loadProjectModel(projectPath: path)
    }

    private func setDefault(_ model: String) {
        Task.detached {
            SettingsWriter.setDefaultModel(model)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentDefault = model
                }
                appState.showToast("Set **\(model)** as default model", icon: "star.fill")
            }
        }
    }

    private func setProjectDefault(_ model: String) {
        guard let path = appState.configProjectPath else { return }
        Task.detached {
            SettingsWriter.setProjectModel(model, projectPath: path)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    projectModel = model
                }
                appState.showToast(
                    "Set **\(model)** as project default",
                    icon: "folder.fill"
                )
            }
        }
    }

    private func clearProjectDefault() {
        guard let path = appState.configProjectPath else { return }
        Task.detached {
            SettingsWriter.setProjectModel(nil, projectPath: path)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    projectModel = nil
                }
                appState.showToast("Cleared project model override", icon: "folder.badge.minus")
            }
        }
    }
}

// MARK: - Model Card

private struct ModelCard: View {
    let name: String
    var filterQuery: String = ""
    let isDefault: Bool
    let isProjectDefault: Bool
    let hasProject: Bool
    let onSetDefault: () -> Void
    let onSetProjectDefault: () -> Void
    let onClearProjectDefault: () -> Void
    @State
    private var isHovered = false

    private var modelDescription: String {
        switch name {
        case "Opus 4":
            "Most capable model for complex reasoning, analysis, and multi-step tasks"
        case "Sonnet 4":
            "Balanced performance for everyday coding and conversation"
        case "Haiku 3.5":
            "Fastest model for quick responses and lightweight tasks"
        default:
            ""
        }
    }

    private var modelStrengths: [String] {
        switch name {
        case "Opus 4":
            ["Complex multi-step reasoning", "Large codebase analysis", "Architecture design", "Nuanced debugging"]
        case "Sonnet 4":
            ["Fast interactive coding", "Code generation", "Refactoring", "Everyday tasks"]
        case "Haiku 3.5":
            ["Fastest response time", "Simple lookups", "Quick edits", "Low-latency workflows"]
        default:
            []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Text(HighlightedText.fuzzyAttributedString(name, query: filterQuery))
                    .font(PoirotTheme.Typography.bodyMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)

                if isDefault {
                    HStack(spacing: PoirotTheme.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .font(PoirotTheme.Typography.nano)
                        Text("Global Default")
                            .font(PoirotTheme.Typography.tiny)
                    }
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .padding(.horizontal, PoirotTheme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(PoirotTheme.Colors.accentDim))
                }

                if isProjectDefault {
                    HStack(spacing: PoirotTheme.Spacing.xs) {
                        Image(systemName: "folder.fill")
                            .font(PoirotTheme.Typography.nano)
                        Text("Project Default")
                            .font(PoirotTheme.Typography.tiny)
                    }
                    .foregroundStyle(PoirotTheme.Colors.green)
                    .padding(.horizontal, PoirotTheme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(PoirotTheme.Colors.green.opacity(0.12)))
                }

                Spacer()
            }

            if !modelDescription.isEmpty {
                Text(modelDescription)
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            if !modelStrengths.isEmpty {
                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                    ForEach(modelStrengths, id: \.self) { strength in
                        HStack(spacing: PoirotTheme.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(PoirotTheme.Typography.micro)
                                .foregroundStyle(PoirotTheme.Colors.green)
                            Text(strength)
                                .font(PoirotTheme.Typography.tiny)
                                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        }
                    }
                }
                .padding(.top, PoirotTheme.Spacing.xs)
            }

            if !isDefault || (hasProject && !isProjectDefault) || isProjectDefault {
                Divider().opacity(0.2)

                HStack(spacing: PoirotTheme.Spacing.md) {
                    if !isDefault {
                        Button {
                            onSetDefault()
                        } label: {
                            HStack(spacing: PoirotTheme.Spacing.xs) {
                                Image(systemName: "star")
                                    .font(PoirotTheme.Typography.micro)
                                Text("Set as Default")
                                    .font(PoirotTheme.Typography.tiny)
                            }
                            .foregroundStyle(PoirotTheme.Colors.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Set as global default")
                    }

                    if hasProject, !isProjectDefault {
                        Button {
                            onSetProjectDefault()
                        } label: {
                            HStack(spacing: PoirotTheme.Spacing.xs) {
                                Image(systemName: "folder.badge.plus")
                                    .font(PoirotTheme.Typography.micro)
                                Text("Set as Project Default")
                                    .font(PoirotTheme.Typography.tiny)
                            }
                            .foregroundStyle(PoirotTheme.Colors.green)
                        }
                        .buttonStyle(.plain)
                        .help("Set as project default")
                    }

                    if isProjectDefault {
                        Button {
                            onClearProjectDefault()
                        } label: {
                            HStack(spacing: PoirotTheme.Spacing.xs) {
                                Image(systemName: "folder.badge.minus")
                                    .font(PoirotTheme.Typography.micro)
                                Text("Clear Project Override")
                                    .font(PoirotTheme.Typography.tiny)
                            }
                            .foregroundStyle(PoirotTheme.Colors.red)
                        }
                        .buttonStyle(.plain)
                        .help("Clear project override")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PoirotTheme.Spacing.lg)
        .cardChrome(isHovered: isHovered)
        .onHover { isHovered = $0 }
    }
}
