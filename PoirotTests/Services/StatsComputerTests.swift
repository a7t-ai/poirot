@testable import Poirot
import Foundation
import Testing

@Suite("StatsComputer")
struct StatsComputerTests {
    @Test
    func compute_aggregatesSessionFromTranscript() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("statscomp-\(UUID().uuidString)")
        let projectDir = root.appendingPathComponent("-Users-test-proj")
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        // swiftlint:disable line_length
        let jsonl = """
        {"type":"user","timestamp":"2026-06-20T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"hi"}}
        {"type":"assistant","timestamp":"2026-06-20T10:00:05.000Z","message":{"id":"a1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20,"cache_read_input_tokens":1000,"cache_creation_input_tokens":100,"server_tool_use":{"web_search_requests":2}},"content":[{"type":"tool_use","name":"Read"},{"type":"text","text":"ok"}]}}
        {"type":"assistant","timestamp":"2026-06-20T10:01:00.000Z","message":{"id":"a2","model":"claude-opus-4-6","usage":{"input_tokens":5,"output_tokens":8,"cache_read_input_tokens":2000,"cache_creation_input_tokens":50},"content":[{"type":"tool_use","name":"Bash"}]}}
        {"type":"assistant","timestamp":"2026-06-20T10:02:00.000Z","isSidechain":true,"message":{"id":"s1","model":"claude-opus-4-6","usage":{"input_tokens":999,"output_tokens":999},"content":[]}}
        """
        // swiftlint:enable line_length
        let sessionId = UUID().uuidString
        try jsonl.write(
            to: projectDir.appendingPathComponent("\(sessionId).jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let stats = try #require(StatsComputer.compute(projectsPath: root.path))

        #expect(stats.totalSessions == 1)
        #expect(stats.totalMessages == 3) // sidechain record excluded

        let model = try #require(stats.modelUsage["claude-opus-4-6"])
        #expect(model.inputTokens == 15) // sidechain's 999 not counted
        #expect(model.outputTokens == 28)
        #expect(model.cacheReadInputTokens == 3000)
        #expect(model.cacheCreationInputTokens == 150)
        #expect(model.webSearchRequests == 2)
        #expect(model.costUSD == 0)

        #expect(stats.dailyActivity.count == 1)
        #expect(stats.dailyActivity.first?.messageCount == 3)
        #expect(stats.dailyActivity.first?.sessionCount == 1)
        #expect(stats.dailyActivity.first?.toolCallCount == 2)
        #expect(stats.totalToolCalls == 2)

        #expect(stats.longestSession.duration == 60000) // 10:00:00 → 10:01:00
        #expect(stats.longestSession.messageCount == 3)
    }

    @Test
    func compute_noSessions_returnsNil() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("statscomp-empty-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        #expect(StatsComputer.compute(projectsPath: root.path) == nil)
    }

    @Test
    func compute_missingPath_returnsNil() {
        #expect(StatsComputer.compute(projectsPath: "/no/such/dir/\(UUID().uuidString)") == nil)
    }
}
