import SwiftUI

struct SessionTodosView: View {
    let todos: [SessionTodo]

    @State
    private var isExpanded = true

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var completedCount: Int { todos.filter { $0.status == .completed }.count }
    private var inProgressCount: Int { todos.filter { $0.status == .inProgress }.count }
    private var pendingCount: Int { todos.filter { $0.status == .pending }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton
            if isExpanded {
                todosList
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
                Image(systemName: "checklist")
                    .font(PoirotTheme.Typography.small)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(PoirotTheme.Colors.accent)

                Text("Todos")
                    .font(PoirotTheme.Typography.smallBold)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                statusSummary

                Spacer()

                Text("\(todos.count)")
                    .font(PoirotTheme.Typography.microSemibold)
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .padding(.horizontal, PoirotTheme.Spacing.sm)
                    .padding(.vertical, PoirotTheme.Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                            .fill(PoirotTheme.Colors.accentDim)
                    )

                Image(systemName: "chevron.right")
                    .font(PoirotTheme.Typography.nanoSemibold)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, PoirotTheme.Spacing.lg)
            .padding(.vertical, PoirotTheme.Spacing.md)
        }
        .buttonStyle(.plain)
        .help(isExpanded ? "Collapse todos" : "Expand todos")
    }

    // MARK: - Status Summary

    private var statusSummary: some View {
        HStack(spacing: PoirotTheme.Spacing.xs) {
            if completedCount > 0 {
                statusPill(count: completedCount, color: PoirotTheme.Colors.green)
            }
            if inProgressCount > 0 {
                statusPill(count: inProgressCount, color: PoirotTheme.Colors.accent)
            }
            if pendingCount > 0 {
                statusPill(count: pendingCount, color: PoirotTheme.Colors.textTertiary)
            }
        }
    }

    private func statusPill(count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(PoirotTheme.Typography.micro)
            .foregroundStyle(color)
            .padding(.horizontal, PoirotTheme.Spacing.xs)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                    .fill(color.opacity(0.1))
            )
    }

    // MARK: - Todos List

    private var todosList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().opacity(0.3)

            ForEach(Array(todos.enumerated()), id: \.element.id) { index, todo in
                todoRow(todo)
                if index < todos.count - 1 {
                    Divider()
                        .opacity(0.15)
                        .padding(.leading, PoirotTheme.Spacing.xxxl)
                }
            }
        }
    }

    private func todoRow(_ todo: SessionTodo) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PoirotTheme.Spacing.md) {
            statusIcon(for: todo.status)

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xxs) {
                Text(todo.content)
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(
                        todo.status == .completed
                            ? PoirotTheme.Colors.textTertiary
                            : PoirotTheme.Colors.textPrimary
                    )
                    .strikethrough(todo.status == .completed, color: PoirotTheme.Colors.textTertiary)

                if todo.status == .inProgress {
                    Text(todo.activeForm)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.accent)
                }
            }

            Spacer()
        }
        .padding(.horizontal, PoirotTheme.Spacing.lg)
        .padding(.vertical, PoirotTheme.Spacing.sm)
    }

    private func statusIcon(for status: SessionTodo.Status) -> some View {
        Group {
            switch status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(PoirotTheme.Colors.green)
                    .symbolEffect(.bounce, value: status)
            case .inProgress:
                Image(systemName: "circle.dotted")
                    .foregroundStyle(PoirotTheme.Colors.accent)
                    .symbolEffect(.breathe, isActive: !reduceMotion)
            case .pending:
                Image(systemName: "circle")
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
        .font(PoirotTheme.Typography.caption)
    }
}
