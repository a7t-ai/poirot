import SwiftUI

// MARK: - Wizard Steps

private enum WizardStep: Int, CaseIterable {
    case selectServer
    case configure
    case preview

    var title: String {
        switch self {
        case .selectServer: "Select Server"
        case .configure: "Configure"
        case .preview: "Preview & Save"
        }
    }

    var icon: String {
        switch self {
        case .selectServer: "server.rack"
        case .configure: "gearshape"
        case .preview: "checkmark.seal"
        }
    }
}

// MARK: - MCPSetupWizardView

struct MCPSetupWizardView: View {
    var editingServer: MCPServer?
    var onComplete: () -> Void

    @State
    private var step: WizardStep = .selectServer
    @State
    private var selectedEntry: MCPCatalogEntry?
    @State
    private var searchQuery = ""
    @State
    private var serverName = ""
    @State
    private var envValues: [String: String] = [:]
    @State
    private var customCommand = ""
    @State
    private var customArgs = ""
    @State
    private var useCustom = false
    @State
    private var bounceValue = 0

    @Environment(\.dismiss)
    private var dismiss
    @Environment(AppState.self)
    private var appState

    private var isEditing: Bool {
        editingServer != nil
    }

    private var resolvedCommand: String {
        useCustom ? customCommand.trimmingCharacters(in: .whitespaces) : (selectedEntry?.command ?? "")
    }

