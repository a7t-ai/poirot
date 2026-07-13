@testable import Poirot
import Foundation
import Testing

// swiftlint:disable file_length type_body_length

@Suite("TranscriptParser")
struct TranscriptParserTests {
    private let parser = TranscriptParser()

    // MARK: - Helpers

    private func makeTempFile(_ content: String) throws -> (URL, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("poirot-parser-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("test-session.jsonl")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return (dir, file)
    }

    private func userRecord(
        content: Any,
        uuid: String = UUID().uuidString,
        timestamp: String = "2026-01-28T10:00:00.000Z",
        isSidechain: Bool = false
    ) -> String {
        let message: [String: Any] = ["role": "user", "content": content]
        let record: [String: Any] = [
            "type": "user",
            "uuid": uuid,
            "timestamp": timestamp,
            "isSidechain": isSidechain,
            "message": message,
        ]
        let data = try! JSONSerialization.data(withJSONObject: record) // swiftlint:disable:this force_try
        return String(data: data, encoding: .utf8)!
    }

    private func assistantRecord(
        content: [[String: Any]],
        msgId: String = "msg_123",
        model: String = "claude-opus-4-6",
        timestamp: String = "2026-01-28T10:01:00.000Z",
        inputTokens: Int = 100,
        outputTokens: Int = 50,
        isSidechain: Bool = false
    ) -> String {
        let message: [String: Any] = [
            "id": msgId,
            "role": "assistant",
            "model": model,
            "content": content,
            "usage": [
                "input_tokens": inputTokens,
                "output_tokens": outputTokens,
            ],
        ]
        let record: [String: Any] = [
            "type": "assistant",
            "uuid": UUID().uuidString,
            "timestamp": timestamp,
            "isSidechain": isSidechain,
            "message": message,
        ]
        let data = try! JSONSerialization.data(withJSONObject: record) // swiftlint:disable:this force_try
        return String(data: data, encoding: .utf8)!
    }

    // MARK: - Empty / Invalid

    @Test
    func parse_emptyFile_returnsNil() throws {
        let (dir, file) = try makeTempFile("")
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result == nil)
    }

