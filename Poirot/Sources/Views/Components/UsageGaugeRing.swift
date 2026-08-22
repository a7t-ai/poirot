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
