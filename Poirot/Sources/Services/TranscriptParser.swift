import Foundation

nonisolated struct TranscriptParser {
    nonisolated(unsafe) private let dateFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt
    }()

    func parse(
        fileURL: URL,
        projectPath: String,
        sessionId: String,
        indexStartedAt: Date?,
        isSidechain: Bool = false
    ) -> Session? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return nil }

        let lines = text.components(separatedBy: .newlines)
        let records = lines.compactMap { line -> [String: Any]? in
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { return nil }
            return json
        }

        let filtered = records.filter { record in
            guard let type = record["type"] as? String,
                  type == "user" || type == "assistant"
            else { return false }

            if !isSidechain, record["isSidechain"] as? Bool == true { return false }

            if type == "assistant" {
                let message = record["message"] as? [String: Any]
                if message?["model"] as? String == "<synthetic>" { return false }
            }

            return true
        }

        guard !filtered.isEmpty else { return nil }

        var messages: [Message] = []
        var pendingGroupId: String?
        var pendingGroupBlocks: [ContentBlock] = []
        var pendingGroupTimestamp: Date?
        var pendingGroupModel: String?
        var pendingGroupUsage: TokenUsage?

        func flushPendingGroup() {
            guard let groupId = pendingGroupId, !pendingGroupBlocks.isEmpty else { return }
            messages.append(Message(
                id: groupId,
                role: .assistant,
                content: pendingGroupBlocks,
                timestamp: pendingGroupTimestamp ?? Date.distantPast,
                model: pendingGroupModel,
                tokenUsage: pendingGroupUsage
            ))
            pendingGroupId = nil
            pendingGroupBlocks = []
            pendingGroupTimestamp = nil
            pendingGroupModel = nil
            pendingGroupUsage = nil
        }

        for record in filtered {
            let type = record["type"] as? String ?? ""
            let message = record["message"] as? [String: Any] ?? [:]
            let timestamp = parseTimestamp(record["timestamp"]) ?? Date.distantPast

            if type == "user" {
                flushPendingGroup()

                let content = message["content"]
                let blocks = parseUserContent(content)
                let uuid = record["uuid"] as? String ?? UUID().uuidString

                messages.append(Message(
                    id: uuid,
                    role: .user,
                    content: blocks,
                    timestamp: timestamp,
                    model: nil,
                    tokenUsage: nil
                ))
            } else if type == "assistant" {
                let msgId = message["id"] as? String ?? UUID().uuidString
                let model = message["model"] as? String
                let usage = parseUsage(message["usage"] as? [String: Any])

                if msgId == pendingGroupId {
                    let newBlocks = parseAssistantContent(message["content"])
                    pendingGroupBlocks.append(contentsOf: newBlocks)
                } else {
                    flushPendingGroup()
                    pendingGroupId = msgId
                    pendingGroupBlocks = parseAssistantContent(message["content"])
                    pendingGroupTimestamp = timestamp
                    pendingGroupModel = model
                    pendingGroupUsage = usage
                }
            }
        }

        flushPendingGroup()

        guard !messages.isEmpty else { return nil }

        let earliestTimestamp = messages.map(\.timestamp).min()
        let startedAt = earliestTimestamp ?? indexStartedAt ?? Date.distantPast

        let firstModel = messages.first(where: { $0.role == .assistant })?.model

        let totalTokens = messages
            .filter { $0.role == .assistant }
            .compactMap(\.tokenUsage)
            .reduce(0) { $0 + $1.total }

        return Session(
            id: sessionId,
            projectPath: projectPath,
            messages: messages,
            startedAt: startedAt,
            model: firstModel,
            totalTokens: totalTokens,
            fileURL: fileURL
        )
    }

    // MARK: - Header Parse (fast — reads only first lines)

    func parseHeader(
        fileURL: URL,
        projectPath: String,
        sessionId: String
    ) -> Session? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }

        let chunkSize = 8192
        var buffer = ""
        var linesProcessed = 0
        let maxLines = 50

        var firstUserText: String?
        var firstAssistantText: String?
        var earliestTimestamp: Date?

        outer: while let data = try? handle.read(upToCount: chunkSize), !data.isEmpty {
            guard let chunk = String(data: data, encoding: .utf8) else { break }
            buffer += chunk

            while let newlineRange = buffer.range(of: "\n") {
                let line = String(buffer[buffer.startIndex ..< newlineRange.lowerBound])
                buffer = String(buffer[newlineRange.upperBound...])
                linesProcessed += 1

                if linesProcessed > maxLines { break outer }
                guard !line.isEmpty,
                      let lineData = line.data(using: .utf8),
                      let record = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
                else { continue }

                guard let type = record["type"] as? String,
                      type == "user" || type == "assistant"
                else { continue }

                if record["isSidechain"] as? Bool == true { continue }

                let message = record["message"] as? [String: Any] ?? [:]

                if type == "assistant" {
                    if message["model"] as? String == "<synthetic>" { continue }
                }

                if let ts = parseTimestamp(record["timestamp"]) {
                    if earliestTimestamp == nil || ts < earliestTimestamp! {
                        earliestTimestamp = ts
                    }
                }

                if type == "user", firstUserText == nil {
                    let content = message["content"]
                    if let str = content as? String, !str.isEmpty {
                        firstUserText = str
                    } else if let array = content as? [[String: Any]] {
                        firstUserText = array.first(where: { $0["type"] as? String == "text" })?["text"] as? String
                    }
                }

                if type == "assistant", firstAssistantText == nil {
                    if let array = message["content"] as? [[String: Any]] {
                        for block in array where block["type"] as? String == "text" {
                            if let text = block["text"] as? String,
                               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                firstAssistantText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                break
                            }
                        }
                    }
                }

                if firstUserText != nil, firstAssistantText != nil, earliestTimestamp != nil { break outer }
            }

            if data.count < chunkSize { break }
        }

        guard firstUserText != nil || earliestTimestamp != nil else { return nil }

        return Session(
            id: sessionId,
            projectPath: projectPath,
            messages: [],
            startedAt: earliestTimestamp ?? Date.distantPast,
            model: nil,
            totalTokens: 0,
            fileURL: fileURL,
            cachedTitle: firstUserText,
            cachedPreview: firstAssistantText,
            cachedTurnCount: nil
        )
    }

    // MARK: - Summary Parse

    func parseSummary(
        fileURL: URL,
        projectPath: String,
        sessionId: String,
        indexStartedAt: Date?,
        firstPrompt: String? = nil,
        agentId: String? = nil,
        isSidechain: Bool = false,
        parentSessionId: String? = nil,
        agentType: String? = nil,
        agentDescription: String? = nil
    ) -> Session? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return nil }

        let lines = text.components(separatedBy: .newlines)

        var firstUserText: String?
        var firstAssistantText: String?
        var userCount = 0
        var firstAssistantModel: String?
        var earliestTimestamp: Date?
        var latestTimestamp: Date?
        var totalTokens = 0
        var seenMsgIds: Set<String> = []

        for line in lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let record = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }

            guard let type = record["type"] as? String,
                  type == "user" || type == "assistant"
            else { continue }

            if !isSidechain, record["isSidechain"] as? Bool == true { continue }

            let message = record["message"] as? [String: Any] ?? [:]

            if type == "assistant" {
                if message["model"] as? String == "<synthetic>" { continue }
            }

            if let ts = parseTimestamp(record["timestamp"]) {
                if earliestTimestamp == nil || ts < earliestTimestamp! {
                    earliestTimestamp = ts
                }
                if latestTimestamp == nil || ts > latestTimestamp! {
                    latestTimestamp = ts
                }
            }

            if type == "user" {
                userCount += 1
                if firstUserText == nil {
                    let content = message["content"]
                    if let str = content as? String, !str.isEmpty {
                        firstUserText = str
                    } else if let array = content as? [[String: Any]] {
                        firstUserText = array.first(where: { $0["type"] as? String == "text" })?["text"] as? String
                    }
                }
            } else if type == "assistant" {
                let msgId = message["id"] as? String ?? UUID().uuidString
                if firstAssistantModel == nil {
                    firstAssistantModel = message["model"] as? String
                }
                if firstAssistantText == nil {
                    if let array = message["content"] as? [[String: Any]] {
                        for block in array where block["type"] as? String == "text" {
                            if let text = block["text"] as? String,
                               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                firstAssistantText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                break
                            }
                        }
                    }
                }
                if !seenMsgIds.contains(msgId) {
                    seenMsgIds.insert(msgId)
                    if let usage = message["usage"] as? [String: Any] {
                        totalTokens += (usage["input_tokens"] as? Int ?? 0) + (usage["output_tokens"] as? Int ?? 0)
                    }
                }
            }
        }

        guard userCount > 0 || !seenMsgIds.isEmpty else { return nil }

        let startedAt = earliestTimestamp ?? indexStartedAt ?? Date.distantPast

        return Session(
            id: sessionId,
            projectPath: projectPath,
            messages: [],
            startedAt: startedAt,
            model: firstAssistantModel,
            totalTokens: totalTokens,
            fileURL: fileURL,
            cachedTitle: firstUserText,
            cachedPreview: firstAssistantText,
            cachedTurnCount: userCount,
            firstPrompt: firstPrompt,
            agentId: agentId,
            isSidechain: isSidechain,
            parentSessionId: parentSessionId,
            endedAt: latestTimestamp,
            agentType: agentType,
            agentDescription: agentDescription
        )
    }

    // MARK: - User Content

    private func parseUserContent(_ content: Any?) -> [ContentBlock] {
        if let text = content as? String {
            return text.isEmpty ? [] : [.text(text)]
        }

        guard let array = content as? [[String: Any]] else { return [] }

        return array.compactMap { block -> ContentBlock? in
            let type = block["type"] as? String
            switch type {
            case "tool_result":
                return parseToolResultBlock(block)
            case "text":
                if let text = block["text"] as? String, !text.isEmpty {
                    return .text(text)
                }
                return nil
            default:
                return nil
            }
        }
    }

    // MARK: - Assistant Content

    private func parseAssistantContent(_ content: Any?) -> [ContentBlock] {
        guard let array = content as? [[String: Any]] else { return [] }

        return array.compactMap { block -> ContentBlock? in
            let type = block["type"] as? String
            switch type {
            case "text":
                if let text = block["text"] as? String, !text.isEmpty {
                    return .text(text)
                }
                return nil
            case "thinking":
                if let text = block["thinking"] as? String, !text.isEmpty {
                    return .thinking(text)
                }
                return nil
            case "tool_use":
                return parseToolUseBlock(block)
            default:
                return nil
            }
        }
    }

    // MARK: - Tool Blocks

    private func parseToolUseBlock(_ block: [String: Any]) -> ContentBlock? {
        guard let id = block["id"] as? String,
              let name = block["name"] as? String
        else { return nil }

        let rawInput = block["input"] as? [String: Any] ?? [:]
        var stringInput: [String: String] = [:]
        for (key, value) in rawInput {
            if let str = stringifyValue(value) {
                stringInput[key] = str
            }
        }

        return .toolUse(ToolUse(id: id, name: name, input: stringInput))
    }

    private func parseToolResultBlock(_ block: [String: Any]) -> ContentBlock? {
        let toolUseId = block["tool_use_id"] as? String ?? ""
        let isError = block["is_error"] as? Bool ?? false
        let content = normalizeToolResultContent(block["content"])

        return .toolResult(ToolResult(
            id: UUID().uuidString,
            toolUseId: toolUseId,
            content: content,
            isError: isError
        ))
    }

    // MARK: - Helpers

    private func stringifyValue(_ value: Any) -> String? {
        if let str = value as? String { return str }
        if let num = value as? NSNumber {
            if CFBooleanGetTypeID() == CFGetTypeID(num) {
                return num.boolValue ? "true" : "false"
            }
            return num.stringValue
        }
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }

    private func normalizeToolResultContent(_ content: Any?) -> String {
        if let str = content as? String { return str }

        guard let array = content as? [[String: Any]] else { return "" }

        let texts = array.compactMap { block -> String? in
            guard block["type"] as? String == "text" else { return nil }
            return block["text"] as? String
        }

        return texts.joined(separator: "\n")
    }

    private func parseTimestamp(_ value: Any?) -> Date? {
        guard let str = value as? String else { return nil }
        return dateFormatter.date(from: str)
    }

    private func parseUsage(_ usage: [String: Any]?) -> TokenUsage? {
        guard let usage else { return nil }
        let input = usage["input_tokens"] as? Int ?? 0
        let output = usage["output_tokens"] as? Int ?? 0
        let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
        let cacheCreation = usage["cache_creation_input_tokens"] as? Int ?? 0
        return TokenUsage(input: input, output: output, cacheRead: cacheRead, cacheCreation: cacheCreation)
    }
}
