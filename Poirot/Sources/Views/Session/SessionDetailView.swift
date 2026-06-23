import MarkdownUI
import SwiftUI

struct SessionDetailView: View {
    let session: Session

    private static let pageSize = 20

    @State
    private var visibleCount: Int = SessionDetailView.pageSize

    @State
    private var showScrollToBottom = false

    @State
    private var isLoadingMore = false

    @State
    private var todos: [SessionTodo] = []

    @State
    private var facets: SessionFacets?

    @Environment(AppState.self)
    private var appState

    @Environment(\.provider)
    private var provider

    @Environment(\.todoLoader)
    private var todoLoader

    @Environment(\.facetsLoader)
    private var facetsLoader

    private var filteredMessages: [Message] {
        var messages = session.messages

        // Text search filter
        let query = appState.sessionSearchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            messages = messages.filter { $0.textContent.lowercased().contains(query) }
        }

        // Tool type filter
        let filters = appState.activeToolFilters
        if !filters.isEmpty {
            let allMessages = messages
            var kept = Set<String>()

            // Keep assistant messages that contain matching tools
            for (index, message) in allMessages.enumerated() where message.role == .assistant {
                let hasMatch = message.toolBlocks.contains { filters.contains($0.name) }
                if hasMatch {
                    kept.insert(message.id)
                    // Also keep the preceding user message for context
                    if index > 0, allMessages[index - 1].role == .user {
                        kept.insert(allMessages[index - 1].id)
                    }
                }
            }

            messages = messages.filter { kept.contains($0.id) }
        }

