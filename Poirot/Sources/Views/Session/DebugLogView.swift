import SwiftUI

struct DebugLogView: View {
    let sessionId: String
    var claudeDebugPath: String?

    @State
    private var entries: [DebugLogEntry] = []

    @State
    private var totalCount = 0

    @State
    private var isLoading = true

    @State
    private var isLoadingMore = false

    @State
    private var searchText = ""

    @State
    private var selectedLevels: Set<DebugLogEntry.Level> = Set(
        DebugLogEntry.Level.allCases
    )

    @State
    private var useRelativeTime = false

    @State
    private var firstErrorId: Int?

    @State
    private var copied = false

    @State
    private var scrollTarget: Int?

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var filteredEntries: [DebugLogEntry] {
        entries.filter { entry in
            guard selectedLevels.contains(entry.level) else {
                return false
            }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                return entry.message.lowercased().contains(query)
                    || entry.level.rawValue.lowercased().contains(query)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            toolbar
            Divider().opacity(0.3)
            logList
        }
        .frame(
            minWidth: 700,
            idealWidth: 800,
            minHeight: 500,
            idealHeight: 600
        )
        .background(PoirotTheme.Colors.bgApp)
        .task {
            await loadEntries()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: PoirotTheme.Spacing.md) {
            Image(systemName: "ladybug.fill")
                .font(PoirotTheme.Typography.headingSmall)
                .foregroundStyle(PoirotTheme.Colors.accent)
                .symbolEffect(
                    .bounce,
                    value: entries.count
                )
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(
                        cornerRadius: PoirotTheme.Radius.md
                    )
                    .fill(PoirotTheme.Colors.accent.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                Text("Debug Log")
                    .font(PoirotTheme.Typography.heading)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)

                HStack(spacing: PoirotTheme.Spacing.sm) {
                    Text("\(totalCount) entries")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)

                    let errorCount = entries.filter {
                        $0.level == .error
                    }.count
                    if errorCount > 0 {
                        HStack(spacing: PoirotTheme.Spacing.xxs) {
                            Image(
                                systemName: "exclamationmark.triangle.fill"
                            )
                            .font(PoirotTheme.Typography.micro)
                            Text("\(errorCount) errors")
                                .font(PoirotTheme.Typography.tiny)
                        }
                        .foregroundStyle(PoirotTheme.Colors.red)
                    }

                    let warnCount = entries.filter {
                        $0.level == .warn
                    }.count
                    if warnCount > 0 {
                        HStack(spacing: PoirotTheme.Spacing.xxs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(PoirotTheme.Typography.micro)
                            Text("\(warnCount) warnings")
                                .font(PoirotTheme.Typography.tiny)
                        }
                        .foregroundStyle(PoirotTheme.Colors.orange)
                    }
                }
            }

            Spacer()

