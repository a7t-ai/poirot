import HighlightSwift
@preconcurrency import MarkdownUI
import SwiftUI

extension Theme {
    @MainActor
    static let poirot = Theme()
        .text {
            ForegroundColor(PoirotTheme.Colors.textPrimary)
            FontSize(14 * PoirotTheme.Typography.scale)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(12 * PoirotTheme.Typography.scale)
            ForegroundColor(PoirotTheme.Colors.accent)
            BackgroundColor(PoirotTheme.Colors.bgCode)
        }
        .strong {
            FontWeight(.semibold)
        }
        .link {
            ForegroundColor(PoirotTheme.Colors.accent)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(18 * PoirotTheme.Typography.scale)
                    ForegroundColor(PoirotTheme.Colors.textPrimary)
                }
                .markdownMargin(top: 16, bottom: 12)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(16 * PoirotTheme.Typography.scale)
                    ForegroundColor(PoirotTheme.Colors.textPrimary)
                }
                .markdownMargin(top: 16, bottom: 10)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(14 * PoirotTheme.Typography.scale)
                    ForegroundColor(PoirotTheme.Colors.textPrimary)
                }
                .markdownMargin(top: 14, bottom: 8)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(PoirotTheme.Colors.accent)
                    .frame(width: 3)

                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(PoirotTheme.Colors.textSecondary)
                        FontStyle(.italic)
                    }
                    .padding(.leading, 12)
            }
            .markdownMargin(top: 8, bottom: 8)
        }
        .codeBlock { configuration in
            PoirotCodeBlockView(configuration: configuration)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 0, bottom: 8)
                .lineSpacing(4)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(13 * PoirotTheme.Typography.scale)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
        }
}

// MARK: - Code Block with Syntax Highlighting

struct PoirotCodeBlockView: View {
    let configuration: CodeBlockConfiguration

    @State
    private var attributedCode: AttributedString?

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = configuration.language {
                HStack {
                    Text(language)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(PoirotTheme.Colors.bgElevated)
            }

            Group {
                if let attributedCode {
                    Text(attributedCode)
                } else {
                    Text(configuration.content)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)
                }
            }
            .font(PoirotTheme.Typography.code)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .background(PoirotTheme.Colors.bgCode)
        .clipShape(RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                .stroke(PoirotTheme.Colors.border)
        )
        .task(id: HighlightRequest(content: configuration.content, isDark: colorScheme == .dark)) {
            await highlight(
                code: configuration.content,
                language: configuration.language,
                isDark: colorScheme == .dark
            )
        }
    }

    private func highlight(code: String, language: String?, isDark: Bool) async {
        guard let lang = language else { return }

        do {
            let result = try await PoirotHighlight.shared.request(
                code,
                mode: .languageAlias(lang),
                // Match the syntax palette to the appearance — the dark xcode theme's near-white
                // tokens were unreadable on the light-mode code background.
                colors: isDark ? .dark(.xcode) : .light(.xcode)
            )
            attributedCode = result.attributedText
        } catch {
            // Fall back to plain text on error
        }
    }
}

// MARK: - Highlight Singleton

private enum PoirotHighlight {
    static let shared = HighlightSwift.Highlight()
}

/// Keys the syntax-highlight task on both the code and the appearance, so switching light/dark
/// re-runs the highlighter with the matching palette.
private struct HighlightRequest: Hashable {
    let content: String
    let isDark: Bool
}
