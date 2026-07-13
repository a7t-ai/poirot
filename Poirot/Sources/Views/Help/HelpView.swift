import SwiftUI

struct HelpView: View {
    @State
    private var showShortcuts = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxl) {
                headerSection
                keyboardShortcutsSection
                featuresSection
                configSection
            }
            .padding(PoirotTheme.Spacing.xxxl)
        }
        .frame(width: 540, height: 620)
        .background(PoirotTheme.Colors.bgApp)
        .sheet(isPresented: $showShortcuts) {
            ShortcutHelpView()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.md) {
                Image(systemName: "questionmark.circle.fill")
                    .font(PoirotTheme.Typography.title)
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .symbolRenderingMode(.hierarchical)

                Text("Poirot Help")
                    .font(PoirotTheme.Typography.heroTitle)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
            }

            Text("A native macOS companion for Claude Code")
                .font(PoirotTheme.Typography.body)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
        }
    }

    // MARK: - Keyboard Shortcuts

    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.md) {
            HStack {
                sectionHeader("Keyboard Shortcuts", icon: "keyboard")
                Spacer()
                Button {
                    showShortcuts = true
                } label: {
                    Label("Show All", systemImage: "rectangle.on.rectangle")
                        .font(PoirotTheme.Typography.caption)
                }
                .buttonStyle(.plain)
                .help("Show all keyboard shortcuts")
                .foregroundStyle(PoirotTheme.Colors.accent)
            }

            VStack(spacing: PoirotTheme.Spacing.xs) {
                shortcutRow("Universal Search", keys: "\u{2318}K")
                shortcutRow("Navigate Back", keys: "\u{2318}[")
                shortcutRow("Navigate Forward", keys: "\u{2318}]")
                shortcutRow("Toggle Tool Filter", keys: "\u{2318}T")
                Divider().opacity(0.2)
                shortcutRow("Move Up/Down", keys: "\u{2191} / \u{2193}")
                shortcutRow("Open / Activate", keys: "Return")
                Divider().opacity(0.2)
                shortcutRow("Increase Font Size", keys: "\u{2318}+")
                shortcutRow("Decrease Font Size", keys: "\u{2318}\u{2212}")
                shortcutRow("Reset Font Size", keys: "\u{2318}0")
                Divider().opacity(0.2)
                shortcutRow("Settings", keys: "\u{2318},")
                shortcutRow("Dismiss Overlay", keys: "ESC")
            }
            .padding(PoirotTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                    .fill(PoirotTheme.Colors.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                            .strokeBorder(PoirotTheme.Colors.border.opacity(0.3))
                    )
            )
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.md) {
            sectionHeader("Features", icon: "star")

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
                featureRow("Session Browser", "Browse and search conversation history grouped by project")
                featureRow("Session Detail", "Rich timeline with markdown, code diffs, and tool output")
                featureRow("Universal Search", "Search across sessions, commands, skills, and more")
                featureRow("Configuration", "Manage commands, skills, MCP servers, models, and plugins")
                featureRow("Live Reload", "Auto-refreshes when session files change on disk")
                featureRow("Editor Integration", "Open files directly in VS Code, Cursor, Xcode, or Zed")
            }
            .padding(PoirotTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                    .fill(PoirotTheme.Colors.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                            .strokeBorder(PoirotTheme.Colors.border.opacity(0.3))
                    )
            )
        }
    }

    // MARK: - Config

    private var configSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.md) {
            sectionHeader("Getting Started", icon: "arrow.right.circle")

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
                Text(
                    // swiftlint:disable:next line_length
                    "Poirot reads session transcripts from **~/.claude/projects/**. Use Claude Code CLI normally — Poirot will automatically discover and display your sessions."
                )
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                .lineSpacing(PoirotTheme.Spacing.xxs)

                Text(
                    // swiftlint:disable:next line_length
                    "Configure your preferred text editor and terminal in **Settings** (\u{2318},) to enable one-click file opening and command re-runs."
                )
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                .lineSpacing(PoirotTheme.Spacing.xxs)
            }
            .padding(PoirotTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                    .fill(PoirotTheme.Colors.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                            .strokeBorder(PoirotTheme.Colors.border.opacity(0.3))
                    )
            )
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(PoirotTheme.Typography.body)
                .foregroundStyle(PoirotTheme.Colors.accent)
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(PoirotTheme.Typography.headingSmall)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)
        }
    }

    private func shortcutRow(_ label: String, keys: String) -> some View {
        HStack {
            Text(label)
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)

            Spacer()

            Text(keys)
                .font(PoirotTheme.Typography.code)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)
                .padding(.horizontal, PoirotTheme.Spacing.sm)
                .padding(.vertical, PoirotTheme.Spacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                        .fill(PoirotTheme.Colors.bgElevated)
                )
        }
    }

    private func featureRow(_ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(PoirotTheme.Typography.micro)
                .foregroundStyle(PoirotTheme.Colors.green)
                .padding(.top, PoirotTheme.Spacing.xxs)

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                Text(title)
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)

                Text(description)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
    }
}
