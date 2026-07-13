import SwiftUI

struct HookFormView: View {
    let scope: ConfigScope
    let projectPath: String?
    var editingEntry: HookEntry?
    var onSave: () -> Void
    var onCancel: () -> Void

    @State
    private var selectedEvent: HookEvent = .preToolUse
    @State
    private var matcher: String = ""
    @State
    private var handlerType: HookHandlerType = .command
    @State
    private var command: String = ""
    @State
    private var url: String = ""
    @State
    private var timeout: String = ""
    @State
    private var statusMessage: String = ""

    @Environment(AppState.self)
    private var appState

    private var isEditing: Bool { editingEntry != nil }

    private var isValid: Bool {
        switch handlerType {
        case .command:
            return !command.trimmingCharacters(in: .whitespaces).isEmpty
        case .http:
            return !url.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            ScrollView {
                formContent
                    .padding(PoirotTheme.Spacing.xl)
            }
            .scrollIndicators(.never)
            Divider()
            actionBar
        }
        .frame(width: 480, height: 520)
        .background(PoirotTheme.Colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: PoirotTheme.Radius.lg))
        .onAppear { populateFromEntry() }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .font(PoirotTheme.Typography.body)
                .foregroundStyle(PoirotTheme.Colors.orange)

            Text(isEditing ? "Edit Hook" : "New Hook")
                .font(PoirotTheme.Typography.bodyMedium)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)

            Spacer()

            Text(scope == .global ? "Global" : "Project")
                .font(PoirotTheme.Typography.tiny)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
                .padding(.horizontal, PoirotTheme.Spacing.sm)
                .padding(.vertical, PoirotTheme.Spacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgElevated)
                )
        }
        .padding(.horizontal, PoirotTheme.Spacing.xl)
        .padding(.vertical, PoirotTheme.Spacing.md)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.lg) {
            // Event picker
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                Text("Event")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                Picker("Event", selection: $selectedEvent) {
                    ForEach(HookEvent.allCases) { event in
                        HStack {
                            Image(systemName: event.icon)
                            Text(event.label)
                        }
                        .tag(event)
                    }
                }
                .labelsHidden()

                Text(selectedEvent.description)
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }

            // Matcher
            if selectedEvent.supportsMatcher {
                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                    Text("Matcher (regex)")
                        .font(PoirotTheme.Typography.captionMedium)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)

                    TextField("e.g. Bash|Write", text: $matcher)
                        .textFieldStyle(.roundedBorder)
                        .font(PoirotTheme.Typography.code)

                    Text("Optional regex to filter when the hook fires")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }
            }

            // Handler type
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                Text("Handler Type")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                Picker("Type", selection: $handlerType) {
                    ForEach(HookHandlerType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Command or URL
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                switch handlerType {
                case .command:
                    Text("Command")
                        .font(PoirotTheme.Typography.captionMedium)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)

                    TextField("e.g. .claude/hooks/check.sh", text: $command)
                        .textFieldStyle(.roundedBorder)
                        .font(PoirotTheme.Typography.code)

                case .http:
                    Text("URL")
                        .font(PoirotTheme.Typography.captionMedium)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)

                    TextField("e.g. http://localhost:3000/hook", text: $url)
                        .textFieldStyle(.roundedBorder)
                        .font(PoirotTheme.Typography.code)
                }
            }

            // Timeout
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                Text("Timeout (seconds)")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                TextField(
                    handlerType == .command ? "Default: 600" : "Default: 30",
                    text: $timeout
                )
                .textFieldStyle(.roundedBorder)
                .font(PoirotTheme.Typography.code)
            }

            // Status message
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                Text("Status Message")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                TextField("e.g. Checking command safety...", text: $statusMessage)
                    .textFieldStyle(.roundedBorder)
                    .font(PoirotTheme.Typography.code)

                Text("Shown in Claude Code while the hook runs")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Button("Cancel") { onCancel() }
                .keyboardShortcut(.cancelAction)
                .help("Cancel")

            Spacer()

            Button(isEditing ? "Save" : "Create") { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
                .help(isEditing ? "Save hook" : "Create hook")
        }
        .padding(.horizontal, PoirotTheme.Spacing.xl)
        .padding(.vertical, PoirotTheme.Spacing.md)
    }

    private func populateFromEntry() {
        guard let entry = editingEntry else { return }
        selectedEvent = entry.event
        matcher = entry.matcher ?? ""
        if let handler = entry.firstHandler {
            handlerType = handler.type
            command = handler.command ?? ""
            url = handler.url ?? ""
            timeout = handler.timeout.map { "\($0)" } ?? ""
            statusMessage = handler.statusMessage ?? ""
        }
    }

    private func save() {
        let handler = HookHandler(
            type: handlerType,
            command: handlerType == .command ? command.trimmingCharacters(in: .whitespaces) : nil,
            url: handlerType == .http ? url.trimmingCharacters(in: .whitespaces) : nil,
            timeout: Int(timeout),
            statusMessage: statusMessage.isEmpty ? nil : statusMessage
        )
        let matcherValue = matcher.trimmingCharacters(in: .whitespaces)
        let group = HookMatcherGroup(
            matcher: matcherValue.isEmpty ? nil : matcherValue,
            handlers: [handler]
        )

        SettingsWriter.saveHook(
            event: selectedEvent,
            matcherGroup: group,
            existingIndex: editingEntry?.matcherGroupIndex,
            scope: scope,
            projectPath: projectPath
        )

        appState.showToast(
            isEditing ? "Hook updated" : "Hook created",
            icon: "checkmark.circle.fill"
        )
        onSave()
    }
}
