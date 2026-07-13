import SwiftUI

// MARK: - Severity Tint

@MainActor
extension UsageSeverity {
    /// Gauge fill color. Semantic (green → orange → red) so utilization reads at a glance,
    /// independent of the user's accent choice.
    var tint: Color {
        switch self {
        case .normal: PoirotTheme.Colors.green
        case .warning: PoirotTheme.Colors.orange
        case .critical: PoirotTheme.Colors.red
        }
    }
}

// MARK: - Usage Gauge Card

/// A single rate-limit window rendered as a ring gauge with a reset countdown.
/// Presentational only — loading / unauthenticated / error states are handled by the
/// containing section (see `AnalyticsDashboardView` and `MenuBarView`).
struct UsageGaugeCard: View {
    let title: String
    let icon: String
    let window: UsageWindow
    /// Injected for deterministic snapshots; defaults to the current time.
    var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(window.severity.tint)
                Text(title)
                    .font(PoirotTheme.Typography.small)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)
                Spacer()
            }

            HStack(spacing: PoirotTheme.Spacing.md) {
                UsageGaugeRing(window: window)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                    Text(resetCountdown)
                        .font(PoirotTheme.Typography.captionMedium)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    Text(resetDetail)
                        .font(PoirotTheme.Typography.micro)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }

                Spacer()
            }
        }
        .padding(PoirotTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .fill(PoirotTheme.Colors.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .stroke(PoirotTheme.Colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(window.percent)% used. \(resetCountdown).")
    }

    private var resetCountdown: String {
        guard let interval = window.timeUntilReset(now: now) else {
            return "No reset window"
        }
        if interval < 60 { return "Resets now" }
        return "Resets in \(UsageCountdown.format(interval))"
    }

    private var resetDetail: String {
        guard let resetsAt = window.resetsAt else { return " " }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "at \(formatter.string(from: resetsAt))"
    }
}

// MARK: - Ring

/// Circular progress ring with the utilization percentage in the center. Drawn with shapes
/// (rather than `Gauge`) for deterministic snapshots and full theme control.
struct UsageGaugeRing: View {
    let window: UsageWindow

    var body: some View {
        ZStack {
            Circle()
                .stroke(PoirotTheme.Colors.bgElevated, lineWidth: 5)

            Circle()
                .trim(from: 0, to: window.fraction)
                .stroke(
                    window.severity.tint,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(window.percent)%")
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)
        }
    }
}

// MARK: - Placeholder (non-loaded states)

/// Compact card for the loading / unauthenticated / error states of the usage section.
struct UsagePlaceholderCard: View {
    let icon: String
    let message: String
    var tint: Color = PoirotTheme.Colors.textTertiary
    var pulse: Bool = false
    var action: (title: String, handler: () -> Void)?

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        HStack(spacing: PoirotTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: pulse && !reduceMotion)

            Text(message)
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if let action {
                Button(action.title, action: action.handler)
                    .buttonStyle(.borderless)
                    .help(action.title)
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.accent)
            }
        }
        .padding(PoirotTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .fill(PoirotTheme.Colors.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .stroke(PoirotTheme.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Consent / Notice Card

/// Consent-first card for usage limits. Nothing is read or fetched until the user taps the
/// action. The disclaimer is always shown, so it stays in view across the opt-in, the
/// "couldn't read token", and error states — wherever Poirot is about to (or just tried to)
/// touch the Keychain.
struct UsageOptInCard: View {
    var icon = "gauge.with.dots.needle.bottom.50percent"
    var title = "See your subscription usage limits"
    // swiftlint:disable:next line_length
    var message = "Show your Claude subscription's 5-hour and 7-day rate-limit windows — utilization and reset countdowns, in the dashboard and the menu bar."
    var actionTitle = "Enable Usage Limits"
    var actionIcon = "lock.open"
    let onAction: () -> Void

    @State
    private var actionBounce = 0

    var body: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.md) {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(PoirotTheme.Colors.accent)
                Text(title)
                    .font(PoirotTheme.Typography.subheading)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
            }

            Text(message)
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                actionBounce += 1
                onAction()
            } label: {
                Label(actionTitle, systemImage: actionIcon)
                    .symbolEffect(.bounce, value: actionBounce)
                    .font(PoirotTheme.Typography.captionMedium)
            }
            .buttonStyle(.borderedProminent)
            .help(actionTitle)
            .tint(PoirotTheme.Colors.accent)

            UsageDisclaimer()
        }
        .padding(PoirotTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .fill(PoirotTheme.Colors.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .stroke(PoirotTheme.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Disclaimer

/// The standing privacy disclosure for usage limits — shown wherever Poirot is about to, or
/// just failed to, read Claude Code's Keychain token, so the user always knows what's happening.
struct UsageDisclaimer: View {
    var sourceURL = URL(string: "https://github.com/a7t-ai/poirot")

    var body: some View {
        HStack(alignment: .top, spacing: PoirotTheme.Spacing.sm) {
            Image(systemName: "lock.shield")
                .font(.system(size: 13))
                .foregroundStyle(PoirotTheme.Colors.green)

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                // swiftlint:disable:next line_length
                Text("Poirot reads the OAuth token Claude Code already stores in your Keychain and asks Anthropic directly for your usage. Nothing leaves your Mac — no servers, no tracking, no analytics. macOS will ask your permission the first time.")
                    .font(PoirotTheme.Typography.micro)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if let sourceURL {
                    Link(destination: sourceURL) {
                        HStack(spacing: PoirotTheme.Spacing.xxs) {
                            Text("The code is open source — verify it yourself")
                            Image(systemName: "arrow.up.forward.square")
                        }
                        .font(PoirotTheme.Typography.micro)
                        .foregroundStyle(PoirotTheme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, PoirotTheme.Spacing.xxs)
    }
}
