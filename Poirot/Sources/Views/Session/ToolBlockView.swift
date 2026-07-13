import MarkdownUI
import SwiftUI

struct ToolBlockView: View {
    let tool: ToolUse
    var result: ToolResult?

    private static let truncatedLineCount = 80

    @Environment(AppState.self)
    private var appState
    @Environment(\.provider)
    private var provider
    @AppStorage("wrapCodeLines")
    private var wrapLines = true
    @State
    private var isExpanded = false
    @State
    private var showAllLines = false
    @AppStorage("textEditor")
    private var textEditor = PreferredEditor.vscode.rawValue
    @AppStorage("openTerminalOnBash")
    private var openTerminalOnBash = false
    @AppStorage("preferredTerminal")
    private var preferredTerminal = PreferredTerminal.terminal.rawValue
    @State
    private var copied = false
    @State
    private var commandCopied = false
    @State
    private var markdownCopied = false
    @State
    private var showRawContent = true
    @State
    private var isContentHovered = false
    @State
    private var isButtonsHovered = false

    private var buttonOpacity: Double {
        isButtonsHovered ? 1.0 : (isContentHovered ? 0.15 : 0.5)
    }

    private var isError: Bool { result?.isError == true }
    private var preferredEditorName: String { (PreferredEditor(rawValue: textEditor) ?? .vscode).displayName }
    private var preferredTerminalName: String {
        (PreferredTerminal(rawValue: preferredTerminal) ?? .terminal).displayName
    }

    private var isMarkdownContent: Bool { !tool.isBash }

    private var formattedContent: String {
        guard let content = result?.content, !content.isEmpty else { return "" }
        return JSONBeautifier.beautify(content)
    }

    private var contentLines: [String] { formattedContent.components(separatedBy: "\n") }
    private var isTruncatable: Bool { contentLines.count > Self.truncatedLineCount }

    private var displayedContent: String {
        let content = formattedContent
        guard !content.isEmpty else { return "" }
        if !showAllLines, isTruncatable {
            return contentLines.prefix(Self.truncatedLineCount).joined(separator: "\n")
        }
        return content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: PoirotTheme.Spacing.sm) {
                    Image(systemName: provider.toolIcon(for: tool.name))
                        .font(PoirotTheme.Typography.small)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)

