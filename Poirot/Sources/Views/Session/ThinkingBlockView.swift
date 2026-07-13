import SwiftUI

struct ThinkingBlockView: View {
    let text: String

    private static let truncatedLineCount = 50

    @AppStorage("wrapCodeLines")
    private var wrapLines = true

    @State
    private var isExpanded = false

    @State
    private var showAll = false

    @State
    private var copied = false

    @State
    private var isContentHovered = false

    @State
    private var isButtonsHovered = false

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var lines: [String] { text.components(separatedBy: "\n") }
    private var isTruncatable: Bool { lines.count > Self.truncatedLineCount }

    private var buttonOpacity: Double {
        isButtonsHovered ? 1.0 : (isContentHovered ? 0.15 : 0.5)
    }

    private var displayedText: String {
        if !showAll, isTruncatable {
            return lines.prefix(Self.truncatedLineCount).joined(separator: "\n")
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: PoirotTheme.Spacing.xs) {
                    Image(systemName: "brain.head.profile")
                        .font(PoirotTheme.Typography.micro)
                        .symbolRenderingMode(.hierarchical)
                        .symbolEffect(.breathe, isActive: !reduceMotion && isExpanded)

                    Text("Thinking")
                        .font(PoirotTheme.Typography.tiny)

                    Image(systemName: "chevron.down")
                        .font(PoirotTheme.Typography.picoSemibold)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .foregroundStyle(PoirotTheme.Colors.purple)
                .padding(.horizontal, PoirotTheme.Spacing.md)
                .padding(.vertical, PoirotTheme.Spacing.xs)
                .background(
                    Capsule()
                        .fill(PoirotTheme.Colors.purple.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(PoirotTheme.Colors.purple.opacity(0.2))
                        )
                )
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse thinking" : "Expand thinking")
            .onAppear {
                isExpanded = UserDefaults.standard.bool(forKey: "autoExpandBlocks")
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        thinkingContent
                            .padding(PoirotTheme.Spacing.md)

                        HStack(spacing: PoirotTheme.Spacing.xs) {
                            wrapToggleButton
                            copyButton
                        }
                        .opacity(buttonOpacity)
                        .onHover { isButtonsHovered = $0 }
                        .animation(.easeInOut(duration: 0.15), value: buttonOpacity)
                        .padding(PoirotTheme.Spacing.sm)
                    }
                    .onHover { isContentHovered = $0 }

                    if isTruncatable {
                        Divider().opacity(0.3)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAll.toggle()
                            }
                        } label: {
                            Text(showAll ? "Show less" : "Show all \(lines.count) lines")
                                .font(PoirotTheme.Typography.tiny)
                                .foregroundStyle(PoirotTheme.Colors.purple)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, PoirotTheme.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                        .help(showAll ? "Show less" : "Show all \(lines.count) lines")
                    }
                }
                .background(PoirotTheme.Colors.bgCode)
                .clipShape(RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .stroke(PoirotTheme.Colors.purple.opacity(0.15))
                )
                .padding(.top, PoirotTheme.Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private var thinkingContent: some View {
        let codeText = Text(displayedText)
            .font(PoirotTheme.Typography.code)
            .foregroundStyle(PoirotTheme.Colors.textTertiary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)

        if wrapLines {
            codeText
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                codeText
            }
        }
    }

    private var wrapToggleButton: some View {
        Button {
            wrapLines.toggle()
        } label: {
            Image(systemName: wrapLines ? "text.word.spacing" : "arrow.right.to.line")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(wrapLines ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(wrapLines ? PoirotTheme.Colors.accent.opacity(0.3) : PoirotTheme.Colors.border)
                        )
                )
        }
        .buttonStyle(.plain)
        .help(wrapLines ? "Disable line wrapping" : "Enable line wrapping")
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(copied ? PoirotTheme.Colors.green : PoirotTheme.Colors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(copied ? PoirotTheme.Colors.green.opacity(0.3) : PoirotTheme.Colors.border)
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Copy thinking")
        .animation(.easeInOut(duration: 0.2), value: copied)
    }
}