        return messages
    }

    private var sessionToolNames: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for message in session.messages where message.role == .assistant {
            for tool in message.toolBlocks where seen.insert(tool.name).inserted {
                ordered.append(tool.name)
            }
        }
        return ordered
    }

    var body: some View {
        VStack(spacing: 0) {
            sessionHeader
            if appState.isToolFilterActive {
                toolFilterBar
            }
            if !todos.isEmpty {
                SessionTodosView(todos: todos)
                    .padding(.horizontal, PoirotTheme.Spacing.md)
                    .padding(.top, PoirotTheme.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let facets {
                SessionFacetsCard(facets: facets)
                    .padding(.horizontal, PoirotTheme.Spacing.md)
                    .padding(.top, PoirotTheme.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            messagesList
        }
        .animation(.easeInOut(duration: 0.2), value: appState.isToolFilterActive)
        .animation(.easeInOut(duration: 0.2), value: todos.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: facets != nil)
        .background(PoirotTheme.Colors.bgApp)
        .onChange(of: session.id) {
            visibleCount = Self.pageSize
            loadTodos()
            loadFacets()
        }
        .task {
            loadTodos()
            loadFacets()
        }
    }

    private func loadTodos() {
        let sessionId = session.id
        let loader = todoLoader
        todos = loader.loadTodos(for: sessionId)
    }

    private func loadFacets() {
        let sessionId = session.id
        let loader = facetsLoader
        facets = loader.loadFacets(for: sessionId)
    }

    // MARK: - Header

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.md) {
                Image(systemName: "rectangle.stack.fill")
                    .font(PoirotTheme.Typography.headingSmall)
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                            .fill(PoirotTheme.Colors.accent.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                    Text(session.title)
                        .font(PoirotTheme.Typography.heading)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: PoirotTheme.Spacing.xs) {
                        if let model = session.model {
                            Text(model)
                                .font(PoirotTheme.Typography.tiny)
                                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                                .padding(.horizontal, PoirotTheme.Spacing.sm)
                                .padding(.vertical, PoirotTheme.Spacing.xxs)
                                .background(
                                    Capsule().fill(PoirotTheme.Colors.bgElevated)
                                )
                        }

                        if session.totalTokens > 0 {
                            Text("\(session.totalTokens.formattedTokens) tokens")
                                .font(PoirotTheme.Typography.tiny)
                                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                                .padding(.horizontal, PoirotTheme.Spacing.sm)
                                .padding(.vertical, PoirotTheme.Spacing.xxs)
                                .background(
                                    Capsule().fill(PoirotTheme.Colors.bgElevated)
                                )
                        }
                    }
                }

                Spacer()
            }

            Text(
                "\(session.projectName) · \(session.timeAgo) · \(session.turnCount) \(session.turnCount == 1 ? "turn" : "turns")"
            )
            .font(PoirotTheme.Typography.caption)
            .foregroundStyle(PoirotTheme.Colors.textSecondary)

            let context = ContextUsage.from(session.messages)
            if !context.isEmpty {
                ConversationContextCard(context: context)
                    .padding(.top, PoirotTheme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PoirotTheme.Spacing.xxxl)
        .padding(.vertical, PoirotTheme.Spacing.xl)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.3)
        }
    }

    // MARK: - Tool Filter Bar

    private var toolFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                ForEach(sessionToolNames, id: \.self) { toolName in
                    let isActive = appState.activeToolFilters.contains(toolName)
                    Button {
                        if isActive {
                            appState.activeToolFilters.remove(toolName)
                        } else {
                            appState.activeToolFilters.insert(toolName)
                        }
                    } label: {
                        HStack(spacing: PoirotTheme.Spacing.xs) {
                            Image(systemName: provider.toolIcon(for: toolName))
                                .font(PoirotTheme.Typography.micro)
                            Text(provider.toolDisplayName(for: toolName))
                                .font(PoirotTheme.Typography.tiny)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, PoirotTheme.Spacing.md)
                        .padding(.vertical, 5)
                        .foregroundStyle(isActive ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textSecondary)
                        .background(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .fill(isActive ? PoirotTheme.Colors.accentDim : PoirotTheme.Colors.bgCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                        .stroke(
                                            isActive
                                                ? PoirotTheme.Colors.accent.opacity(0.3)
                                                : PoirotTheme.Colors.border
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !appState.activeToolFilters.isEmpty {
                    Button {
                        appState.activeToolFilters.removeAll()
                    } label: {
                        Text("Clear")
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PoirotTheme.Spacing.lg)
        }
        .padding(.vertical, PoirotTheme.Spacing.sm)
        .background {
            GlassBackground(in: .rect(cornerRadius: PoirotTheme.Radius.sm))
        }
        .overlay {
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                .stroke(PoirotTheme.Colors.border.opacity(0.3), lineWidth: 0.5)
        }
        .padding(.horizontal, PoirotTheme.Spacing.md)
        .padding(.top, PoirotTheme.Spacing.xs)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Messages

    private var messagesList: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    let messages = filteredMessages
                    if messages.isEmpty {
                        emptyState
                    } else {
                        Color.clear
                            .frame(height: 1)
                            .id("session-top")

                        let bubbleWidth = (geo.size.width - PoirotTheme.Spacing.xxxl * 2) * 0.75
                        let visible = Array(messages.prefix(visibleCount).enumerated())
                        let hasMore = visibleCount < messages.count
                        let toolResults = Self.buildToolResultLookup(session.messages)

                        LazyVStack(spacing: PoirotTheme.Spacing.lg) {
                            let query = appState.sessionSearchQuery.trimmingCharacters(in: .whitespaces)
                            ForEach(visible, id: \.offset) { index, message in
                                BubbleRow(
                                    message: message,
                                    turnNumber: index + 1,
                                    maxBubbleWidth: bubbleWidth,
                                    toolResults: toolResults,
                                    highlightQuery: query,
                                    activeToolFilters: appState.activeToolFilters
                                )
                            }

                            if hasMore {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
                                        isLoadingMore = true
                                        visibleCount += Self.pageSize
                                    }
                                    .onDisappear {
                                        isLoadingMore = false
                                    }
                            }
                        }
                        .padding(PoirotTheme.Spacing.xxxl)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    let distanceFromBottom = geometry.contentSize.height
                        - geometry.contentOffset.y
                        - geometry.containerSize.height
                    return distanceFromBottom > 100
                } action: { _, isScrolledUp in
                    showScrollToBottom = isScrolledUp
                }
                .overlay(alignment: .bottom) {
                    if showScrollToBottom || isLoadingMore {
                        Button {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        } label: {
                            Group {
                                if isLoadingMore {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.down")
                                        .font(PoirotTheme.Typography.bodyMedium)
                                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                                }
                            }
                            .frame(width: 36, height: 36) // scroll-to-bottom FAB
                            .background {
                                GlassBackground(in: .circle)
                            }
                            .overlay {
                                Circle()
                                    .stroke(PoirotTheme.Colors.border.opacity(0.3), lineWidth: 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, PoirotTheme.Spacing.md)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showScrollToBottom)
                .animation(.easeInOut(duration: 0.2), value: isLoadingMore)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: PoirotTheme.Spacing.md) {
            Image(systemName: "text.bubble")
                .font(PoirotTheme.Typography.heroTitle)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)

            Text("No messages to display")
                .font(PoirotTheme.Typography.bodyMedium)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)

            if let preview = session.preview {
                Text(preview)
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(6)
                    .frame(maxWidth: 400)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private static func buildToolResultLookup(_ messages: [Message]) -> [String: ToolResult] {
        var lookup: [String: ToolResult] = [:]
        for message in messages where message.role == .user {
            for result in message.toolResultBlocks {
                lookup[result.toolUseId] = result
            }
        }
        return lookup
    }
}

// MARK: - Bubble Row

private struct BubbleRow: View {
    let message: Message
    let turnNumber: Int
    let maxBubbleWidth: CGFloat
    let toolResults: [String: ToolResult]
    var highlightQuery: String = ""
    var activeToolFilters: Set<String> = []

    @Environment(\.provider)
    private var provider

    var body: some View {
        switch message.role {
        case .user:
            UserBubble(
                message: message,
                turnNumber: turnNumber,
                maxBubbleWidth: maxBubbleWidth,
                highlightQuery: highlightQuery
            )
        case .assistant:
            AssistantBubble(
                message: message,
                turnNumber: turnNumber,
                maxBubbleWidth: maxBubbleWidth,
                provider: provider,
                toolResults: toolResults,
                highlightQuery: highlightQuery,
                activeToolFilters: activeToolFilters
            )
        case .system:
            EmptyView()
        }
    }
}

// MARK: - User Bubble (right-aligned)

private struct UserBubble: View {
    let message: Message
    let turnNumber: Int
    let maxBubbleWidth: CGFloat
    var highlightQuery: String = ""

    @State
    private var isFormatted = true

    private var isHighlighting: Bool { !highlightQuery.isEmpty }

    var body: some View {
        let parsed = SystemContentParser.parse(message.textContent)

        HStack {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: PoirotTheme.Spacing.sm) {
                    Text("You")
                        .font(PoirotTheme.Typography.smallBold)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)

                    Text(message.timestamp, style: .time)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)

                    Text("#\(turnNumber)")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary.opacity(0.6))
                }
                .padding(.bottom, PoirotTheme.Spacing.sm)

                if !parsed.userText.isEmpty {
                    if isHighlighting {
                        Text(highlightedAttributedString(parsed.userText, query: highlightQuery))
                            .font(PoirotTheme.Typography.body)
                            .foregroundStyle(PoirotTheme.Colors.textPrimary)
                            .lineSpacing(PoirotTheme.Spacing.xs)
                            .textSelection(.enabled)
                    } else if isFormatted {
                        Markdown(parsed.userText)
                            .markdownTheme(.poirot)
                            .textSelection(.enabled)
                            .linkCursorIfNeeded(parsed.userText)
                    } else {
                        Text(parsed.userText)
                            .font(PoirotTheme.Typography.body)
                            .foregroundStyle(PoirotTheme.Colors.textPrimary)
                            .lineSpacing(PoirotTheme.Spacing.xs)
                            .textSelection(.enabled)
                    }
                } else if !message.toolResultBlocks.isEmpty {
                    ForEach(message.toolResultBlocks) { result in
                        ToolResultBlock(result: result)
                    }
                }

                if !parsed.systemBlocks.isEmpty {
                    SystemContentView(blocks: parsed.systemBlocks)
                }
            }
            .padding(PoirotTheme.Spacing.lg)
            .frame(width: maxBubbleWidth, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                    .fill(PoirotTheme.Colors.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                            .stroke(PoirotTheme.Colors.border)
                    )
            )
            .bubbleActions(
                text: copyableText(parsed: parsed),
                message: message,
                isFormatted: $isFormatted,
                showActions: !parsed.userText.isEmpty
            )
        }
    }

    private func copyableText(parsed: SystemContentParser.Result) -> String {
        if !parsed.userText.isEmpty {
            return parsed.userText
        }
        return message.toolResultBlocks
            .map(\.content)
            .joined(separator: "\n\n")
    }
}

