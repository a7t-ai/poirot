import Foundation

nonisolated struct Session: Identifiable, Hashable {
    let id: String
    let projectPath: String
    let messages: [Message]
    let startedAt: Date
    let model: String?
    let totalTokens: Int
    let fileURL: URL?
    let cachedTitle: String?
    let cachedPreview: String?
    let cachedTurnCount: Int?
    let firstPrompt: String?
    let agentId: String?
    let isSidechain: Bool
    let parentSessionId: String?
    let endedAt: Date?
    let agentType: String?
    let agentDescription: String?
    /// Lowercased, length-capped concatenation of the conversation's free text — user prompts,
    /// assistant replies, thinking, and tool calls/results. Lets global search match sessions by
    /// what was discussed inside them, not just their title. Empty when built without indexing.
    let searchableText: String

    init(
        id: String,
        projectPath: String,
        messages: [Message],
        startedAt: Date,
        model: String?,
        totalTokens: Int,
        fileURL: URL? = nil,
        cachedTitle: String? = nil,
        cachedPreview: String? = nil,
        cachedTurnCount: Int? = nil,
        firstPrompt: String? = nil,
        agentId: String? = nil,
        isSidechain: Bool = false,
        parentSessionId: String? = nil,
        endedAt: Date? = nil,
        agentType: String? = nil,
        agentDescription: String? = nil,
        searchableText: String = ""
    ) {
        self.id = id
        self.projectPath = projectPath
        self.messages = messages
        self.startedAt = startedAt
        self.model = model
        self.totalTokens = totalTokens
        self.fileURL = fileURL
        self.cachedTitle = cachedTitle
        self.cachedPreview = cachedPreview
        self.cachedTurnCount = cachedTurnCount
        self.firstPrompt = firstPrompt
        self.agentId = agentId
        self.isSidechain = isSidechain
        self.parentSessionId = parentSessionId
        self.endedAt = endedAt
        self.agentType = agentType
        self.agentDescription = agentDescription
        self.searchableText = searchableText
    }

    var projectName: String {
        (projectPath as NSString).lastPathComponent
    }

    var title: String {
        let raw = cachedTitle
            ?? messages.first(where: { $0.role == .user })?.textContent
            ?? String(localized: "Untitled session")
        return raw.strippingXMLTags()
    }

    var preview: String? {
        let raw = cachedPreview ?? messages.first(where: { $0.role == .assistant })?.textContent
        return raw?.strippingXMLTags()
    }

    var turnCount: Int {
        cachedTurnCount ?? messages.filter { $0.role == .user }.count
    }

    nonisolated(unsafe) private static let relativeDateFormatter = RelativeDateTimeFormatter()

    var timeAgo: String {
        Self.relativeDateFormatter.localizedString(for: startedAt, relativeTo: .now)
    }

    var isSubAgent: Bool { parentSessionId != nil }

    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Helpers

nonisolated private extension String {
    static let xmlTagRegex = try? NSRegularExpression(pattern: "<[^>]+>")

    func strippingXMLTags() -> String {
        guard let regex = Self.xmlTagRegex else { return self }
        let range = NSRange(startIndex..., in: self)
        let stripped = regex.stringByReplacingMatches(in: self, range: range, withTemplate: "")
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? self : trimmed
    }
}
