import MarkdownUI
import SwiftUI

struct SystemContentView: View {
    let blocks: [SystemContentParser.SystemBlock]

    @State
    private var isExpanded = false

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .opacity(0.3)
                .padding(.bottom, PoirotTheme.Spacing.sm)

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: PoirotTheme.Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(PoirotTheme.Typography.micro)

                    Text("System context (\(blocks.count))")
                        .font(PoirotTheme.Typography.tiny)

                    Image(systemName: "chevron.down")
                        .font(PoirotTheme.Typography.picoSemibold)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .padding(.horizontal, PoirotTheme.Spacing.md)
                .padding(.vertical, PoirotTheme.Spacing.xs)
                .background(
                    Capsule()
                        .fill(PoirotTheme.Colors.bgCode.opacity(0.5))
                        .overlay(
                            Capsule()
                                .stroke(PoirotTheme.Colors.borderSubtle)
                        )
                )
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse system context" : "Expand system context")
            .onAppear {
                isExpanded = UserDefaults.standard.bool(forKey: "autoExpandBlocks")
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
                    ForEach(blocks) { block in
                        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                            Text(block.tagName)
                                .font(PoirotTheme.Typography.codeMicro)
                                .foregroundStyle(PoirotTheme.Colors.accent)
                                .padding(.horizontal, PoirotTheme.Spacing.xs)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                                        .fill(PoirotTheme.Colors.accentDim)
                                )

                            SystemBlockContentView(content: block.content)
                        }
                    }
                }
                .padding(PoirotTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgCode)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(PoirotTheme.Colors.borderSubtle)
                        )
                )
                .padding(.top, PoirotTheme.Spacing.sm)
            }
        }
        .padding(.top, PoirotTheme.Spacing.md)
    }
}

// MARK: - Block Content (parses inner XML fields)

private struct SystemBlockContentView: View {
    let content: String

    @AppStorage("parseMarkdownInResults")
    private var parseMarkdown = true

    private var innerParsed: SystemContentParser.Result {
        SystemContentParser.parse(content)
    }

    var body: some View {
        let parsed = innerParsed

        if !parsed.systemBlocks.isEmpty {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                if !parsed.userText.isEmpty {
                    fieldValue(parsed.userText)
                }

                ForEach(parsed.systemBlocks) { field in
                    VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                        Text(field.tagName)
                            .font(PoirotTheme.Typography.codeNano)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary.opacity(0.7))

                        fieldValue(field.content)
                    }
                }
            }
        } else {
            fieldValue(content)
        }
    }

    @ViewBuilder
    private func fieldValue(_ text: String) -> some View {
        let beautified = JSONBeautifier.beautify(text)

        if parseMarkdown {
            Markdown(beautified)
                .markdownTheme(.poirot)
                .textSelection(.enabled)
                .linkCursorIfNeeded(beautified)
        } else {
            Text(beautified)
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .lineSpacing(PoirotTheme.Spacing.xxs)
                .textSelection(.enabled)
        }
    }
}