// MARK: - Tool Result Block (inside user bubbles)

private struct ToolResultBlock: View {
    let result: ToolResult

    private static let truncatedLineCount = 80

    @AppStorage("wrapCodeLines")
    private var wrapLines = true

    @State
    private var isExpanded = false

    @State
    private var showAllLines = false

    @State
    private var showRawContent = true

    @State
    private var copied = false

    @State
    private var isContentHovered = false

    @State
    private var isButtonsHovered = false

    private var buttonOpacity: Double {
        isButtonsHovered ? 1.0 : (isContentHovered ? 0.15 : 0.5)
    }

    private var isMarkdownContent: Bool { true }

    private var formattedContent: String { JSONBeautifier.beautify(result.content) }
    private var contentLines: [String] { formattedContent.components(separatedBy: "\n") }
    private var isTruncatable: Bool { contentLines.count > Self.truncatedLineCount }

    private var displayedContent: String {
        if !showAllLines, isTruncatable {
            return contentLines.prefix(Self.truncatedLineCount).joined(separator: "\n")
        }
        return formattedContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: PoirotTheme.Spacing.sm) {
                    Image(systemName: result.isError ? "exclamationmark.triangle" : "checkmark.circle")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(result.isError ? PoirotTheme.Colors.red : PoirotTheme.Colors.green)

                    Text("Tool result")
                        .font(PoirotTheme.Typography.smallBold)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)

