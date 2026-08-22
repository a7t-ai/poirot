import Foundation

enum ClaudeConfigLoader {
    nonisolated private static var claudeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    // MARK: - Commands

    nonisolated static func loadCommands(projectPath: String? = nil) -> [ClaudeCommand] {
        var results = loadCommandsFrom(dir: claudeDir.appendingPathComponent("commands"), scope: .global)

        if let projectPath {
            let projectDir = URL(fileURLWithPath: projectPath)
                .appendingPathComponent(".claude")
                .appendingPathComponent("commands")
            results += loadCommandsFrom(dir: projectDir, scope: .project)
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func loadCommandsFrom(dir: URL, scope: ConfigScope) -> [ClaudeCommand] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> ClaudeCommand? in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let parsed = FrontmatterParser.parse(content)
                let filename = url.deletingPathExtension().lastPathComponent
                return ClaudeCommand(
                    id: "\(scope.rawValue)-\(filename)",
                    name: "/\(filename)",
                    description: parsed.metadata["description"] ?? "",
                    model: parsed.metadata["model"],
                    argumentHint: parsed.metadata["argument-hint"],
                    allowedTools: parsed.metadata["allowed-tools"],
                    outputStyle: parsed.metadata["output-style"],
                    body: parsed.body,
                    filePath: url.path,
                    scope: scope
                )
            }
    }

    // MARK: - Plans

