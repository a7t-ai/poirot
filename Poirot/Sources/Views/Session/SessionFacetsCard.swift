import MarkdownUI
import SwiftUI

struct SessionFacetsCard: View {
    let facets: SessionFacets

    @State
    private var isExpanded = true

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton
            if isExpanded {
                expandedContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .fill(PoirotTheme.Colors.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .stroke(PoirotTheme.Colors.border)
        )
        .clipShape(RoundedRectangle(cornerRadius: PoirotTheme.Radius.md))
    }

    // MARK: - Header

    private var headerButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(PoirotTheme.Typography.small)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(PoirotTheme.Colors.purple)

                Text("AI Summary")
                    .font(PoirotTheme.Typography.smallBold)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                outcomeBadge

                helpfulnessBadge

                Spacer()

                sessionTypeBadge

                Image(systemName: "chevron.right")
                    .font(PoirotTheme.Typography.nanoSemibold)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, PoirotTheme.Spacing.lg)
            .padding(.vertical, PoirotTheme.Spacing.md)
        }
        .buttonStyle(.plain)
        .help(isExpanded ? "Collapse AI summary" : "Expand AI summary")
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.md) {
                // Brief Summary
                if !facets.briefSummary.isEmpty {
                    Markdown(facets.briefSummary)
                        .markdownTheme(.poirot)
                        .textSelection(.enabled)
                }

                // Goal
                if !facets.underlyingGoal.isEmpty {
                    goalSection
                }

                // Goal Categories
                if !facets.goalCategories.isEmpty {
                    goalCategoriesSection
                }

                // Friction
                if facets.totalFrictionCount > 0 {
                    frictionSection
                }
            }
            .padding(PoirotTheme.Spacing.lg)
        }
    }

    // MARK: - Goal Section

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Label {
                Text("Goal")
                    .font(PoirotTheme.Typography.microSemibold)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            } icon: {
                Image(systemName: "target")
                    .font(PoirotTheme.Typography.micro)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }

            Text(facets.underlyingGoal)
                .font(PoirotTheme.Typography.caption)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Goal Categories

    private var goalCategoriesSection: some View {
        FlowLayout(spacing: PoirotTheme.Spacing.xs) {
            ForEach(facets.sortedGoalCategories, id: \.name) { category in
                HStack(spacing: PoirotTheme.Spacing.xxs) {
                    Text(SessionFacets.categoryLabel(category.name))
                        .font(PoirotTheme.Typography.micro)
                        .foregroundStyle(PoirotTheme.Colors.accent)

                    if category.count > 1 {
                        Text("\(category.count)")
                            .font(PoirotTheme.Typography.micro)
                            .foregroundStyle(PoirotTheme.Colors.accent.opacity(0.7))
                    }
                }
                .padding(.horizontal, PoirotTheme.Spacing.sm)
                .padding(.vertical, PoirotTheme.Spacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                        .fill(PoirotTheme.Colors.accentDim)
                )
            }
        }
    }

    // MARK: - Friction Section

    private var frictionSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Label {
                Text("Friction")
                    .font(PoirotTheme.Typography.microSemibold)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .font(PoirotTheme.Typography.micro)
                    .foregroundStyle(PoirotTheme.Colors.orange)
            }

            FlowLayout(spacing: PoirotTheme.Spacing.xs) {
                ForEach(facets.sortedFrictionItems, id: \.name) { item in
                    HStack(spacing: PoirotTheme.Spacing.xxs) {
                        Text(SessionFacets.frictionLabel(item.name))
                            .font(PoirotTheme.Typography.micro)
                            .foregroundStyle(PoirotTheme.Colors.orange)

                        if item.count > 1 {
                            Text("\(item.count)")
                                .font(PoirotTheme.Typography.micro)
                                .foregroundStyle(PoirotTheme.Colors.orange.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, PoirotTheme.Spacing.sm)
                    .padding(.vertical, PoirotTheme.Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                            .fill(PoirotTheme.Colors.orange.opacity(0.1))
                    )
                }
            }

            if !facets.frictionDetail.isEmpty {
                Text(facets.frictionDetail)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Badges

    private var outcomeBadge: some View {
        Text(facets.outcomeLabel)
            .font(PoirotTheme.Typography.microSemibold)
            .foregroundStyle(outcomeColor)
            .padding(.horizontal, PoirotTheme.Spacing.sm)
            .padding(.vertical, PoirotTheme.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                    .fill(outcomeColor.opacity(0.1))
            )
    }

    private var helpfulnessBadge: some View {
        Text(facets.helpfulnessLabel)
            .font(PoirotTheme.Typography.microSemibold)
            .foregroundStyle(helpfulnessColor)
            .padding(.horizontal, PoirotTheme.Spacing.sm)
            .padding(.vertical, PoirotTheme.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                    .fill(helpfulnessColor.opacity(0.1))
            )
    }

    private var sessionTypeBadge: some View {
        Text(facets.sessionTypeLabel)
            .font(PoirotTheme.Typography.micro)
            .foregroundStyle(PoirotTheme.Colors.textTertiary)
            .padding(.horizontal, PoirotTheme.Spacing.sm)
            .padding(.vertical, PoirotTheme.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                    .fill(PoirotTheme.Colors.bgElevated)
            )
    }

    // MARK: - Colors

    private var outcomeColor: Color {
        switch facets.outcome {
        case "success": PoirotTheme.Colors.green
        case "partially_achieved": PoirotTheme.Colors.orange
        case "failure": PoirotTheme.Colors.red
        default: PoirotTheme.Colors.textTertiary
        }
    }

    private var helpfulnessColor: Color {
        switch facets.claudeHelpfulness {
        case "very_helpful": PoirotTheme.Colors.green
        case "slightly_helpful": PoirotTheme.Colors.accent
        case "not_helpful": PoirotTheme.Colors.orange
        case "harmful": PoirotTheme.Colors.red
        default: PoirotTheme.Colors.textTertiary
        }
    }
}

// MARK: - Flow Layout

/// A simple horizontal wrapping layout for tag chips.
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        let size: CGSize
        let offsets: [CGPoint]
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return LayoutResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            offsets: offsets
        )
    }
}
