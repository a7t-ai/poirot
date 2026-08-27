import Charts
import SwiftUI

struct SessionTimelineView<Trailing: View>: View {
    let group: SessionGroup
    let trailing: Trailing

    init(
        group: SessionGroup,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.group = group
        self.trailing = trailing()
    }

    @Environment(AppState.self)
    private var appState

    @State
    private var hoveredEntry: TimelineEntry?

    private var entries: [TimelineEntry] {
        var result: [TimelineEntry] = []
        let now = Date()

        result.append(TimelineEntry(
            id: group.parent.id,
            label: group.parent.title,
            startDate: group.parent.startedAt,
            endDate: group.parent.endedAt ?? now,
            isParent: true,
            agentType: nil,
            session: group.parent
        ))

        for agent in group.agents {
            let label = agent.agentDescription
                ?? agent.agentType
                ?? agent.title
            result.append(TimelineEntry(
                id: agent.id,
                label: label,
                startDate: agent.startedAt,
                endDate: agent.endedAt ?? now,
                isParent: false,
                agentType: agent.agentType,
                session: agent
            ))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.3)
            ScrollView {
                ganttChart
                    .padding(PoirotTheme.Spacing.lg)
                legend
                    .padding(.horizontal, PoirotTheme.Spacing.lg)
                    .padding(.bottom, PoirotTheme.Spacing.lg)
            }
        }
        .background(PoirotTheme.Colors.bgApp)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: PoirotTheme.Spacing.sm) {
            Label("Session Timeline", systemImage: "chart.bar.xaxis")
                .font(PoirotTheme.Typography.bodyMedium)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)

            Spacer(minLength: PoirotTheme.Spacing.sm)

            Text("\(group.agentCount) agents")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(PoirotTheme.Colors.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(PoirotTheme.Colors.purple.opacity(0.15))
                )

            trailing
        }
        .padding(.horizontal, PoirotTheme.Spacing.lg)
        .padding(.vertical, PoirotTheme.Spacing.md)
    }

    // MARK: - Gantt Chart

    private var ganttChart: some View {
        Chart(entries) { entry in
            BarMark(
                xStart: .value("Start", entry.startDate),
                xEnd: .value("End", entry.endDate),
                y: .value("Session", entry.label)
            )
            .foregroundStyle(colorForEntry(entry))
            .cornerRadius(3)
            .opacity(hoveredEntry?.id == entry.id ? 1.0 : 0.85)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(PoirotTheme.Colors.border)
                AxisValueLabel(format: .dateTime.hour().minute().second())
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .font(PoirotTheme.Typography.micro)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(PoirotTheme.Colors.border)
                AxisValueLabel()
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .font(PoirotTheme.Typography.tiny)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.background(PoirotTheme.Colors.bgCard.opacity(0.3))
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let date: Date = proxy.value(atX: location.x) else { return }
                        if let tapped = entries.first(where: {
                            date >= $0.startDate && date <= $0.endDate
                        }) {
                            appState.selectedSession = tapped.session
                        }
                    }
            }
        }
        .frame(height: CGFloat(max(entries.count * 36, 120)))
        .padding(PoirotTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .fill(PoirotTheme.Colors.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                .stroke(PoirotTheme.Colors.border, lineWidth: 1)
        )
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: PoirotTheme.Spacing.md) {
            legendItem(color: PoirotTheme.Colors.accent, label: "Parent")
            legendItem(color: PoirotTheme.Colors.blue, label: "Explore")
            legendItem(color: PoirotTheme.Colors.green, label: "Plan")
            legendItem(color: PoirotTheme.Colors.purple, label: "Other")
        }
        .font(PoirotTheme.Typography.tiny)
        .foregroundStyle(PoirotTheme.Colors.textTertiary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }

    // MARK: - Helpers

    private func colorForEntry(_ entry: TimelineEntry) -> Color {
        if entry.isParent { return PoirotTheme.Colors.accent }
        switch entry.agentType?.lowercased() {
        case "explore": return PoirotTheme.Colors.blue
        case "plan": return PoirotTheme.Colors.green
        default: return PoirotTheme.Colors.purple
        }
    }
}

extension SessionTimelineView where Trailing == EmptyView {
    init(group: SessionGroup) {
        self.init(group: group) { EmptyView() }
    }
}

// MARK: - Timeline Entry

struct TimelineEntry: Identifiable {
    let id: String
    let label: String
    let startDate: Date
    let endDate: Date
    let isParent: Bool
    let agentType: String?
    let session: Session
}