    nonisolated static func loadPlans() -> [Plan] {
        let dir = claudeDir.appendingPathComponent("plans")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> Plan? in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let slug = url.deletingPathExtension().lastPathComponent
                return Plan(
                    id: slug,
                    name: Plan.humanize(slug: slug),
                    content: content,
                    fileURL: url
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Skills

    nonisolated static func loadSkills(projectPath: String? = nil) -> [ClaudeSkill] {
        var results = loadSkillsFrom(dir: claudeDir.appendingPathComponent("skills"), scope: .global)

        if let projectPath {
            let projectDir = URL(fileURLWithPath: projectPath)
                .appendingPathComponent(".claude")
                .appendingPathComponent("skills")
            results += loadSkillsFrom(dir: projectDir, scope: .project)
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func loadSkillsFrom(dir: URL, scope: ConfigScope) -> [ClaudeSkill] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        return entries.compactMap { folder -> ClaudeSkill? in
            let skillFile = folder.appendingPathComponent("SKILL.md")
            guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else { return nil }
            let parsed = FrontmatterParser.parse(content)
            let folderName = folder.lastPathComponent
            return ClaudeSkill(
                id: "\(scope.rawValue)-\(folderName)",
                name: parsed.metadata["name"] ?? folderName,
                description: parsed.metadata["description"] ?? "",
                model: parsed.metadata["model"],
                allowedTools: parsed.metadata["allowed-tools"],
                body: parsed.body,
                filePath: skillFile.path,
                scope: scope
            )
        }
    }

    // MARK: - MCP Servers

    nonisolated private static var claudeConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    nonisolated static func loadClaudeConfig() -> ClaudeConfig? {
        guard let data = try? Data(contentsOf: claudeConfigURL) else { return nil }
        return try? JSONDecoder().decode(ClaudeConfig.self, from: data)
    }

    nonisolated static func loadMCPServers(projectPath: String? = nil) -> [MCPServer] {
        let config = loadClaudeConfig()
        let toolPermissions = collectToolPermissions()
        var serversByName: [String: MCPServer] = [:]

        // 1. User-scope servers from top-level mcpServers in ~/.claude.json
        if let userServers = config?.mcpServers {
            for (name, definition) in userServers {
                let server = makeServer(
                    name: name,
                    definition: definition,
                    scope: .global,
                    source: .user,
                    tools: toolPermissions[name]
                )
                serversByName[name] = server
            }
        }

        if let projectPath {
            // 2. Local-scope servers from projects[path].mcpServers in ~/.claude.json
            if let localServers = config?.projects?[projectPath]?.mcpServers {
                for (name, definition) in localServers {
                    let server = makeServer(
                        name: name,
                        definition: definition,
                        scope: .project,
                        source: .user,
                        tools: toolPermissions[name]
                    )
                    serversByName[name] = server // local overrides user
                }
            }

            // 3. Project-scope servers from <project>/.mcp.json
            let mcpJsonURL = URL(fileURLWithPath: projectPath).appendingPathComponent(".mcp.json")
            if let data = try? Data(contentsOf: mcpJsonURL),
               let mcpConfig = try? JSONDecoder().decode(MCPProjectConfig.self, from: data),
               let projectServers = mcpConfig.mcpServers {
                for (name, definition) in projectServers where serversByName[name] == nil {
                    let server = makeServer(
                        name: name,
                        definition: definition,
                        scope: .project,
                        source: .user,
                        tools: toolPermissions[name]
                    )
                    serversByName[name] = server
                }
            }
        }

        // 4. Plugin MCP servers (built-in via installed plugins)
        for server in loadPluginMCPServers(toolPermissions: toolPermissions) {
            serversByName[server.rawName] = server
        }

        // 5. Cloud integration servers (claude.ai managed, e.g. Gmail)
        for server in loadCloudIntegrationServers(existingNames: Set(serversByName.keys)) {
            serversByName[server.rawName] = server
        }

        return serversByName.values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func makeServer(
        name: String,
        definition: MCPServerDefinition,
        scope: ConfigScope,
        source: MCPServerSource,
        tools: [String]?
    ) -> MCPServer {
        MCPServer(
            id: "\(source.rawValue)-\(name)",
            name: formatServerName(name),
            rawName: name,
            tools: (tools ?? []).sorted(),
            isWildcard: tools == nil,
            scope: scope,
            source: source,
            type: definition.type,
            command: definition.command,
            args: definition.args ?? [],
            env: definition.env ?? [:],
            url: definition.url
        )
    }

    /// Discovers plugin-provided MCP servers from tool permissions.
    /// Plugin MCP tools use the format: mcp__plugin_{name}_{name}__{tool}
    nonisolated private static func loadPluginMCPServers(
        toolPermissions: [String: [String]]
    ) -> [MCPServer] {
        let settings = loadSettings()
        let enabledPlugins = settings?.enabledPlugins ?? [:]

        // Find tool permission keys that start with "plugin_"
        let pluginServerNames = toolPermissions.keys.filter { $0.hasPrefix("plugin_") }
        guard !pluginServerNames.isEmpty else { return [] }

        // Load installed plugins for metadata
        let installedURL = claudeDir
            .appendingPathComponent("plugins")
            .appendingPathComponent("installed_plugins.json")
        let installed: InstalledPlugins? = {
            guard let data = try? Data(contentsOf: installedURL) else { return nil }
            return try? JSONDecoder().decode(InstalledPlugins.self, from: data)
        }()

        return pluginServerNames.compactMap { permissionName in
            // permissionName is like "plugin_context-mode_context-mode"
            // Convert underscores back to colons for the raw name: "plugin:context-mode:context-mode"
            let rawName = convertPluginPermissionToRawName(permissionName)

            // Extract the plugin identifier to check if it's enabled
            let pluginKey = findPluginKey(
                for: permissionName,
                installed: installed,
                enabledPlugins: enabledPlugins
            )

            // Only include if the plugin is enabled (or if we can't determine)
            if let key = pluginKey, enabledPlugins[key] == false {
                return nil
            }

            let tools = toolPermissions[permissionName]
            return MCPServer(
                id: "plugin-\(rawName)",
                name: formatPluginServerName(permissionName),
                rawName: rawName,
                tools: (tools ?? []).sorted(),
                isWildcard: tools == nil,
                scope: .global,
                source: .plugin,
                type: "stdio",
                command: nil,
                args: [],
                env: [:],
                url: nil
            )
        }
    }

    /// Converts a plugin permission name (plugin_context-mode_context-mode)
    /// to the raw name shown by Claude Code (plugin:context-mode:context-mode).
    nonisolated private static func convertPluginPermissionToRawName(_ permissionName: String) -> String {
        // Split on "plugin_" prefix, then rejoin parts with colons
        let withoutPrefix = String(permissionName.dropFirst("plugin_".count))
        return "plugin:" + withoutPrefix.replacingOccurrences(of: "_", with: ":")
    }

    /// Formats a plugin server name for display.
    /// "plugin_context-mode_context-mode" → "Context Mode"
    nonisolated private static func formatPluginServerName(_ permissionName: String) -> String {
        // Extract the plugin name part (first segment after "plugin_")
        let withoutPrefix = String(permissionName.dropFirst("plugin_".count))
        let parts = withoutPrefix.split(separator: "_")
        let pluginName = parts.first.map(String.init) ?? withoutPrefix
        return formatServerName(pluginName)
    }

    /// Finds the installed plugin key matching a permission name.
    nonisolated private static func findPluginKey(
        for permissionName: String,
        installed: InstalledPlugins?,
        enabledPlugins: [String: Bool]
    ) -> String? {
        let withoutPrefix = String(permissionName.dropFirst("plugin_".count))
        let parts = withoutPrefix.split(separator: "_")
        let pluginName = parts.first.map(String.init) ?? withoutPrefix

        // Match against installed plugin keys (format: "name@author")
        return enabledPlugins.keys.first { key in
            let keyParts = key.split(separator: "@", maxSplits: 1)
            let name = keyParts.first.map(String.init) ?? key
            return name == pluginName
        }
    }

    /// Loads cloud integration servers from the auth cache.
    /// Entries prefixed with "claude.ai " that aren't in mcpServers are cloud integrations.
    nonisolated private static func loadCloudIntegrationServers(
        existingNames: Set<String>
    ) -> [MCPServer] {
        let authServers = MCPServerStatusChecker.loadAuthCache()
        let cloudPrefix = "claude.ai "

        return authServers
            .filter { $0.hasPrefix(cloudPrefix) && !existingNames.contains($0) }
            .map { name in
                let displayName = String(name.dropFirst(cloudPrefix.count))
                return MCPServer(
                    id: "cloud-\(name)",
                    name: displayName,
                    rawName: name,
                    tools: [],
                    isWildcard: true,
                    scope: .global,
                    source: .cloudIntegration,
                    type: "http",
                    command: nil,
                    args: [],
                    env: [:],
                    url: nil,
                    status: .needsAuth
                )
            }
    }

    /// Collects tool permissions from settings.json keyed by server name.
    nonisolated private static func collectToolPermissions() -> [String: [String]] {
        guard let allowed = loadSettings()?.permissions?.allow else { return [:] }
        var serverTools: [String: [String]] = [:]
        for entry in allowed {
            guard entry.hasPrefix("mcp__") else { continue }
            let parts = entry.dropFirst(5)
            guard let separatorRange = parts.range(of: "__") else { continue }
            let serverName = String(parts[parts.startIndex ..< separatorRange.lowerBound])
            let toolName = String(parts[separatorRange.upperBound...])
            serverTools[serverName, default: []].append(toolName)
        }
        return serverTools
    }

    // MARK: - Plugins

    nonisolated static func loadPlugins() -> [ClaudePlugin] {
        let installedURL = claudeDir
            .appendingPathComponent("plugins")
            .appendingPathComponent("installed_plugins.json")

        guard let data = try? Data(contentsOf: installedURL),
              let installed = try? JSONDecoder().decode(InstalledPlugins.self, from: data)
        else { return [] }

        let settings = loadSettings()
        let enabled = settings?.enabledPlugins ?? [:]

        return installed.plugins.flatMap { key, versions -> [ClaudePlugin] in
            versions.map { info in
                let parts = key.split(separator: "@", maxSplits: 1)
                let pluginName = parts.first.map(String.init) ?? key
                let author = parts.count > 1 ? String(parts[1]) : ""

                return ClaudePlugin(
                    id: key,
                    name: pluginName,
                    author: author,
                    version: info.version,
                    installedAt: info.installedAt,
                    isEnabled: enabled[key] == true
                )
            }
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Output Styles

    nonisolated static func loadOutputStyles(projectPath: String? = nil) -> [OutputStyle] {
        var results = loadOutputStylesFrom(dir: claudeDir.appendingPathComponent("output-styles"), scope: .global)

        if let projectPath {
            let projectDir = URL(fileURLWithPath: projectPath)
                .appendingPathComponent(".claude")
                .appendingPathComponent("output-styles")
            results += loadOutputStylesFrom(dir: projectDir, scope: .project)
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func loadOutputStylesFrom(dir: URL, scope: ConfigScope) -> [OutputStyle] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "md" && $0.lastPathComponent != "README.md" }
            .compactMap { url -> OutputStyle? in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let parsed = FrontmatterParser.parse(content)
                let filename = url.lastPathComponent
                return OutputStyle(
                    id: "\(scope.rawValue)-\(filename)",
                    name: parsed.metadata["name"] ?? url.deletingPathExtension().lastPathComponent,
                    description: parsed.metadata["description"] ?? "",
                    filename: filename,
                    body: parsed.body,
                    filePath: url.path,
                    scope: scope
                )
            }
    }

    // MARK: - Memory Files

    /// Loads memory files for a given project directory hash within `~/.claude/projects/<hash>/memory/`.
    nonisolated static func loadMemoryFiles(projectDirName: String) -> [MemoryFile] {
        let memoryDir = claudeDir
            .appendingPathComponent("projects")
            .appendingPathComponent(projectDirName)
            .appendingPathComponent("memory")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: memoryDir, includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> MemoryFile? in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let filename = url.lastPathComponent
                return MemoryFile(
                    id: "\(projectDirName)-\(filename)",
                    name: MemoryFile.displayName(from: filename),
                    filename: filename,
                    content: content,
                    fileURL: url,
                    projectID: projectDirName
                )
            }
            .sorted { lhs, rhs in
                // MEMORY.md always first, then alphabetical
                if lhs.isMain { return true }
                if rhs.isMain { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// Returns the memory directory path for a given project hash.
    nonisolated static func memoryDirectoryPath(projectDirName: String) -> String {
        claudeDir
            .appendingPathComponent("projects")
            .appendingPathComponent(projectDirName)
            .appendingPathComponent("memory")
            .path
    }

    /// Returns all project directory names that have at least one memory file.
    nonisolated static func projectsWithMemory() -> [(dirName: String, count: Int)] {
        let projectsDir = claudeDir.appendingPathComponent("projects")
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return projectDirs.compactMap { dirURL -> (String, Int)? in
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: dirURL.path, isDirectory: &isDir),
                  isDir.boolValue else { return nil }

            let memoryDir = dirURL.appendingPathComponent("memory")
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: memoryDir, includingPropertiesForKeys: nil
            ) else { return nil }

            let mdCount = files.filter { $0.pathExtension == "md" }.count
            guard mdCount > 0 else { return nil }
            return (dirURL.lastPathComponent, mdCount)
        }
    }

    /// Loads `.md` memory files from a user-added folder (non-recursive). Each file carries the
    /// folder's name as its `sourceLabel` so custom sources are distinguishable from projects.
    nonisolated static func loadMemoryFiles(customFolder folder: URL) -> [MemoryFile] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil
        ) else { return [] }

        let label = folder.lastPathComponent
        let projectID = "\(MemoryFile.customSourcePrefix)\(folder.path)"
        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> MemoryFile? in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let filename = url.lastPathComponent
                return MemoryFile(
                    id: "\(projectID)/\(filename)",
                    name: MemoryFile.displayName(from: filename),
                    filename: filename,
                    content: content,
                    fileURL: url,
                    projectID: projectID,
                    sourceLabel: label
                )
            }
            .sorted { lhs, rhs in
                if lhs.isMain { return true }
                if rhs.isMain { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// Counts the `.md` files in a user-added memory folder.
    nonisolated static func customMemoryFileCount(folder: URL) -> Int {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "md" }.count ?? 0
    }

    /// Counts total memory files across all projects and any user-added folders.
    nonisolated static func totalMemoryFileCount() -> Int {
        let projectCount = projectsWithMemory().reduce(0) { $0 + $1.count }
        let customCount = MemorySourcesStore.loadFolders()
            .reduce(0) { $0 + customMemoryFileCount(folder: $1) }
        return projectCount + customCount
    }

    // MARK: - Settings

    nonisolated static func loadSettings() -> ClaudeSettings? {
        let url = claudeDir.appendingPathComponent("settings.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ClaudeSettings.self, from: data)
    }

    // MARK: - Project Model

    nonisolated static func loadProjectModel(projectPath: String) -> String? {
        let url = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(ClaudeSettings.self, from: data)
        else { return nil }
        return settings.model
    }

    // MARK: - Hooks

    nonisolated static func loadHooks(projectPath: String? = nil) -> [HookEntry] {
        var results = loadHooksFrom(url: SettingsWriter.settingsFileURL(), scope: .global)
        if let projectPath {
            let projectURL = URL(fileURLWithPath: projectPath)
                .appendingPathComponent(".claude")
                .appendingPathComponent("settings.json")
            results += loadHooksFrom(url: projectURL, scope: .project)
        }
        return results
    }

    nonisolated private static func loadHooksFrom(url: URL, scope: ConfigScope) -> [HookEntry] {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = dict["hooks"] as? [String: Any]
        else { return [] }

        var results: [HookEntry] = []
        for (eventKey, value) in hooks {
            guard let event = HookEvent(rawValue: eventKey),
                  let matcherGroups = value as? [[String: Any]]
            else { continue }

            for (groupIndex, group) in matcherGroups.enumerated() {
                let matcher = group["matcher"] as? String
                let handlersArray = group["hooks"] as? [[String: Any]] ?? []
                let handlers = handlersArray.compactMap { parseHandler($0) }
                guard !handlers.isEmpty else { continue }

                results.append(HookEntry(
                    id: "\(scope.rawValue)-\(eventKey)-\(groupIndex)",
                    event: event,
                    matcherGroupIndex: groupIndex,
                    matcherGroup: HookMatcherGroup(matcher: matcher, handlers: handlers),
                    scope: scope
                ))
            }
        }
        return results.sorted { $0.event.rawValue < $1.event.rawValue }
    }

    nonisolated private static func parseHandler(_ dict: [String: Any]) -> HookHandler? {
        guard let typeStr = dict["type"] as? String,
              let type = HookHandlerType(rawValue: typeStr)
        else { return nil }
        return HookHandler(
            type: type,
            command: dict["command"] as? String,
            url: dict["url"] as? String,
            timeout: dict["timeout"] as? Int,
            statusMessage: dict["statusMessage"] as? String
        )
    }

    // MARK: - Custom Agents

    nonisolated static var agentsDir: URL {
        claudeDir.appendingPathComponent("agents")
    }

    nonisolated static func loadCustomAgents() -> [SubAgent] {
        let dir = agentsDir
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> SubAgent? in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let parsed = FrontmatterParser.parse(content)
                let filename = url.deletingPathExtension().lastPathComponent
                let name = parsed.metadata["name"] ?? filename
                let tools = parsed.metadata["tools"]?
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty } ?? []
                let color = parsed.metadata["color"].flatMap { AgentColor(rawValue: $0) }
                let memory = parsed.metadata["memory"].flatMap { AgentMemory(rawValue: $0) }
                return SubAgent(
                    id: "custom-\(filename)",
                    name: name,
                    icon: "person.crop.circle.badge.plus",
                    description: parsed.metadata["description"] ?? "",
                    tools: tools,
                    model: parsed.metadata["model"],
                    color: color,
                    prompt: parsed.body.isEmpty ? nil : parsed.body,
                    filePath: url.path,
                    memory: memory,
                    scope: .global
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated static func saveAgent(_ agent: SubAgent) -> String? {
        let dir = agentsDir
        ensureDirectory(dir)

        let desiredFilename = agent.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        let url: URL
        if let existing = agent.filePath {
            let existingURL = URL(fileURLWithPath: existing)
            let existingFilename = existingURL.deletingPathExtension().lastPathComponent
            if existingFilename == desiredFilename {
                url = existingURL
            } else {
                url = uniqueFile(in: dir, baseName: desiredFilename, ext: "md")
            }
        } else {
            url = uniqueFile(in: dir, baseName: desiredFilename, ext: "md")
        }

        var frontmatter = "---\n"
        frontmatter += "name: \(agent.name)\n"
        frontmatter += "description: \(agent.description)\n"
        if !agent.tools.isEmpty {
            frontmatter += "tools: \(agent.tools.joined(separator: ", "))\n"
        }
        if let model = agent.model, !model.isEmpty {
            frontmatter += "model: \(model)\n"
        }
        if let color = agent.color {
            frontmatter += "color: \(color.rawValue)\n"
        }
        if let memory = agent.memory {
            frontmatter += "memory: \(memory.rawValue)\n"
        }
        frontmatter += "---\n"

        let content = frontmatter + "\n" + (agent.prompt ?? "")
        guard (try? content.write(to: url, atomically: true, encoding: .utf8)) != nil else { return nil }

        // Delete old file if renamed
        if let existing = agent.filePath, url.path != existing {
            try? FileManager.default.removeItem(atPath: existing)
        }

        return url.path
    }

    nonisolated static func createAgentTemplate() -> String? {
        let dir = agentsDir
        ensureDirectory(dir)
        let url = uniqueFile(in: dir, baseName: "new-agent", ext: "md")
        let template = """
        ---
        name: New Agent
        description: Describe what this agent does
        tools: Glob, Grep, Read, Bash
        model: sonnet
        color: orange
        ---

        Your agent instructions go here.
        """
        guard (try? template.write(to: url, atomically: true, encoding: .utf8)) != nil else { return nil }
        return url.path
    }

    nonisolated static func exportAgentAsJSON(_ agent: SubAgent) -> Data? {
        let dict: [String: Any] = [
            "name": agent.name,
            "description": agent.description,
            "tools": agent.tools,
            "model": agent.model ?? "",
            "color": agent.color?.rawValue ?? "",
            "prompt": agent.prompt ?? "",
            "memory": agent.memory?.rawValue ?? "",
        ]
        return try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    nonisolated static func importAgentFromJSON(_ data: Data) -> String? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = dict["name"] as? String
        else { return nil }

        let tools = (dict["tools"] as? [String]) ?? []
        let agent = SubAgent(
            id: UUID().uuidString,
            name: name,
            icon: "person.crop.circle.badge.plus",
            description: dict["description"] as? String ?? "",
            tools: tools,
            model: dict["model"] as? String,
            color: (dict["color"] as? String).flatMap { AgentColor(rawValue: $0) },
            prompt: dict["prompt"] as? String,
            memory: (dict["memory"] as? String).flatMap { AgentMemory(rawValue: $0) },
            scope: .global
        )
        return saveAgent(agent)
    }

    // MARK: - Template Creation

    nonisolated static func createCommandTemplate() -> String? {
        let dir = claudeDir.appendingPathComponent("commands")
        ensureDirectory(dir)
        let url = uniqueFile(in: dir, baseName: "new-command", ext: "md")
        let template = """
        ---
        description: Describe what this command does
        # model: claude-sonnet-4-6
        # allowed-tools: Bash, Read, Write
        # argument-hint: <arg>
        ---

        Your command instructions go here.
        """
        guard (try? template.write(to: url, atomically: true, encoding: .utf8)) != nil else { return nil }
        return url.path
    }

    nonisolated static func createSkillTemplate() -> String? {
        let dir = claudeDir.appendingPathComponent("skills").appendingPathComponent("new-skill")

        // Handle uniqueness by varying the folder name
        var finalDir = dir
        var counter = 2
        while FileManager.default.fileExists(atPath: finalDir.appendingPathComponent("SKILL.md").path) {
            finalDir = claudeDir.appendingPathComponent("skills").appendingPathComponent("new-skill-\(counter)")
            counter += 1
        }
        ensureDirectory(finalDir)

        let url = finalDir.appendingPathComponent("SKILL.md")
        let template = """
        ---
        name: New Skill
        description: Describe what this skill does
        # model: claude-sonnet-4-6
        # allowed-tools: Bash, Read, Write, Edit
        ---

        Your skill instructions go here.
        """
        guard (try? template.write(to: url, atomically: true, encoding: .utf8)) != nil else { return nil }
        return url.path
    }

    nonisolated static func createOutputStyleTemplate() -> String? {
        let dir = claudeDir.appendingPathComponent("output-styles")
        ensureDirectory(dir)
        let url = uniqueFile(in: dir, baseName: "new-style", ext: "md")
        let template = """
        ---
        name: New Style
        description: Describe this output style
        ---

        Define your output formatting instructions here.
        """
        guard (try? template.write(to: url, atomically: true, encoding: .utf8)) != nil else { return nil }
        return url.path
    }

    nonisolated static func deleteConfigFile(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        // For skills, remove the parent directory if it's a SKILL.md
        if url.lastPathComponent == "SKILL.md" {
            return (try? FileManager.default.removeItem(at: url.deletingLastPathComponent())) != nil
        }
        return (try? FileManager.default.removeItem(at: url)) != nil
    }

    // MARK: - Helpers

    nonisolated private static func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    nonisolated private static func uniqueFile(in dir: URL, baseName: String, ext: String) -> URL {
        var url = dir.appendingPathComponent("\(baseName).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("\(baseName)-\(counter).\(ext)")
            counter += 1
        }
        return url
    }

    nonisolated private static func formatServerName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

// MARK: - Installed Plugins JSON Model

nonisolated private struct InstalledPlugins: Codable, Sendable {
    let plugins: [String: [PluginInfo]]

    nonisolated struct PluginInfo: Codable, Sendable {
        let version: String
        let installedAt: String
    }
}
