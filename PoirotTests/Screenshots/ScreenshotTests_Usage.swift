@testable import Poirot
import SnapshotTesting
import SwiftUI
import Testing

@Suite("Usage Gauge Screenshots")
struct ScreenshotTests_Usage {
    private let isRecording = false

    /// Fixed reference instant so reset countdowns render deterministically.
    private static let now = Date(timeIntervalSince1970: 1_780_000_000)

    private static let cardRow = CGSize(width: 760, height: 150)
    private static let optIn = CGSize(width: 560, height: 280)
    private static let contextCard = CGSize(width: 860, height: 130)

    private static let sampleContext = ContextUsage(
        current: 440_000,
        peak: 470_000,
        window: 1_000_000,
        inputTokens: 12400,
        outputTokens: 38900,
        cacheReadTokens: 9_240_000,
        cacheCreationTokens: 410_000,
        series: [86000, 180_000, 240_000, 330_000, 470_000, 412_000, 440_000]
    )

    @Test
    func testUsageGaugeRow() {
        snapshotView(
            usageRow,
            size: Self.cardRow,
            named: "testUsageGaugeRow",
            record: isRecording
        )
    }

    @Test
    func testUsageGaugeRowLight() {
        snapshotView(
            usageRow,
            size: Self.cardRow,
            named: "testUsageGaugeRowLight",
            record: isRecording,
            colorScheme: .light
        )
    }

    @Test
    func testUsageUnauthenticated() {
        let view = UsageOptInCard(
            icon: "key.slash",
            title: "Add your usage token",
            message: "Run `claude setup-token` in your terminal, then paste the token in Settings › Usage.",
            actionTitle: "Open Settings",
            actionIcon: "gearshape"
        ) {}
            .frame(width: 460)
            .padding(PoirotTheme.Spacing.xl)
            .background(PoirotTheme.Colors.bgApp)

        snapshotView(
            view,
            size: Self.optIn,
            named: "testUsageUnauthenticated",
            record: isRecording
        )
    }

    @Test
    func testUsageOptIn() {
        let view = UsageOptInCard {}
            .frame(width: 460)
            .padding(PoirotTheme.Spacing.xl)
            .background(PoirotTheme.Colors.bgApp)

        snapshotView(
            view,
            size: Self.optIn,
            named: "testUsageOptIn",
            record: isRecording
        )
    }

    @Test
    func testConversationContext() {
        let view = ConversationContextCard(context: Self.sampleContext)
            .frame(width: 760)
            .padding(PoirotTheme.Spacing.xl)
            .background(PoirotTheme.Colors.bgApp)

        snapshotView(
            view,
            size: Self.contextCard,
            named: "testConversationContext",
            record: isRecording
        )
    }

    // MARK: - Helpers

    private var usageRow: some View {
        HStack(spacing: PoirotTheme.Spacing.md) {
            UsageGaugeCard(
                title: "5-Hour Window",
                icon: "clock.arrow.circlepath",
                window: UsageWindow(utilization: 22, resetsAt: Self.now.addingTimeInterval(8040)),
                now: Self.now
            )
            UsageGaugeCard(
                title: "7-Day Window",
                icon: "calendar",
                window: UsageWindow(utilization: 86, resetsAt: Self.now.addingTimeInterval(280_800)),
                now: Self.now
            )
            UsageGaugeCard(
                title: "Opus Weekly",
                icon: "exclamationmark.triangle",
                window: UsageWindow(utilization: 97, resetsAt: Self.now.addingTimeInterval(1800)),
                now: Self.now
            )
        }
        .frame(height: 110)
        .padding(PoirotTheme.Spacing.xxl)
        .background(PoirotTheme.Colors.bgApp)
    }
}