                    Spacer()

                    Text(result.isError ? "ERROR" : "OK")
                        .font(PoirotTheme.Typography.microSemibold)
                        .textCase(.uppercase)
                        .foregroundStyle(result.isError ? PoirotTheme.Colors.red : PoirotTheme.Colors.green)
                        .padding(.horizontal, PoirotTheme.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                                .fill(
                                    (result.isError ? PoirotTheme.Colors.red : PoirotTheme.Colors.green)
                                        .opacity(0.1)
                                )
                        )

                    Image(systemName: "chevron.right")
                        .font(PoirotTheme.Typography.nanoSemibold)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, PoirotTheme.Spacing.md)
                .padding(.vertical, PoirotTheme.Spacing.xs)
            }
            .buttonStyle(.plain)

            if isExpanded, !result.content.isEmpty {
                Divider().opacity(0.3)

                VStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        resultContent
                            .padding(PoirotTheme.Spacing.md)

                        HStack(spacing: PoirotTheme.Spacing.xs) {
                            markdownToggleButton
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
                    }
                }
                .background(PoirotTheme.Colors.bgCode)
            }
        }
        .background(PoirotTheme.Colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                .stroke(result.isError ? PoirotTheme.Colors.red.opacity(0.2) : PoirotTheme.Colors.border)
        )
        .onAppear {
            isExpanded = UserDefaults.standard.bool(forKey: "autoExpandBlocks")
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if isMarkdownContent, !showRawContent {
            Markdown(displayedContent)
                .markdownTheme(.poirot)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let codeText = Text(displayedContent)
                .font(PoirotTheme.Typography.code)
                .foregroundStyle(
                    result.isError
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

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.content, forType: .string)
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
}

// MARK: - Assistant Bubble (left-aligned)

private struct AssistantBubble: View {
    let message: Message
    let turnNumber: Int
    let maxBubbleWidth: CGFloat
    let provider: any ProviderDescribing
    let toolResults: [String: ToolResult]
    var highlightQuery: String = ""
    var activeToolFilters: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            ForEach(
                Array(message.textAndToolSegments.enumerated()),
                id: \.offset
            ) { index, segment in
                switch segment {
                case let .text(text):
                    HStack(alignment: .top, spacing: PoirotTheme.Spacing.md) {
                        if index == 0 {
                            avatarView
                        } else {
                            Spacer().frame(width: 28) // avatar width alignment
                        }
                        AssistantTextBubble(
                            text: text,
                            message: message,
                            isFirst: index == 0,
                            turnNumber: turnNumber,
                            timestamp: message.timestamp,
                            maxBubbleWidth: maxBubbleWidth,
                            provider: provider,
                            highlightQuery: highlightQuery
                        )
                        Spacer(minLength: 0)
                    }
                case let .tools(tools):
                    let filtered = activeToolFilters.isEmpty
                        ? tools
                        : tools.filter { activeToolFilters.contains($0.name) }
                    if !filtered.isEmpty {
                        HStack(alignment: .top, spacing: PoirotTheme.Spacing.md) {
                            if index == 0 {
                                avatarView
                            } else {
                                Spacer().frame(width: 28) // avatar width alignment
                            }
                            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                                ForEach(filtered) { tool in
                                    ToolBlockView(tool: tool, result: toolResults[tool.id])
                                }
                            }
                            .frame(maxWidth: maxBubbleWidth)
                            Spacer(minLength: 0)
                        }
                    }
                case let .thinking(text):
                    HStack(alignment: .top, spacing: PoirotTheme.Spacing.md) {
                        if index == 0 {
                            avatarView
                        } else {
                            Spacer().frame(width: 28) // avatar width alignment
                        }
                        ThinkingBlockView(text: text)
                            .frame(maxWidth: maxBubbleWidth, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var avatarView: some View {
        Text(provider.assistantAvatarLetter)
            .font(PoirotTheme.Typography.smallBold)
            .foregroundStyle(PoirotTheme.Colors.accent)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                    .fill(PoirotTheme.Colors.accentDim)
            )
    }
}

// MARK: - Assistant Text Bubble

private struct AssistantTextBubble: View {
    let text: String
    let message: Message
    let isFirst: Bool
    let turnNumber: Int
    let timestamp: Date
    let maxBubbleWidth: CGFloat
    let provider: any ProviderDescribing
    var highlightQuery: String = ""

    @State
    private var isFormatted = true

    private var isHighlighting: Bool { !highlightQuery.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isFirst {
                HStack(spacing: PoirotTheme.Spacing.sm) {
                    Text(provider.assistantName)
                        .font(PoirotTheme.Typography.smallBold)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)

                    Text(timestamp, style: .time)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)

                    Text("#\(turnNumber)")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary.opacity(0.6))
                }
                .padding(.bottom, PoirotTheme.Spacing.sm)
            }

            if isHighlighting {
                Text(highlightedAttributedString(text, query: highlightQuery))
                    .font(PoirotTheme.Typography.body)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .lineSpacing(PoirotTheme.Spacing.xs)
                    .textSelection(.enabled)
            } else if isFormatted {
                Markdown(text)
                    .markdownTheme(.poirot)
                    .textSelection(.enabled)
                    .linkCursorIfNeeded(text)
            } else {
                Text(text)
                    .font(PoirotTheme.Typography.body)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .lineSpacing(PoirotTheme.Spacing.xs)
                    .textSelection(.enabled)
            }
        }
        .padding(PoirotTheme.Spacing.lg)
        .frame(width: maxBubbleWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .fill(PoirotTheme.Colors.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                        .stroke(PoirotTheme.Colors.border)
                )
        )
        .bubbleActions(text: text, message: message, isFormatted: $isFormatted)
    }
}

