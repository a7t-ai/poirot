import Foundation

nonisolated struct Message: Identifiable, Hashable {
    let id: String
    let role: Role
    let content: [ContentBlock]
    let timestamp: Date
    let model: String?
    let tokenUsage: TokenUsage?

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    var textContent: String {
        content
            .compactMap { block in
                if case let .text(text) = block {
                    return text
                }
                return nil
            }
            .joined(separator: "\n")
    }

    var toolBlocks: [ToolUse] {
        content.compactMap { block in
            if case let .toolUse(tool) = block {
                return tool
            }
            return nil
        }
    }

    var toolResultBlocks: [ToolResult] {
        content.compactMap { block in
            if case let .toolResult(result) = block {
                return result
            }
            return nil
        }
    }
}

nonisolated enum ContentBlock: Hashable {
    case text(String)
    case toolUse(ToolUse)
    case toolResult(ToolResult)
    case thinking(String)
}

nonisolated struct ToolUse: Identifiable, Hashable {
    let id: String
    let name: String
    let input: [String: String]

    var filePath: String? {
        input["file_path"] ?? input["path"]
    }

    var command: String? { input["command"] }
    var isBash: Bool { name == "Bash" }
    var isEdit: Bool { name == "Edit" }
    var oldString: String? { input["old_string"] }
    var newString: String? { input["new_string"] }
    var hasDiffData: Bool { isEdit && oldString != nil && newString != nil }
}

nonisolated struct ToolResult: Identifiable, Hashable {
    let id: String
    let toolUseId: String
    let content: String
    let isError: Bool
}

// MARK: - Content Segments

extension Message {
    enum ContentSegment: Equatable {
        case text(String)
        case tools([ToolUse])
        case thinking(String)
    }

    var textAndToolSegments: [ContentSegment] {
        var segments: [ContentSegment] = []
        var currentTexts: [String] = []
        var currentTools: [ToolUse] = []

        for block in content {
            switch block {
            case let .text(text):
                if !currentTools.isEmpty {
                    segments.append(.tools(currentTools))
                    currentTools = []
                }
                currentTexts.append(text)
            case let .toolUse(tool):
                if !currentTexts.isEmpty {
                    segments.append(.text(currentTexts.joined(separator: "\n")))
                    currentTexts = []
                }
                currentTools.append(tool)
            case let .thinking(text):
                if !currentTexts.isEmpty {
                    segments.append(.text(currentTexts.joined(separator: "\n")))
                    currentTexts = []
                }
                if !currentTools.isEmpty {
                    segments.append(.tools(currentTools))
                    currentTools = []
                }
                segments.append(.thinking(text))
            case .toolResult:
                break
            }
        }

        if !currentTexts.isEmpty {
            segments.append(.text(currentTexts.joined(separator: "\n")))
        }
        if !currentTools.isEmpty {
            segments.append(.tools(currentTools))
        }

        return segments
    }
}

nonisolated struct TokenUsage: Hashable {
    let input: Int
    let output: Int
    let cacheRead: Int
    let cacheCreation: Int

    init(input: Int, output: Int, cacheRead: Int = 0, cacheCreation: Int = 0) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheCreation = cacheCreation
    }

    /// Billable token volume for this turn (prompt input + generated output). Used for the
    /// session's cumulative token total.
    var total: Int { input + output }

    /// Total prompt tokens the model held as context on this turn — fresh input plus cached
    /// reads and cache writes. This is what fills the context window.
    var contextTokens: Int { input + cacheRead + cacheCreation }

    /// Fraction (0...1) of the prompt served from cache rather than sent fresh.
    var cacheHitRate: Double {
        contextTokens > 0 ? Double(cacheRead) / Double(contextTokens) : 0
    }

    var formatted: String {
        let total = Double(total)
        if total >= 1000 {
            return String(format: "%.1fk", total / 1000)
        }
        return "\(self.total)"
    }
}