            copyLogButton
            dismissButton
        }
        .padding(.horizontal, PoirotTheme.Spacing.xl)
        .padding(.vertical, PoirotTheme.Spacing.lg)
    }

    private var copyLogButton: some View {
        Button {
            copyFullLog()
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(PoirotTheme.Typography.small)
                .foregroundStyle(
                    copied
                        ? PoirotTheme.Colors.green
                        : PoirotTheme.Colors.textTertiary
                )
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(
                        cornerRadius: PoirotTheme.Radius.sm
                    )
                    .fill(PoirotTheme.Colors.bgElevated)
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: PoirotTheme.Radius.sm
                        )
                        .stroke(
                            copied
                                ? PoirotTheme.Colors.green.opacity(0.3)
                                : PoirotTheme.Colors.border
                        )
                    )
                )
        }
        .buttonStyle(.plain)
        .help("Copy Log")
        .animation(.easeInOut(duration: 0.2), value: copied)
    }

    private var dismissButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(PoirotTheme.Typography.small)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
        .buttonStyle(.plain)
        .help("Close")
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            searchField
            Spacer()
            levelFilters
            timeToggle
        }
        .padding(.horizontal, PoirotTheme.Spacing.lg)
        .padding(.vertical, PoirotTheme.Spacing.sm)
        .background(PoirotTheme.Colors.bgCard.opacity(0.5))
    }

    private var searchField: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(PoirotTheme.Typography.small)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)

            TextField("Filter log entries...", text: $searchText)
                .textFieldStyle(.plain)
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)

            if !searchText.isEmpty {
                Text("\(filteredEntries.count)/\(entries.count)")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .contentTransition(.numericText())

                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(PoirotTheme.Typography.small)
                        .foregroundStyle(
                            PoirotTheme.Colors.textTertiary
                        )
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, PoirotTheme.Spacing.sm)
        .padding(.vertical, PoirotTheme.Spacing.xs)
        .frame(maxWidth: 300)
    }

    private var levelFilters: some View {
        HStack(spacing: PoirotTheme.Spacing.xs) {
            ForEach(
                DebugLogEntry.Level.allCases,
                id: \.self
            ) { level in
                let isActive = selectedLevels.contains(level)
                Button {
                    if isActive {
                        selectedLevels.remove(level)
                    } else {
                        selectedLevels.insert(level)
                    }
                } label: {
                    Text(level.label)
                        .font(PoirotTheme.Typography.tiny)
                        .fontWeight(.medium)
                        .padding(.horizontal, PoirotTheme.Spacing.sm)
                        .frame(height: 26)
                        .foregroundStyle(
                            isActive
                                ? levelColor(level)
                                : PoirotTheme.Colors.textTertiary
                        )
                        .background(
                            RoundedRectangle(
                                cornerRadius: PoirotTheme.Radius.sm
                            )
                            .fill(
                                isActive
                                    ? levelColor(level).opacity(0.12)
                                    : PoirotTheme.Colors.bgCard
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: PoirotTheme.Radius.sm
                                )
                                .stroke(
                                    isActive
                                        ? levelColor(level).opacity(0.3)
                                        : PoirotTheme.Colors.border
                                )
                            )
                        )
                }
                .buttonStyle(.plain)
                .help(isActive ? "Hide \(level.label) entries" : "Show \(level.label) entries")
            }
        }
    }

    private var timeToggle: some View {
        Button {
            useRelativeTime.toggle()
        } label: {
            Image(
                systemName: useRelativeTime
                    ? "clock.arrow.circlepath" : "clock"
            )
            .font(PoirotTheme.Typography.small)
            .foregroundStyle(
                useRelativeTime
                    ? PoirotTheme.Colors.accent
                    : PoirotTheme.Colors.textTertiary
            )
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(
                    cornerRadius: PoirotTheme.Radius.sm
                )
                .fill(PoirotTheme.Colors.bgElevated)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: PoirotTheme.Radius.sm
                    )
                    .stroke(
                        useRelativeTime
                            ? PoirotTheme.Colors.accent.opacity(0.3)
                            : PoirotTheme.Colors.border
                    )
                )
            )
        }
        .buttonStyle(.plain)
        .help(
            useRelativeTime
                ? "Show absolute time"
                : "Show relative time"
        )
    }

    // MARK: - Log List

    private var hasMoreEntries: Bool {
        entries.count < totalCount
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoading {
                    logSkeleton
                        .transition(.opacity)
                } else if filteredEntries.isEmpty {
                    emptyState
                } else {
                    let visible = filteredEntries
                    LazyVStack(
                        alignment: .leading,
                        spacing: 0
                    ) {
                        ForEach(visible) { entry in
                            DebugLogEntryRow(
                                entry: entry,
                                useRelativeTime: useRelativeTime,
                                firstTimestamp: entries.first?.timestamp,
                                searchQuery: searchText
                            )
                            .id(entry.id)
                            .onAppear {
                                if entry.id == visible.last?.id, hasMoreEntries {
                                    Task { await loadMoreEntries() }
                                }
                            }
                        }

                        if hasMoreEntries {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(PoirotTheme.Colors.textTertiary)
                                Text("Loading more\u{2026}")
                                    .font(PoirotTheme.Typography.tiny)
                                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                                Spacer()
                            }
                            .padding(.vertical, PoirotTheme.Spacing.md)
                        }
                    }
                    .padding(.vertical, PoirotTheme.Spacing.xs)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isLoading)
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(target, anchor: .center)
                }
                scrollTarget = nil
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: PoirotTheme.Spacing.md) {
            if entries.isEmpty {
                Image(systemName: "doc.text")
                    .font(PoirotTheme.Typography.heroTitle)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)

                Text("No debug log found")
                    .font(PoirotTheme.Typography.bodyMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                Text("This session does not have a debug log file.")
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            } else {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(PoirotTheme.Typography.heroTitle)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)

                Text("No matching entries")
                    .font(PoirotTheme.Typography.bodyMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                Text("Adjust your filters or search query.")
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Skeleton

    private static let skeletonMessageWidths: [CGFloat] = [
        280, 200, 350, 160, 300, 240, 320, 180, 260, 340, 220, 290, 310, 190, 250,
    ]

    private var logSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0 ..< 15, id: \.self) { index in
                HStack(spacing: PoirotTheme.Spacing.sm) {
                    skeletonRect(width: 80, height: 10)
                    skeletonRect(width: [45, 38, 50][index % 3], height: 16)
                    skeletonRect(width: Self.skeletonMessageWidths[index], height: 10)
                    Spacer()
                }
                .padding(.horizontal, PoirotTheme.Spacing.lg)
                .padding(.vertical, PoirotTheme.Spacing.sm)
                .shimmer(cornerRadius: 0)
            }
        }
    }

    private func skeletonRect(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
            .fill(PoirotTheme.Colors.bgElevated)
            .frame(width: width, height: height)
    }

    // MARK: - Actions

    nonisolated private static let pageSize = 200

    private func loadEntries() async {
        isLoading = true
        let sid = sessionId
        let path = claudeDebugPath
        let page = await Task.detached {
            DebugLogLoader(claudeDebugPath: path).loadEntries(for: sid, offset: 0, limit: Self.pageSize)
        }.value
        entries = page.entries
        totalCount = page.totalCount
        isLoading = false

        // Auto-scroll to first error in loaded page
        if let firstError = page.entries.first(where: { $0.level == .error }) {
            firstErrorId = firstError.id
            scrollTarget = firstError.id
        }
    }

    private func loadMoreEntries() async {
        guard !isLoadingMore, hasMoreEntries else { return }
        isLoadingMore = true
        let sid = sessionId
        let currentOffset = entries.count
        let path = claudeDebugPath
        let page = await Task.detached {
            DebugLogLoader(claudeDebugPath: path).loadEntries(for: sid, offset: currentOffset, limit: Self.pageSize)
        }.value
        entries.append(contentsOf: page.entries)
        isLoadingMore = false
    }

    private func copyFullLog() {
        let sid = sessionId
        let allEntries = DebugLogLoader(claudeDebugPath: claudeDebugPath).loadEntries(for: sid)
        let text = allEntries
            .map { entry in
                "\(Self.absoluteFormatter.string(from: entry.timestamp)) "
                    + "[\(entry.level.rawValue)] \(entry.message)"
            }
            .joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }

    private static let absoluteFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss.SSS"
        return fmt
    }()

    // MARK: - Helpers

    private func levelColor(
        _ level: DebugLogEntry.Level
    ) -> Color {
        switch level {
        case .debug: PoirotTheme.Colors.textTertiary
        case .warn: PoirotTheme.Colors.orange
        case .error: PoirotTheme.Colors.red
        }
    }
}