                    Text(provider.toolDisplayName(for: tool.name))
                        .font(PoirotTheme.Typography.smallBold)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)

                    if tool.isBash, let command = tool.command {
                        Text("$ \(command)")
                            .font(PoirotTheme.Typography.codeSmall)
                            .foregroundStyle(PoirotTheme.Colors.textSecondary)
                            .lineLimit(1)
                    } else if let path = tool.filePath {
                        Text(path)
                            .font(PoirotTheme.Typography.codeSmall)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary)
                            .lineLimit(1)
                    }

                    if let path = tool.filePath, !tool.isBash {
                        Button {
                            let editor = PreferredEditor(rawValue: textEditor) ?? .vscode
                            EditorLauncher.open(filePath: path, editor: editor)
                        } label: {
                            Image(systemName: "arrow.up.forward.square")
                                .font(PoirotTheme.Typography.micro)
                                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Open in \(preferredEditorName)")
                    }

                    Spacer()

                    Text(tool.isBash ? (isError ? "Exit 1" : "Exit 0") : (isError ? "Error" : "Done"))
                        .font(PoirotTheme.Typography.microSemibold)
                        .textCase(.uppercase)
                        .foregroundStyle(isError ? PoirotTheme.Colors.red : PoirotTheme.Colors.green)
                        .padding(.horizontal, PoirotTheme.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                                .fill((isError ? PoirotTheme.Colors.red : PoirotTheme.Colors.green).opacity(0.1))
                        )

                    Image(systemName: "chevron.right")
                        .font(PoirotTheme.Typography.nanoSemibold)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, PoirotTheme.Spacing.lg)
                .padding(.vertical, PoirotTheme.Spacing.sm)
                .background(PoirotTheme.Colors.bgElevated)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse" : "Expand")

            if isExpanded {
                Divider().opacity(0.3)

                if tool.hasDiffData, let oldStr = tool.oldString, let newStr = tool.newString {
                    EditDiffView(oldString: oldStr, newString: newStr, filePath: tool.filePath)
                } else if let content = result?.content, !content.isEmpty {
                    VStack(spacing: 0) {
                        ZStack(alignment: .topTrailing) {
                            codeContent
                                .padding(PoirotTheme.Spacing.lg)

                            HStack(spacing: PoirotTheme.Spacing.xs) {
                                if tool.isBash, let command = tool.command {
                                    bashCommandButton(command: command)
                                }
                                if !tool.isBash {
                                    markdownToggleButton
                                }
                                markdownCopyButton
                                wrapToggleButton
                                copyButton(content: content)
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
                                    showAllLines.toggle()
                                }
                            } label: {
                                Text(showAllLines ? "Show less" : "Show all \(contentLines.count) lines")
                                    .font(PoirotTheme.Typography.tiny)
                                    .foregroundStyle(PoirotTheme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, PoirotTheme.Spacing.xs)
                            }
                            .buttonStyle(.plain)
                            .help(showAllLines ? "Show less" : "Show all \(contentLines.count) lines")
                        }
                    }
                    .background(PoirotTheme.Colors.bgCode)
                } else {
                    Text("No output")
                        .font(PoirotTheme.Typography.code)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(PoirotTheme.Spacing.lg)
                        .background(PoirotTheme.Colors.bgCode)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PoirotTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .stroke(isError ? PoirotTheme.Colors.red.opacity(0.2) : PoirotTheme.Colors.border)
        )
        .onAppear {
            isExpanded = UserDefaults.standard.bool(forKey: "autoExpandBlocks")
        }
        .onChange(of: appState.allBlocksExpanded) {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded = appState.allBlocksExpanded }
        }
    }

    @ViewBuilder
    private var codeContent: some View {
        if isMarkdownContent, !showRawContent {
            Markdown(displayedContent)
                .markdownTheme(.poirot)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let codeText = Text(displayedContent)
                .font(PoirotTheme.Typography.code)
                .foregroundStyle(
                    isError
                        ? PoirotTheme.Colors.red.opacity(0.8)
                        : PoirotTheme.Colors.textSecondary
                )
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
    }

    private var markdownToggleButton: some View {
        Button {
            showRawContent.toggle()
        } label: {
            Image(systemName: showRawContent ? "doc.plaintext" : "doc.richtext")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(showRawContent ? PoirotTheme.Colors.textTertiary : PoirotTheme.Colors.accent)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(
                                    showRawContent
                                        ? PoirotTheme.Colors.border
                                        : PoirotTheme.Colors.accent.opacity(0.3)
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .help(showRawContent ? "Show rendered markdown" : "Show raw content")
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

    private var markdownCopyButton: some View {
        Button {
            let md = SessionExporter.toolBlockToMarkdown(tool: tool, result: result)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(md, forType: .string)
            markdownCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                markdownCopied = false
            }
        } label: {
            Image(systemName: markdownCopied ? "checkmark" : "doc.text")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(markdownCopied ? PoirotTheme.Colors.green : PoirotTheme.Colors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(
                                    markdownCopied
                                        ? PoirotTheme.Colors.green.opacity(0.3)
                                        : PoirotTheme.Colors.border
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Copy as Markdown")
        .animation(.easeInOut(duration: 0.2), value: markdownCopied)
    }

    private func copyButton(content: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
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
        .help("Copy content")
        .animation(.easeInOut(duration: 0.2), value: copied)
    }

    private func bashCommandButton(command: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            if openTerminalOnBash {
                let terminal = PreferredTerminal(rawValue: preferredTerminal) ?? .terminal
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    TerminalLauncher.open(terminal)
                }
            }
            commandCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                commandCopied = false
            }
        } label: {
            Image(systemName: commandCopied ? "checkmark" : "terminal")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(commandCopied ? PoirotTheme.Colors.green : PoirotTheme.Colors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(
                                    commandCopied
                                        ? PoirotTheme.Colors.green.opacity(0.3)
                                        : PoirotTheme.Colors.border
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .help(openTerminalOnBash ? "Copy and open \(preferredTerminalName)" : "Copy command")
        .animation(.easeInOut(duration: 0.2), value: commandCopied)
    }
}
