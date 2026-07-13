import SwiftUI

struct ThemePicker: View {
    @Binding
    var selection: ColorTheme
    @State
    private var preHoverSelection: ColorTheme?

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ColorTheme.allCases, id: \.self) { theme in
                ThemeOption(
                    theme: theme,
                    isSelected: selection == theme
                ) {
                    preHoverSelection = nil
                    selection = theme
                }
                .onHover { hovering in
                    if hovering {
                        if preHoverSelection == nil {
                            preHoverSelection = selection
                        }
                        ColorThemeStorage.current = theme
                    }
                }
            }
        }
        .onHover { hovering in
            if !hovering, let original = preHoverSelection {
                ColorThemeStorage.current = original
                preHoverSelection = nil
            }
        }
    }
}

// MARK: - Option

private struct ThemeOption: View {
    let theme: ColorTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ThemeThumbnail(palette: theme.palette)
                    .frame(width: 96, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 2.5 : 0.5
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                Text(theme.label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(theme.label)
    }
}

// MARK: - Thumbnail

private struct ThemeThumbnail: View {
    let palette: ThemePalette

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 3) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hex: palette.textTertiary.lightHex).opacity(0.5))
                        .frame(width: 14, height: 2)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hex: palette.textTertiary.lightHex).opacity(0.3))
                        .frame(width: 10, height: 2)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hex: palette.textTertiary.lightHex).opacity(0.3))
                        .frame(width: 12, height: 2)
                }
                .padding(4)
                .frame(maxWidth: 24, maxHeight: .infinity)
                .background(Color(hex: palette.bgSidebar.darkHex))

                // Main content
                VStack(alignment: .leading, spacing: 3) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hex: palette.textPrimary.darkHex))
                        .frame(width: 30, height: 2)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hex: palette.textSecondary.darkHex).opacity(0.6))
                        .frame(width: 40, height: 2)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: palette.bgCard.darkHex))
                        .frame(height: 14)
                        .overlay(
                            VStack(alignment: .leading, spacing: 2) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color(hex: palette.textSecondary.darkHex).opacity(0.5))
                                    .frame(width: 28, height: 1.5)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color(hex: palette.textTertiary.darkHex).opacity(0.3))
                                    .frame(width: 36, height: 1.5)
                            }
                            .padding(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        )

                    Spacer(minLength: 0)
                }
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: palette.bgApp.darkHex))
            }
        }
    }
}