    private var resolvedArgs: [String] {
        if useCustom {
            return customArgs
                .components(separatedBy: " ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        var args = selectedEntry?.args ?? []
        // For filesystem server, append allowed dirs as extra args
        if selectedEntry?.id == "filesystem", let dirs = envValues["ALLOWED_DIRS"], !dirs.isEmpty {
            let paths = dirs.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            args.append(contentsOf: paths)
        }
        return args
    }

    private var resolvedEnv: [String: String] {
        var env: [String: String] = [:]
        for (key, value) in envValues {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // Skip ALLOWED_DIRS and SQLITE_DB_PATH — these are passed as args, not env
            if selectedEntry?.id == "filesystem", key == "ALLOWED_DIRS" { continue }
            if selectedEntry?.id == "sqlite", key == "SQLITE_DB_PATH" { continue }
            env[key] = trimmed
        }
        return env
    }

    private var resolvedServerName: String {
        let name = serverName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? (selectedEntry?.id ?? "custom") : name
    }

    private var isConfigValid: Bool {
        guard !resolvedServerName.isEmpty else { return false }
        if useCustom {
            return !resolvedCommand.isEmpty
        }
        guard let entry = selectedEntry else { return false }
        for key in entry.envKeys where key.isRequired {
            let value = envValues[key.id]?.trimmingCharacters(in: .whitespaces) ?? ""
            if value.isEmpty { return false }
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            stepIndicator
            Divider()

            Group {
                switch step {
                case .selectServer:
                    serverSelectionStep
                case .configure:
                    configurationStep
                case .preview:
                    previewStep
                }
            }
            .frame(maxHeight: .infinity)

            Divider()
            actionBar
        }
        .frame(width: 560, height: 600)
        .background(PoirotTheme.Colors.bgApp)
        .onAppear { populateFromEditing() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image(systemName: "powerplug")
                .font(PoirotTheme.Typography.body)
                .foregroundStyle(PoirotTheme.Colors.green)
                .symbolEffect(.bounce, value: bounceValue)

            Text(isEditing ? "Edit MCP Server" : "Add MCP Server")
                .font(PoirotTheme.Typography.bodyMedium)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)

            Spacer()

            Text("~/.claude.json")
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

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(WizardStep.allCases, id: \.rawValue) { wizardStep in
                HStack(spacing: PoirotTheme.Spacing.xs) {
                    Image(systemName: wizardStep.icon)
                        .font(.system(size: 10))
                    Text(wizardStep.title)
                        .font(PoirotTheme.Typography.tiny)
                }
                .foregroundStyle(
                    step.rawValue >= wizardStep.rawValue
                        ? PoirotTheme.Colors.accent
                        : PoirotTheme.Colors.textTertiary
                )
                .padding(.horizontal, PoirotTheme.Spacing.md)
                .padding(.vertical, PoirotTheme.Spacing.sm)
                .background(
                    step == wizardStep
                        ? RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.accentDim)
                        : nil
                )

                if wizardStep != WizardStep.allCases.last {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, PoirotTheme.Spacing.xl)
        .padding(.vertical, PoirotTheme.Spacing.sm)
        .background(PoirotTheme.Colors.bgCard)
    }

    // MARK: - Step 1: Server Selection

    private var serverSelectionStep: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: PoirotTheme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                TextField("Search servers\u{2026}", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(PoirotTheme.Typography.body)
            }
            .padding(.horizontal, PoirotTheme.Spacing.lg)
            .padding(.vertical, PoirotTheme.Spacing.sm)
            .background(PoirotTheme.Colors.bgCard)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    // Custom server option
                    customServerRow

                    let groups = filteredGroups
                    ForEach(groups, id: \.category) { group in
                        sectionHeader(group.category.rawValue, icon: group.category.icon)
                        ForEach(group.entries) { entry in
                            catalogRow(entry)
                        }
                    }
                }
                .padding(.vertical, PoirotTheme.Spacing.sm)
            }
            .scrollIndicators(.never)
        }
    }

    private var filteredGroups: [(category: MCPCatalogCategory, entries: [MCPCatalogEntry])] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return MCPServerCatalog.grouped() }
        let filtered = MCPServerCatalog.search(q)
        return MCPCatalogCategory.allCases.compactMap { cat in
            let matching = filtered.filter { $0.category == cat }
            return matching.isEmpty ? nil : (cat, matching)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: PoirotTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(title.uppercased())
                .font(PoirotTheme.Typography.sectionHeader)
        }
        .foregroundStyle(PoirotTheme.Colors.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PoirotTheme.Spacing.xl)
        .padding(.top, PoirotTheme.Spacing.lg)
        .padding(.bottom, PoirotTheme.Spacing.xs)
    }

    private var customServerRow: some View {
        Button {
            useCustom = true
            selectedEntry = nil
            serverName = ""
            step = .configure
        } label: {
            HStack(spacing: PoirotTheme.Spacing.md) {
                Image(systemName: "terminal")
                    .font(.system(size: 14))
                    .foregroundStyle(PoirotTheme.Colors.purple)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                            .fill(PoirotTheme.Colors.purple.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Server")
                        .font(PoirotTheme.Typography.bodyMedium)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    Text("Configure a custom MCP server with any command")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
            .padding(.horizontal, PoirotTheme.Spacing.xl)
            .padding(.vertical, PoirotTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Configure a custom server")
    }

    private func catalogRow(_ entry: MCPCatalogEntry) -> some View {
        Button {
            selectedEntry = entry
            useCustom = false
            if serverName.isEmpty || serverName == editingServer?.rawName {
                serverName = entry.id
            }
            // Pre-populate env with empty strings
            for key in entry.envKeys where envValues[key.id] == nil {
                envValues[key.id] = ""
            }
            step = .configure
        } label: {
            HStack(spacing: PoirotTheme.Spacing.md) {
                Image(systemName: entry.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(PoirotTheme.Colors.blue)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                            .fill(PoirotTheme.Colors.blue.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(PoirotTheme.Typography.bodyMedium)
                        .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    Text(entry.description)
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if entry.envKeys.isEmpty {
                    Text("No config needed")
                        .font(PoirotTheme.Typography.micro)
                        .foregroundStyle(PoirotTheme.Colors.green)
                } else {
                    Text("\(entry.envKeys.count) var\(entry.envKeys.count == 1 ? "" : "s")")
                        .font(PoirotTheme.Typography.micro)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
            .padding(.horizontal, PoirotTheme.Spacing.xl)
            .padding(.vertical, PoirotTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Configure \(entry.name)")
    }

    // MARK: - Step 2: Configuration

    private var configurationStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.lg) {
                // Server name
                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                    Text("Server Name")
                        .font(PoirotTheme.Typography.captionMedium)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                    TextField("e.g. github", text: $serverName)
                        .textFieldStyle(.roundedBorder)
                        .font(PoirotTheme.Typography.code)
                    Text("Key used in mcpServers object")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }

                if useCustom {
                    customCommandFields
                } else if let entry = selectedEntry {
                    catalogCommandInfo(entry)
                    envFields(entry)
                }
            }
            .padding(PoirotTheme.Spacing.xl)
        }
        .scrollIndicators(.never)
    }

    private var customCommandFields: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                Text("Command")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)
                TextField("e.g. npx", text: $customCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(PoirotTheme.Typography.code)
            }

            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                Text("Arguments")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)
                TextField("e.g. -y @scope/server-name", text: $customArgs)
                    .textFieldStyle(.roundedBorder)
                    .font(PoirotTheme.Typography.code)
                Text("Space-separated arguments")
                    .font(PoirotTheme.Typography.tiny)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
    }

    private func catalogCommandInfo(_ entry: MCPCatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Text("Command")
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
            Text(([entry.command] + entry.args).joined(separator: " "))
                .font(PoirotTheme.Typography.codeSmall)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
                .padding(PoirotTheme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgCode)
                )
        }
    }

    private func envFields(_ entry: MCPCatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.lg) {
            if entry.envKeys.isEmpty {
                HStack(spacing: PoirotTheme.Spacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.green)
                    Text("No environment variables required")
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.textSecondary)
                }
            } else {
                Text("Environment Variables")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                ForEach(entry.envKeys) { key in
                    VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
                        HStack(spacing: PoirotTheme.Spacing.xs) {
                            Text(key.label)
                                .font(PoirotTheme.Typography.captionMedium)
                                .foregroundStyle(PoirotTheme.Colors.textPrimary)

                            if key.isRequired {
                                Text("Required")
                                    .font(PoirotTheme.Typography.micro)
                                    .foregroundStyle(PoirotTheme.Colors.red)
                                    .padding(.horizontal, PoirotTheme.Spacing.xs)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.xs)
                                            .fill(PoirotTheme.Colors.red.opacity(0.1))
                                    )
                            } else {
                                Text("Optional")
                                    .font(PoirotTheme.Typography.micro)
                                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
                            }
                        }

                        if key.isSensitive {
                            SecureField(key.placeholder, text: envBinding(for: key.id))
                                .textFieldStyle(.roundedBorder)
                                .font(PoirotTheme.Typography.code)
                        } else {
                            TextField(key.placeholder, text: envBinding(for: key.id))
                                .textFieldStyle(.roundedBorder)
                                .font(PoirotTheme.Typography.code)
                        }

                        Text(key.description)
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    }
                }
            }
        }
    }

    private func envBinding(for key: String) -> Binding<String> {
        Binding(
            get: { envValues[key] ?? "" },
            set: { envValues[key] = $0 }
        )
    }

    // MARK: - Step 3: Preview

    private var previewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PoirotTheme.Spacing.lg) {
                Text("Configuration Preview")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)

                Text(previewJSON)
                    .font(PoirotTheme.Typography.codeSmall)
                    .foregroundStyle(PoirotTheme.Colors.textPrimary)
                    .textSelection(.enabled)
                    .padding(PoirotTheme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                            .fill(PoirotTheme.Colors.bgCode)
                            .overlay(
                                RoundedRectangle(cornerRadius: PoirotTheme.Radius.md)
                                    .strokeBorder(PoirotTheme.Colors.border)
                            )
                    )

                HStack(spacing: PoirotTheme.Spacing.sm) {
                    Image(systemName: "info.circle")
                        .font(PoirotTheme.Typography.caption)
                        .foregroundStyle(PoirotTheme.Colors.blue)
                    Text("This will be written to ~/.claude.json under the mcpServers key.")
                        .font(PoirotTheme.Typography.tiny)
                        .foregroundStyle(PoirotTheme.Colors.textTertiary)
                }

                if !resolvedEnv.isEmpty {
                    HStack(spacing: PoirotTheme.Spacing.sm) {
                        Image(systemName: "lock.shield")
                            .font(PoirotTheme.Typography.caption)
                            .foregroundStyle(PoirotTheme.Colors.orange)
                        Text("Sensitive values will be stored in ~/.claude.json on disk.")
                            .font(PoirotTheme.Typography.tiny)
                            .foregroundStyle(PoirotTheme.Colors.textTertiary)
                    }
                }
            }
            .padding(PoirotTheme.Spacing.xl)
        }
        .scrollIndicators(.never)
    }

    private var previewJSON: String {
        var serverDef: [String: Any] = [
            "command": resolvedCommand,
            "args": resolvedArgs,
        ]
        if !resolvedEnv.isEmpty {
            // Mask sensitive values in preview
            var masked: [String: String] = [:]
            for (key, value) in resolvedEnv {
                let isSensitive = selectedEntry?.envKeys.first(where: { $0.id == key })?.isSensitive ?? false
                masked[key] = isSensitive ? String(value.prefix(4)) + "***" : value
            }
            serverDef["env"] = masked
        }

        let wrapper: [String: Any] = [resolvedServerName: serverDef]
        guard let data = try? JSONSerialization.data(
            withJSONObject: wrapper,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            if step != .selectServer {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = WizardStep(rawValue: step.rawValue - 1) ?? .selectServer
                    }
                }
                .help("Go back")
            }

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .help("Cancel")

            Spacer()

            switch step {
            case .selectServer:
                EmptyView()
            case .configure:
                Button("Preview") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = .preview
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isConfigValid)
                .help("Preview configuration")
            case .preview:
                Button(isEditing ? "Save" : "Add Server") {
                    saveServer()
                }
                .keyboardShortcut(.defaultAction)
                .help(isEditing ? "Save server" : "Add server")
            }
        }
        .padding(.horizontal, PoirotTheme.Spacing.xl)
        .padding(.vertical, PoirotTheme.Spacing.md)
    }

    // MARK: - Actions

    private func saveServer() {
        bounceValue += 1
        if isEditing, let original = editingServer {
            SettingsWriter.updateMCPServer(
                originalName: original.rawName,
                newName: resolvedServerName,
                command: resolvedCommand,
                args: resolvedArgs,
                env: resolvedEnv
            )
        } else {
            SettingsWriter.addMCPServer(
                name: resolvedServerName,
                command: resolvedCommand,
                args: resolvedArgs,
                env: resolvedEnv
            )
        }

        appState.showToast(
            isEditing ? "Server updated" : "Server added",
            icon: "checkmark.circle.fill"
        )
        onComplete()
        dismiss()
    }

    private func populateFromEditing() {
        guard let server = editingServer else { return }
        serverName = server.rawName

        // Try to match to a catalog entry
        if let entry = MCPServerCatalog.entries.first(where: { $0.id == server.rawName }) {
            selectedEntry = entry
            useCustom = false
            for (key, value) in server.env {
                envValues[key] = value
            }
        } else {
            useCustom = true
            customCommand = server.command ?? ""
            customArgs = server.args.joined(separator: " ")
            for (key, value) in server.env {
                envValues[key] = value
            }
        }

        // Skip to configure step when editing
        step = .configure
    }
}
