import SwiftUI

struct ExportOptionsView: View {
    let session: Session

    @State
    private var options = ExportOptions()

    @Environment(AppState.self)
    private var appState

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(PoirotTheme.Typography.body)
                    .foregroundStyle(PoirotTheme.Colors.accent)

                Text("Export Session")
                    .font(PoirotTheme.Typography.headingSmall)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
            }

            // Options
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
                Text("Options")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                Toggle("Include timestamps", isOn: $options.includeTimestamps)
                Toggle("Include tool results", isOn: $options.includeToolResults)
                Toggle("Include thinking blocks", isOn: $options.includeThinking)
                Toggle("Include token usage", isOn: $options.includeTokenUsage)
            }
            .font(PoirotTheme.Typography.caption)
            .foregroundStyle(PoirotTheme.Colors.textPrimary)
            .toggleStyle(.checkbox)

            Divider()

            // Actions
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Button("Copy") {
                    copyMarkdown()
                }
                .buttonStyle(.bordered)
                .help("Copy session as Markdown")

                Spacer()

                Button("Export\u{2026}") {
                    exportMarkdown()
                }
                .buttonStyle(.borderedProminent)
                .help("Export session as Markdown")
            }
        }
        .padding(PoirotTheme.Spacing.lg)
        .frame(width: 300)
    }

    // MARK: - Actions

    private func copyMarkdown() {
        let markdown = SessionExporter.toMarkdown(session, options: options)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        appState.showToast("Copied session as Markdown")
        dismiss()
    }

    private func exportMarkdown() {
        let content = SessionExporter.toMarkdown(session, options: options)
        SessionExporter.presentMarkdownSavePanel(
            content: content,
            sessionTitle: session.title
        )
        dismiss()
    }
}