    @Test
    func parse_onlySkippedRecordTypes_returnsNil() throws {
        let lines = [
            #"{"type":"progress","data":{"type":"hook_progress"},"timestamp":"2026-01-28T10:00:00.000Z"}"#,
            #"{"type":"file-history-snapshot","snapshot":{},"timestamp":"2026-01-28T10:00:01.000Z"}"#,
        ]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result == nil)
    }

    @Test
    func parse_malformedLines_skipsGracefully() throws {
        let lines = [
            "not valid json",
            "{broken json",
            userRecord(content: "Hello"),
        ]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result != nil)
        #expect(result?.messages.count == 1)
    }

    @Test
    func parse_sidechainRecords_skipped() throws {
        let lines = [
            userRecord(content: "Hello", isSidechain: true),
            userRecord(content: "World", isSidechain: false),
        ]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result != nil)
        #expect(result?.messages.count == 1)
        #expect(result?.messages[0].textContent == "World")
    }

    // MARK: - User Content

    @Test
    func parse_userStringContent_createsTextBlock() throws {
        let lines = [userRecord(content: "Hello world")]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result != nil)
        #expect(result?.messages.count == 1)
        #expect(result?.messages[0].role == .user)
        #expect(result?.messages[0].content == [.text("Hello world")])
    }

    @Test
    func parse_userToolResult_createsToolResultBlock() throws {
        let toolResult: [[String: Any]] = [
            [
                "type": "tool_result",
                "tool_use_id": "toolu_abc",
                "content": "File created successfully",
            ],
        ]
        let lines = [userRecord(content: toolResult)]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result != nil)
        #expect(result?.messages.count == 1)

        if case let .toolResult(tr) = result?.messages[0].content.first {
            #expect(tr.toolUseId == "toolu_abc")
            #expect(tr.content == "File created successfully")
            #expect(tr.isError == false)
        } else {
            Issue.record("Expected toolResult block")
        }
    }

    @Test
    func parse_toolResult_stringContent_normalized() throws {
        let toolResult: [[String: Any]] = [
            [
                "type": "tool_result",
                "tool_use_id": "toolu_1",
                "content": "Simple string content",
            ],
        ]
        let lines = [userRecord(content: toolResult)]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        if case let .toolResult(tr) = result?.messages[0].content.first {
            #expect(tr.content == "Simple string content")
        } else {
            Issue.record("Expected toolResult block")
        }
    }

    @Test
    func parse_toolResult_arrayContent_extractsTextOnly() throws {
        let toolResult: [[String: Any]] = [
            [
                "type": "tool_result",
                "tool_use_id": "toolu_2",
                "content": [
                    ["type": "text", "text": "Line 1"],
                    ["type": "tool_reference", "ref": "something"],
                    ["type": "text", "text": "Line 2"],
                ] as [[String: Any]],
            ],
        ]
        let lines = [userRecord(content: toolResult)]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        if case let .toolResult(tr) = result?.messages[0].content.first {
            #expect(tr.content == "Line 1\nLine 2")
        } else {
            Issue.record("Expected toolResult block")
        }
    }

    @Test
    func parse_toolResult_isError_flagged() throws {
        let toolResult: [[String: Any]] = [
            [
                "type": "tool_result",
                "tool_use_id": "toolu_err",
                "content": "Error: file not found",
                "is_error": true,
            ],
        ]
        let lines = [userRecord(content: toolResult)]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        if case let .toolResult(tr) = result?.messages[0].content.first {
            #expect(tr.isError == true)
        } else {
            Issue.record("Expected toolResult block")
        }
    }

    // MARK: - Assistant Content

    @Test
    func parse_assistantTextBlock() throws {
        let content: [[String: Any]] = [["type": "text", "text": "Hello from assistant"]]
        let lines = [assistantRecord(content: content)]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result != nil)
        #expect(result?.messages.count == 1)
        #expect(result?.messages[0].role == .assistant)
        #expect(result?.messages[0].content == [.text("Hello from assistant")])
    }

    @Test
    func parse_assistantThinkingBlock() throws {
        let content: [[String: Any]] = [["type": "thinking", "thinking": "Let me think about this"]]
        let lines = [assistantRecord(content: content)]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.messages[0].content == [.thinking("Let me think about this")])
    }

    @Test
    func parse_assistantToolUseBlock() throws {
        let content: [[String: Any]] = [
            [
                "type": "tool_use",
                "id": "toolu_xyz",
                "name": "Read",
                "input": ["file_path": "/foo/bar.swift"],
            ],
        ]
        let lines = [assistantRecord(content: content)]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        if case let .toolUse(tu) = result?.messages[0].content.first {
            #expect(tu.id == "toolu_xyz")
            #expect(tu.name == "Read")
            #expect(tu.input["file_path"] == "/foo/bar.swift")
        } else {
            Issue.record("Expected toolUse block")
        }
    }

    @Test
    func parse_toolUse_nonStringInputsStringified() throws {
        let content: [[String: Any]] = [
            [
                "type": "tool_use",
                "id": "toolu_num",
                "name": "Bash",
                "input": [
                    "command": "ls",
                    "timeout": 5000,
                    "dangerouslyDisableSandbox": true,
                ] as [String: Any],
            ],
        ]
        let lines = [assistantRecord(content: content)]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        if case let .toolUse(tu) = result?.messages[0].content.first {
            #expect(tu.input["command"] == "ls")
            #expect(tu.input["timeout"] == "5000")
            #expect(tu.input["dangerouslyDisableSandbox"] == "true")
        } else {
            Issue.record("Expected toolUse block")
        }
    }

    // MARK: - Filtering

    @Test
    func parse_syntheticModel_skipped() throws {
        let content: [[String: Any]] = [["type": "text", "text": "Synthetic message"]]
        let syntheticLine = assistantRecord(content: content, model: "<synthetic>")
        let realLine = userRecord(content: "Real user message")
        let (dir, file) = try makeTempFile([syntheticLine, realLine].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.messages.count == 1)
        #expect(result?.messages[0].role == .user)
    }

    // MARK: - Grouping

    @Test
    func parse_multipleRecordsSameId_grouped() throws {
        let line1 = assistantRecord(
            content: [["type": "text", "text": "Part 1"]],
            msgId: "msg_grouped",
            timestamp: "2026-01-28T10:01:00.000Z"
        )
        let line2 = assistantRecord(
            content: [["type": "tool_use", "id": "t1", "name": "Read", "input": ["path": "/a"]]],
            msgId: "msg_grouped",
            timestamp: "2026-01-28T10:01:01.000Z"
        )
        let (dir, file) = try makeTempFile([line1, line2].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.messages.count == 1)

        let msg = result?.messages[0]
        #expect(msg?.role == .assistant)
        #expect(msg?.content.count == 2)
        #expect(msg?.content[0] == .text("Part 1"))
        if case let .toolUse(tu) = msg?.content[1] {
            #expect(tu.name == "Read")
        } else {
            Issue.record("Expected toolUse as second block")
        }
    }

    @Test
    func parse_usage_deduplicatedPerGroup() throws {
        let line1 = assistantRecord(
            content: [["type": "text", "text": "A"]],
            msgId: "msg_dup",
            inputTokens: 100,
            outputTokens: 50
        )
        let line2 = assistantRecord(
            content: [["type": "text", "text": "B"]],
            msgId: "msg_dup",
            inputTokens: 200,
            outputTokens: 100
        )
        let (dir, file) = try makeTempFile([line1, line2].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.messages.count == 1)
        #expect(result?.messages[0].tokenUsage?.input == 100)
        #expect(result?.messages[0].tokenUsage?.output == 50)
        #expect(result?.totalTokens == 150)
    }

    // MARK: - Session Assembly

    @Test
    func parse_startedAt_usesEarliestTimestamp() throws {
        let userLine = userRecord(content: "First", timestamp: "2026-01-28T09:00:00.000Z")
        let assistantLine = assistantRecord(
            content: [["type": "text", "text": "Reply"]],
            timestamp: "2026-01-28T10:00:00.000Z"
        )
        let (dir, file) = try makeTempFile([userLine, assistantLine].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expected = fmt.date(from: "2026-01-28T09:00:00.000Z")
        #expect(result?.startedAt == expected)
    }

    @Test
    func parse_model_fromFirstAssistantGroup() throws {
        let userLine = userRecord(content: "Hi")
        let a1 = assistantRecord(
            content: [["type": "text", "text": "A"]],
            msgId: "msg_1",
            model: "claude-sonnet-4-5-20250514",
            timestamp: "2026-01-28T10:01:00.000Z"
        )
        let a2 = assistantRecord(
            content: [["type": "text", "text": "B"]],
            msgId: "msg_2",
            model: "claude-opus-4-6",
            timestamp: "2026-01-28T10:02:00.000Z"
        )
        let lines = [userLine, a1, a2].joined(separator: "\n")
        let (dir, file) = try makeTempFile(lines)
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.model == "claude-sonnet-4-5-20250514")
    }

    @Test
    func parse_totalTokens_summedAcrossGroups() throws {
        let userLine = userRecord(content: "Hi")
        let a1 = assistantRecord(
            content: [["type": "text", "text": "A"]],
            msgId: "msg_1",
            timestamp: "2026-01-28T10:01:00.000Z",
            inputTokens: 100,
            outputTokens: 50
        )
        let a2 = assistantRecord(
            content: [["type": "text", "text": "B"]],
            msgId: "msg_2",
            timestamp: "2026-01-28T10:02:00.000Z",
            inputTokens: 200,
            outputTokens: 100
        )
        let lines = [userLine, a1, a2].joined(separator: "\n")
        let (dir, file) = try makeTempFile(lines)
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.totalTokens == 450)
    }

    @Test
    func parse_interleaved_userAndAssistant_preservesOrder() throws {
        let u1 = userRecord(content: "Q1", uuid: "u1", timestamp: "2026-01-28T10:00:00.000Z")
        let a1 = assistantRecord(
            content: [["type": "text", "text": "A1"]],
            msgId: "msg_a1",
            timestamp: "2026-01-28T10:01:00.000Z"
        )
        let u2 = userRecord(content: "Q2", uuid: "u2", timestamp: "2026-01-28T10:02:00.000Z")
        let a2 = assistantRecord(
            content: [["type": "text", "text": "A2"]],
            msgId: "msg_a2",
            timestamp: "2026-01-28T10:03:00.000Z"
        )
        let lines = [u1, a1, u2, a2].joined(separator: "\n")
        let (dir, file) = try makeTempFile(lines)
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.messages.count == 4)
        #expect(result?.messages[0].role == .user)
        #expect(result?.messages[0].textContent == "Q1")
        #expect(result?.messages[1].role == .assistant)
        #expect(result?.messages[1].textContent == "A1")
        #expect(result?.messages[2].role == .user)
        #expect(result?.messages[2].textContent == "Q2")
        #expect(result?.messages[3].role == .assistant)
        #expect(result?.messages[3].textContent == "A2")
    }

    // MARK: - parseSummary

    @Test
    func parseSummary_emptyFile_returnsNil() throws {
        let (dir, file) = try makeTempFile("")
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result == nil)
    }

    @Test
    func parseSummary_extractsTitle() throws {
        let lines = [
            userRecord(content: "Hello world"),
            assistantRecord(content: [["type": "text", "text": "Hi"]]),
        ]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result != nil)
        #expect(result?.title == "Hello world")
        #expect(result?.messages.isEmpty == true)
        #expect(result?.fileURL == file)
    }

    @Test
    func parseSummary_extractsTurnCount() throws {
        let u1 = userRecord(content: "Q1", uuid: "u1", timestamp: "2026-01-28T10:00:00.000Z")
        let a1 = assistantRecord(
            content: [["type": "text", "text": "A1"]],
            msgId: "msg_a1",
            timestamp: "2026-01-28T10:01:00.000Z"
        )
        let u2 = userRecord(content: "Q2", uuid: "u2", timestamp: "2026-01-28T10:02:00.000Z")
        let (dir, file) = try makeTempFile([u1, a1, u2].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.turnCount == 2)
    }

    @Test
    func parseSummary_extractsModel() throws {
        let lines = [
            userRecord(content: "Hello"),
            assistantRecord(content: [["type": "text", "text": "Hi"]], model: "claude-sonnet-4-6"),
        ]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.model == "claude-sonnet-4-6")
    }

    @Test
    func parseSummary_sumsTokensPerGroup() throws {
        let u1 = userRecord(content: "Hi")
        let a1 = assistantRecord(
            content: [["type": "text", "text": "A"]],
            msgId: "msg_1",
            timestamp: "2026-01-28T10:01:00.000Z",
            inputTokens: 100,
            outputTokens: 50
        )
        // Duplicate msgId — tokens should NOT be double-counted
        let a1dup = assistantRecord(
            content: [["type": "tool_use", "id": "t1", "name": "Read", "input": ["path": "/a"]]],
            msgId: "msg_1",
            timestamp: "2026-01-28T10:01:01.000Z",
            inputTokens: 200,
            outputTokens: 100
        )
        let a2 = assistantRecord(
            content: [["type": "text", "text": "B"]],
            msgId: "msg_2",
            timestamp: "2026-01-28T10:02:00.000Z",
            inputTokens: 300,
            outputTokens: 150
        )
        let (dir, file) = try makeTempFile([u1, a1, a1dup, a2].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        // msg_1: 100+50=150, msg_2: 300+150=450 → total 600
        #expect(result?.totalTokens == 600)
    }

    @Test
    func parseSummary_skipsSidechainRecords() throws {
        let lines = [
            userRecord(content: "Sidechain", isSidechain: true),
            userRecord(content: "Real message", isSidechain: false),
        ]
        let (dir, file) = try makeTempFile(lines.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.title == "Real message")
        #expect(result?.turnCount == 1)
    }

    @Test
    func parseSummary_skipsSyntheticAssistant() throws {
        let synth = assistantRecord(content: [["type": "text", "text": "Synthetic"]], model: "<synthetic>")
        let real = userRecord(content: "Real user")
        let (dir, file) = try makeTempFile([synth, real].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        #expect(result?.model == nil)
        #expect(result?.turnCount == 1)
    }

    @Test
    func parseSummary_usesEarliestTimestamp() throws {
        let u = userRecord(content: "First", timestamp: "2026-01-28T09:00:00.000Z")
        let a = assistantRecord(
            content: [["type": "text", "text": "Reply"]],
            timestamp: "2026-01-28T10:00:00.000Z"
        )
        let (dir, file) = try makeTempFile([u, a].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expected = fmt.date(from: "2026-01-28T09:00:00.000Z")
        #expect(result?.startedAt == expected)
    }

    // MARK: - Searchable Text

    @Test
    func parseSummary_searchableText_indexesConversationContent() throws {
        let u = userRecord(content: "Deploy to Digital Ocean")
        let a = assistantRecord(content: [
            ["type": "text", "text": "Provisioning a droplet"],
            ["type": "thinking", "thinking": "The user wants Kubernetes"],
            ["type": "tool_use", "id": "t1", "name": "Bash", "input": ["command": "doctl compute droplet create"]],
        ])
        let toolResult: [[String: Any]] = [
            ["type": "tool_result", "tool_use_id": "t1", "content": "droplet 12345 created"],
        ]
        let tr = userRecord(content: toolResult, uuid: "u2", timestamp: "2026-01-28T10:02:00.000Z")
        let (dir, file) = try makeTempFile([u, a, tr].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        let text = try #require(result?.searchableText)
        // User prose, assistant prose, reasoning, tool command, and tool output are all indexed.
        #expect(text.contains("digital ocean"))
        #expect(text.contains("provisioning a droplet"))
        #expect(text.contains("kubernetes"))
        #expect(text.contains("doctl compute droplet create"))
        #expect(text.contains("droplet 12345 created"))
        // Stored lowercased so search can match case-insensitively without re-lowercasing.
        #expect(!text.contains("Digital Ocean"))
    }

    @Test
    func parseSummary_searchableText_excludesSyntheticAndSidechain() throws {
        let synth = assistantRecord(content: [["type": "text", "text": "SECRETSYNTH"]], model: "<synthetic>")
        let side = userRecord(content: "SECRETSIDE", uuid: "u1", isSidechain: true)
        let real = userRecord(content: "realcontent", uuid: "u2", timestamp: "2026-01-28T10:05:00.000Z")
        let (dir, file) = try makeTempFile([synth, side, real].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        let text = try #require(result?.searchableText)
        #expect(text.contains("realcontent"))
        #expect(!text.contains("secretsynth"))
        #expect(!text.contains("secretside"))
    }

    @Test
    func parseSummary_searchableText_respectsCap() throws {
        let big = String(repeating: "a", count: TranscriptParser.searchableTextCap + 5000)
        let (dir, file) = try makeTempFile(userRecord(content: big))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parseSummary(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        let text = try #require(result?.searchableText)
        // Bounded (allowing the trailing separator) so a giant transcript can't balloon memory.
        #expect(text.count <= TranscriptParser.searchableTextCap + 1)
        #expect(text.contains("aaaa"))
    }

    @Test
    func parse_searchableText_indexesContent() throws {
        let u = userRecord(content: "FindMe in Content")
        let a = assistantRecord(content: [["type": "text", "text": "Here is the Response"]])
        let (dir, file) = try makeTempFile([u, a].joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = parser.parse(fileURL: file, projectPath: "/test", sessionId: "s1", indexStartedAt: nil)
        let text = try #require(result?.searchableText)
        #expect(text.contains("findme in content"))
        #expect(text.contains("here is the response"))
    }
}

// swiftlint:enable file_length type_body_length