// MARK: - Bubble Action Buttons

private struct BubbleActionButtons: View {
    let text: String
    var message: Message?
    @Binding
    var isFormatted: Bool

    @State
    private var copied = false
    @State
    private var markdownCopied = false

    var body: some View {
        HStack(spacing: PoirotTheme.Spacing.xs) {
            // Format toggle
            BubbleIconButton(
                icon: isFormatted ? "doc.plaintext" : "doc.richtext",
                isActive: isFormatted,
                activeColor: PoirotTheme.Colors.accent
            ) {
                isFormatted.toggle()
            }

            // Copy as Markdown
            if let message {
                BubbleIconButton(
                    icon: markdownCopied ? "checkmark" : "doc.text",
                    isActive: markdownCopied,
                    activeColor: PoirotTheme.Colors.green,
                    help: "Copy as Markdown"
                ) {
                    let md = SessionExporter.messageToMarkdown(message)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(md, forType: .string)
                    markdownCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        markdownCopied = false
                    }
                }
            }

            // Copy raw text
            BubbleIconButton(
                icon: copied ? "checkmark" : "doc.on.doc",
                isActive: copied,
                activeColor: PoirotTheme.Colors.green
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            }
        }
    }
}

private struct BubbleIconButton: View {
    let icon: String
    let isActive: Bool
    let activeColor: Color
    var help: String? = nil
    let action: () -> Void

