import SwiftUI

struct ShortcutHelpView: View {
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            ScrollView {
                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xl) {
                    globalSection
                    navigationSection
                }
                .padding(PoirotTheme.Spacing.xxl)
            }
        }
        .frame(width: 480, height: 560)
        .background(PoirotTheme.Colors.bgApp)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "keyboard")
                .font(PoirotTheme.Typography.heading)
                .foregroundStyle(PoirotTheme.Colors.accent)
                .symbolRenderingMode(.hierarchical)

            Text("Keyboard Shortcuts")
                .font(PoirotTheme.Typography.heading)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(PoirotTheme.Typography.body)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(PoirotTheme.Spacing.xl)
    }

    // MARK: - Sections

    private var globalSection: some View {
        shortcutSection("Global", icon: "globe") {
            shortcutRow("Universal Search", keys: "\u{2318}K")
            shortcutRow("Toggle Tool Filter", keys: "\u{2318}T")
            shortcutRow("Dismiss / Go Back", keys: "Esc")
        }
    }

    private var navigationSection: some View {
        shortcutSection("Navigation", icon: "arrow.left.arrow.right") {
            shortcutRow("Navigate Back", keys: "\u{2318}[")
            shortcutRow("Navigate Forward", keys: "\u{2318}]")
            shortcutRow("Increase Font", keys: "\u{2318}+")
            shortcutRow("Decrease Font", keys: "\u{2318}\u{2212}")
            shortcutRow("Reset Font", keys: "\u{2318}0")
            shortcutRow("Settings", keys: "\u{2318},")
        }
    }

    // MARK: - Helpers

    private func shortcutSection<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            VStack(spacing: PoirotTheme.Spacing.xs) {
                content()
            }
            .padding(PoirotTheme.Spacing.md)
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

    private func shortcutRow(_ label: String, keys: String) -> some View {
        HStack {
            Text(label)
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)

            Spacer()

            HStack(spacing: PoirotTheme.Spacing.xxs) {
                ForEach(keys.components(separatedBy: " / "), id: \.self) { key in
                    Text(key)
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
        }
    }
}
