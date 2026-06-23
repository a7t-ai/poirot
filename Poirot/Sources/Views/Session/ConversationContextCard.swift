import SwiftUI

/// Compact card shown in the session header: how full the model's context window was on the
/// most recent turn, the cache-hit rate, the token mix, and a per-turn growth sparkline.
/// Everything is derived from the local transcript — no network, no opt-in.
struct ConversationContextCard: View {
    let context: ContextUsage

    private var ringWindow: UsageWindow {
        UsageWindow(utilization: context.fraction * 100, resetsAt: nil)
    }

    var body: some View {
        HStack(alignment: .center, spacing: PoirotTheme.Spacing.lg) {
            contextColumn
            Divider().frame(height: 44).opacity(0.4)
            tokenMixColumn
            Spacer(minLength: PoirotTheme.Spacing.md)
            if context.series.count > 1 {
                sparklineColumn
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

    // MARK: - Context

    private var contextColumn: some View {
        HStack(spacing: PoirotTheme.Spacing.md) {
            UsageGaugeRing(window: ringWindow)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                Text("Context window")
                    .font(PoirotTheme.Typography.small)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)
                Text("\(format(context.current)) / \(format(context.window))")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                Text("\(Int((context.cacheHitRate * 100).rounded()))% from cache")
                    .font(PoirotTheme.Typography.micro)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Token Mix

    private var tokenMixColumn: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Text("Tokens")
                .font(PoirotTheme.Typography.small)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)

            tokenMixBar
                .frame(width: 150, height: 6)
                .clipShape(Capsule())

            HStack(spacing: PoirotTheme.Spacing.sm) {
                legend("Cache", context.cacheReadTokens + context.cacheCreationTokens, PoirotTheme.Colors.blue)
                legend("In", context.inputTokens, PoirotTheme.Colors.teal)
                legend("Out", context.outputTokens, PoirotTheme.Colors.accent)
            }
        }
    }

    private var tokenMixBar: some View {
        let cache = context.cacheReadTokens + context.cacheCreationTokens
        let total = max(1, context.inputTokens + context.outputTokens + cache)
        return GeometryReader { geo in
            HStack(spacing: 0) {
                segment(cache, total, geo.size.width, PoirotTheme.Colors.blue)
                segment(context.inputTokens, total, geo.size.width, PoirotTheme.Colors.teal)
                segment(context.outputTokens, total, geo.size.width, PoirotTheme.Colors.accent)
            }
        }
    }

    private func segment(_ value: Int, _ total: Int, _ width: CGFloat, _ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width * CGFloat(value) / CGFloat(total))
    }

    private func legend(_ label: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: PoirotTheme.Spacing.xxs) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label) \(format(value))")
                .font(PoirotTheme.Typography.micro)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
    }

    // MARK: - Sparkline

    private var sparklineColumn: some View {
        VStack(alignment: .trailing, spacing: PoirotTheme.Spacing.xxs) {
            Text("Context over \(context.series.count) turns")
                .font(PoirotTheme.Typography.micro)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
            ContextSparkline(values: context.series, ceiling: context.window)
                .stroke(ringWindow.severity.tint, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                .frame(width: 150, height: 32)
        }
    }

    private func format(_ value: Int) -> String {
        AnalyticsFormatters.formatLargeNumber(value)
    }
}

// MARK: - Sparkline Shape

/// A normalized polyline of context size per turn. Heights are relative to `ceiling`
/// (the window), so the line doubles as a fill indicator.
struct ContextSparkline: Shape {
    let values: [Int]
    let ceiling: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1, ceiling > 0 else { return path }

        let stepX = rect.width / CGFloat(values.count - 1)
        func point(_ index: Int) -> CGPoint {
            let fraction = min(max(Double(values[index]) / Double(ceiling), 0), 1)
            let y = rect.maxY - CGFloat(fraction) * rect.height
            return CGPoint(x: rect.minX + CGFloat(index) * stepX, y: y)
        }

        path.move(to: point(0))
        for index in 1 ..< values.count {
            path.addLine(to: point(index))
        }
        return path
    }
}