    @State
    private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(isActive ? activeColor : PoirotTheme.Colors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .stroke(isActive ? activeColor.opacity(0.3) : PoirotTheme.Colors.border)
                        )
                )
        }
        .buttonStyle(.plain)
        .help(help ?? "")
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

private extension View {
    func bubbleActions(
        text: String,
        message: Message? = nil,
        isFormatted: Binding<Bool>,
        showActions: Bool = true
    ) -> some View {
        BubbleActionsWrapper(text: text, message: message, showActions: showActions, isFormatted: isFormatted) { self }
    }
}

private struct BubbleActionsWrapper<Content: View>: View {
    let text: String
    var message: Message?
    let showActions: Bool
    @Binding
    var isFormatted: Bool
    @ViewBuilder
    let content: Content

    @State
    private var isContentHovered = false

    @State
    private var isButtonsHovered = false

    private var buttonOpacity: Double {
        isButtonsHovered ? 1.0 : (isContentHovered ? 0.15 : 0.5)
    }

    var body: some View {
        if showActions {
            content
                .onHover { isContentHovered = $0 }
                .overlay(alignment: .topTrailing) {
                    BubbleActionButtons(text: text, message: message, isFormatted: $isFormatted)
                        .opacity(buttonOpacity)
                        .onHover { isButtonsHovered = $0 }
                        .animation(.easeInOut(duration: 0.15), value: buttonOpacity)
                        .padding(PoirotTheme.Spacing.xs)
                }
        } else {
            content
        }
    }
}

// MARK: - Token Formatting

extension Int {
    var formattedTokens: String {
        let value = Double(self)
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return "\(self)"
    }
}

// MARK: - Search Highlighting

private func highlightedAttributedString(_ text: String, query: String) -> AttributedString {
    HighlightedText.attributedString(text, query: query)
}

// MARK: - Shell Escaping

extension String {
    var shellEscaped: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