// MARK: - Entry Row

private struct DebugLogEntryRow: View {
    let entry: DebugLogEntry
    let useRelativeTime: Bool
    let firstTimestamp: Date?
    var searchQuery: String = ""

    @State
    private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: PoirotTheme.Spacing.sm) {
            timestampView
                .frame(width: 90, alignment: .trailing)

            levelBadge

            messageView
        }
        .padding(.horizontal, PoirotTheme.Spacing.lg)
        .padding(.vertical, PoirotTheme.Spacing.xxs)
        .background(rowBackground)
        .onHover { isHovered = $0 }
    }

    private var timestampView: some View {
        Group {
            if useRelativeTime, let first = firstTimestamp {
                let offset = entry.timestamp.timeIntervalSince(first)
                Text("+\(Self.formatOffset(offset))")
            } else {
                Text(Self.absoluteFormatter.string(from: entry.timestamp))
            }
        }
        .font(PoirotTheme.Typography.codeSmall)
        .foregroundStyle(PoirotTheme.Colors.textTertiary)
        .lineLimit(1)
    }

    private var levelBadge: some View {
        Text(entry.level.rawValue)
            .font(PoirotTheme.Typography.codeMicro)
            .foregroundStyle(levelColor)
            .frame(width: 42)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                    .fill(levelColor.opacity(0.1))
            )
    }

    private var messageView: some View {
        Group {
            if searchQuery.isEmpty {
                Text(entry.message)
            } else {
                Text(
                    HighlightedText.attributedString(
                        entry.message,
                        query: searchQuery
                    )
                )
            }
        }
        .font(PoirotTheme.Typography.codeSmall)
        .foregroundStyle(messageForeground)
        .lineLimit(nil)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rowBackground: some View {
        Group {
            if entry.level == .error {
                PoirotTheme.Colors.red.opacity(isHovered ? 0.08 : 0.04)
            } else if entry.level == .warn {
                PoirotTheme.Colors.orange.opacity(isHovered ? 0.06 : 0.02)
            } else if isHovered {
                PoirotTheme.Colors.bgElevated.opacity(0.5)
            } else {
                Color.clear
            }
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: PoirotTheme.Colors.textTertiary
        case .warn: PoirotTheme.Colors.orange
        case .error: PoirotTheme.Colors.red
        }
    }

    private var messageForeground: Color {
        switch entry.level {
        case .debug: PoirotTheme.Colors.textSecondary
        case .warn: PoirotTheme.Colors.textPrimary
        case .error: PoirotTheme.Colors.red
        }
    }

    private static let absoluteFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss.SSS"
        return fmt
    }()

    private static func formatOffset(
        _ interval: TimeInterval
    ) -> String {
        let totalMs = Int(interval * 1000)
        let seconds = totalMs / 1000
        let ms = totalMs % 1000
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return String(
                format: "%d:%02d.%03d", minutes, secs, ms
            )
        }
        return String(format: "%d.%03ds", secs, ms)
    }
}
