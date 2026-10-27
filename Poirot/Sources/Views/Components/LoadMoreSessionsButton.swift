import SwiftUI

/// Loads the next batch of older sessions for one project. Shown while the batch size leaves some
/// of the project's sessions on disk unloaded.
struct LoadMoreSessionsButton: View {
    enum Style {
        /// A row closing a project's sessions in the session list
        case row
        /// A centered button under the sessions on the project page
        case footer
    }

    let project: Project
    var style: Style = .row

    @Environment(AppState.self)
    private var appState
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State
    private var isHovered = false
    @State
    private var tapCount = 0

    private var isLoading: Bool {
        appState.isLoadingSessions(for: project.id)
    }

    private var isHighlighted: Bool {
        isHovered && !isLoading
    }

    var body: some View {
        Button {
            tapCount += 1
            appState.loadMoreSessions(for: project.id)
        } label: {
            switch style {
            case .row:
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, PoirotTheme.Spacing.md)
                    .padding(.vertical, PoirotTheme.Spacing.sm)
                    .padding(.leading, PoirotTheme.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                            .fill(isHighlighted ? PoirotTheme.Colors.bgCardHover : .clear)
                    )
                    .contentShape(Rectangle())
            case .footer:
                content
                    .padding(.horizontal, PoirotTheme.Spacing.lg)
                    .padding(.vertical, PoirotTheme.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(PoirotTheme.Colors.bgElevated)
                            .overlay(Capsule().stroke(PoirotTheme.Colors.border))
                    )
                    .contentShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .help("Load older sessions from \(project.name)")
        .onHover { isHovered = $0 }
    }

    private var content: some View {
        HStack(spacing: PoirotTheme.Spacing.xs) {
            Image(systemName: "ellipsis.circle")
                .font(PoirotTheme.Typography.small)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: reduceMotion ? 0 : tapCount)
                .symbolEffect(.pulse, isActive: isLoading && !reduceMotion)

            Text(
                isLoading
                    ? String(localized: "Loading older sessions\u{2026}")
                    : Self.title(remaining: project.unloadedSessionCount, batch: appState.loadBatchSize.limit)
            )
            .font(PoirotTheme.Typography.caption)
        }
        .foregroundStyle(isHighlighted ? PoirotTheme.Colors.accent : PoirotTheme.Colors.textTertiary)
    }

    /// "Show 14 older sessions", or "Show 20 of 54 older sessions" when more than one batch is left.
    static func title(remaining: Int, batch: Int) -> String {
        if remaining > batch {
            return String(localized: "Show \(batch) of \(remaining) older sessions")
        }
        return remaining == 1
            ? String(localized: "Show 1 older session")
            : String(localized: "Show \(remaining) older sessions")
    }
}
