import SwiftUI

struct ClaudeCodeProvider: ProviderDescribing {
    let name = String(localized: "Claude Code")
    let assistantName = String(localized: "Claude")
    let assistantAvatarLetter = "C"
    let statusActiveText = String(localized: "Claude Code active")
    let companionTagline = String(localized: "Your Claude Code companion")
    let capabilities: Set<ProviderCapability> = Set(ProviderCapability.allCases)
    let projectsPath = "~/.claude/projects"
    let cliPath = "/usr/local/bin/claude"
    let cliLabel = String(localized: "Claude Code Path")
    let defaultModelName = ClaudeModelCatalog.defaultModelName
    /// Baseline current lineup. The Models screen extends this with models discovered in your
    /// sessions; see `ClaudeModelCatalog`.
    var supportedModels: [String] { ClaudeModelCatalog.curatedNames }

    let toolDefinitions: [String: ToolDefinition] = [
        "Read": ToolDefinition(displayName: String(localized: "Read"), icon: "doc.text"),
        "Write": ToolDefinition(displayName: String(localized: "Write"), icon: "doc.text.fill"),
        "Edit": ToolDefinition(displayName: String(localized: "Edit"), icon: "pencil"),
        "Bash": ToolDefinition(displayName: String(localized: "Bash"), icon: "terminal"),
        "Glob": ToolDefinition(displayName: String(localized: "Glob"), icon: "magnifyingglass"),
        "Grep": ToolDefinition(displayName: String(localized: "Grep"), icon: "text.magnifyingglass"),
        "Task": ToolDefinition(displayName: String(localized: "Task"), icon: "checklist"),
    ]

    let configurationItems: [ConfigurationItem] = [
        ConfigurationItem(
            id: "skills",
            icon: "bolt.fill",
            iconColor: PoirotTheme.Colors.accent,
            title: String(localized: "Skills"),
            count: String(localized: "8 active"),
            description: String(localized: "Reusable skill modules that guide Claude through complex tasks"),
            requiredCapability: .skills
        ),
        ConfigurationItem(
            id: "commands",
            icon: "slash.circle",
            iconColor: PoirotTheme.Colors.blue,
            title: String(localized: "Slash Commands"),
            count: String(localized: "12 available"),
            description: String(localized: "Slash commands for quick access to common workflows"),
            requiredCapability: .commands
        ),
        ConfigurationItem(
            id: "plans",
            icon: "list.bullet.clipboard.fill",
            iconColor: PoirotTheme.Colors.teal,
            title: String(localized: "Plans"),
            count: String(localized: "Saved"),
            description: String(localized: "Named plan files saved by Claude Code sessions"),
            requiredCapability: .plans
        ),
        ConfigurationItem(
            id: "mcpServers",
            icon: "powerplug.fill",
            iconColor: PoirotTheme.Colors.green,
            title: String(localized: "MCP Servers"),
            count: String(localized: "5 connected"),
            description: String(localized: "External services connected via the Model Context Protocol"),
            requiredCapability: .mcpServers
        ),
        ConfigurationItem(
            id: "models",
            icon: "brain.fill",
            iconColor: PoirotTheme.Colors.purple,
            title: String(localized: "Models"),
            count: ClaudeModelCatalog.defaultModelName,
            description: String(localized: "Default and per-project model preferences"),
            requiredCapability: .models
        ),
        ConfigurationItem(
            id: "subAgents",
            icon: "person.2.fill",
            iconColor: PoirotTheme.Colors.orange,
            title: String(localized: "Sub-agents"),
            count: String(localized: "4+ types"),
            description: String(localized: "Built-in and custom agents for explore, plan, and code tasks"),
            requiredCapability: .subAgents
        ),
        ConfigurationItem(
            id: "memory",
            icon: "brain.head.profile.fill",
            iconColor: PoirotTheme.Colors.purple,
            title: String(localized: "Memory"),
            count: String(localized: "Per-project"),
            description: String(localized: "Auto-memory files that Claude loads into every conversation"),
            requiredCapability: .memory
        ),
        ConfigurationItem(
            id: "hooks",
            icon: "arrow.triangle.branch",
            iconColor: PoirotTheme.Colors.orange,
            title: String(localized: "Hooks"),
            count: String(localized: "Event-driven"),
            description: String(localized: "Event-driven shell commands and HTTP endpoints"),
            requiredCapability: .hooks
        ),
        ConfigurationItem(
            id: "plugins",
            icon: "puzzlepiece.fill",
            iconColor: PoirotTheme.Colors.teal,
            title: String(localized: "Plugins"),
            count: String(localized: "Available"),
            description: String(localized: "Extensions that add capabilities to Claude Code"),
            requiredCapability: .plugins
        ),
        ConfigurationItem(
            id: "outputStyles",
            icon: "speaker.wave.3.fill",
            iconColor: PoirotTheme.Colors.red,
            title: String(localized: "Output Styles"),
            count: String(localized: "TTS ready"),
            description: String(localized: "Custom response formatting and tone presets"),
            requiredCapability: .outputStyles
        ),
    ]
}
