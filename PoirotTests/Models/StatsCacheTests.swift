@testable import Poirot
import Foundation
import Testing

@Suite("StatsCache Model")
struct StatsCacheTests {
    // MARK: - Test JSON

    private static let validJSON = """
    {
      "version": 2,
      "lastComputedDate": "2026-02-17",
      "dailyActivity": [
        {
          "date": "2026-01-01",
          "messageCount": 18255,
          "sessionCount": 11,
          "toolCallCount": 5324
        },
        {
          "date": "2026-01-02",
          "messageCount": 360,
          "sessionCount": 1,
          "toolCallCount": 100
        }
      ],
      "dailyModelTokens": [
        {
          "date": "2026-01-01",
          "tokensByModel": {
            "claude-opus-4-5-20251101": 2269186
          }
        },
        {
          "date": "2026-01-12",
          "tokensByModel": {
            "claude-opus-4-5-20251101": 196417,
            "claude-sonnet-4-5-20250929": 99944
          }
        }
      ],
      "modelUsage": {
        "claude-opus-4-5-20251101": {
          "inputTokens": 4020186,
          "outputTokens": 3833943,
          "cacheReadInputTokens": 7246318082,
          "cacheCreationInputTokens": 325882562,
          "webSearchRequests": 0,
          "costUSD": 0,
          "contextWindow": 0,
          "maxOutputTokens": 0
        },
        "claude-opus-4-6": {
          "inputTokens": 592180,
          "outputTokens": 1778001,
          "cacheReadInputTokens": 2323328386,
          "cacheCreationInputTokens": 103861546,
          "webSearchRequests": 0,
          "costUSD": 0,
          "contextWindow": 0,
          "maxOutputTokens": 0
        }
      },
      "totalSessions": 466,
      "totalMessages": 322626,
      "longestSession": {
        "sessionId": "ce55f01b-e4f4-4c6a-934e-f95ba536935f",
        "duration": 321972719,
        "messageCount": 1504,
        "timestamp": "2026-01-13T19:55:30.879Z"
      },
      "firstSessionDate": "2025-12-31T19:57:52.149Z",
      "hourCounts": {
        "0": 3,
        "11": 52,
        "23": 16
      },
      "totalSpeculationTimeSavedMs": 0
    }
    """

    // MARK: - Decoding

    @Test
    func decode_fullJSON_succeeds() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        #expect(stats.version == 2)
        #expect(stats.lastComputedDate == "2026-02-17")
        #expect(stats.totalSessions == 466)
        #expect(stats.totalMessages == 322_626)
        #expect(stats.totalSpeculationTimeSavedMs == 0)
    }

    @Test
    func decode_dailyActivity_parsesCorrectly() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        #expect(stats.dailyActivity.count == 2)
        #expect(stats.dailyActivity[0].date == "2026-01-01")
        #expect(stats.dailyActivity[0].messageCount == 18255)
        #expect(stats.dailyActivity[0].sessionCount == 11)
        #expect(stats.dailyActivity[0].toolCallCount == 5324)
    }

    @Test
    func decode_dailyModelTokens_parsesMultiModel() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        #expect(stats.dailyModelTokens.count == 2)
        let multiModel = stats.dailyModelTokens[1]
        #expect(multiModel.tokensByModel.count == 2)
        #expect(multiModel.tokensByModel["claude-opus-4-5-20251101"] == 196_417)
        #expect(multiModel.tokensByModel["claude-sonnet-4-5-20250929"] == 99944)
    }

    @Test
    func decode_modelUsage_parsesTokenCounts() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        #expect(stats.modelUsage.count == 2)
        let opus = try #require(stats.modelUsage["claude-opus-4-5-20251101"])
        #expect(opus.inputTokens == 4_020_186)
        #expect(opus.outputTokens == 3_833_943)
        #expect(opus.cacheReadInputTokens == 7_246_318_082)
        #expect(opus.cacheCreationInputTokens == 325_882_562)
    }

    @Test
    func decode_longestSession_parsesAllFields() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        #expect(stats.longestSession.sessionId == "ce55f01b-e4f4-4c6a-934e-f95ba536935f")
        #expect(stats.longestSession.duration == 321_972_719)
        #expect(stats.longestSession.messageCount == 1504)
    }

    @Test
    func decode_hourCounts_parsesStringKeys() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        #expect(stats.hourCounts["0"] == 3)
        #expect(stats.hourCounts["11"] == 52)
        #expect(stats.hourCounts["23"] == 16)
    }

    // MARK: - Computed Helpers

    @Test
    func longestSessionFormatted_showsHoursAndMinutes() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        // 321972719 ms = ~89h 26m
        #expect(stats.longestSessionFormatted == "89h 26m")
    }

    @Test
    func sortedHourCounts_sortsAscending() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        let sorted = stats.sortedHourCounts
        #expect(sorted.count == 3)
        #expect(sorted[0].hour == 0)
        #expect(sorted[1].hour == 11)
        #expect(sorted[2].hour == 23)
    }

    @Test
    func totalOutputTokens_sumsAcrossModels() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        #expect(stats.totalOutputTokens == 3_833_943 + 1_778_001)
    }

    @Test
    func friendlyModelName_mapsKnownModels() {
        #expect(StatsCache.friendlyModelName("claude-opus-4-6") == "Opus 4.6")
        #expect(StatsCache.friendlyModelName("claude-opus-4-5-20251101") == "Opus 4.5")
        #expect(StatsCache.friendlyModelName("claude-sonnet-4-5-20250929") == "Sonnet 4.5")
        #expect(StatsCache.friendlyModelName("unknown-model") == "unknown-model")
    }

    @Test
    func firstSessionParsedDate_parsesISO8601() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        let date = try #require(stats.firstSessionParsedDate)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
        #expect(components.year == 2025)
        #expect(components.month == 12)
        #expect(components.day == 31)
    }

    @Test
    func totalToolCalls_sumsAcrossDays() throws {
        let data = Data(Self.validJSON.utf8)
        let stats = try JSONDecoder().decode(StatsCache.self, from: data)

        #expect(stats.totalToolCalls == 5324 + 100)
    }

    // MARK: - StatsCacheLoader

    @Test
    func loader_missingFile_returnsNil() {
        let result = StatsCacheLoader.load(from: "/nonexistent/path/stats-cache.json")
        #expect(result == nil)
    }

    // MARK: - Staleness

    @Test
    func isStale_tokensLagActivity_isTrue() {
        let cache = Self.makeCache(
            lastComputedDate: "2026-08-28",
            dailyActivity: [
                .init(date: "2026-03-01", messageCount: 1, sessionCount: 1, toolCallCount: 0),
                .init(date: "2026-08-28", messageCount: 2, sessionCount: 1, toolCallCount: 0),
            ],
            dailyModelTokens: [
                .init(date: "2026-03-01", tokensByModel: ["claude-opus-4-6": 100]),
            ]
        )
        #expect(StatsCacheLoader.isStale(cache, latestSessionDay: "2026-08-28"))
        #expect(StatsCacheLoader.isStale(cache, latestSessionDay: nil))
    }

    @Test
    func isStale_lastComputedBeforeLatestSession_isTrue() {
        let cache = Self.makeCache(
            lastComputedDate: "2026-03-15",
            dailyActivity: [
                .init(date: "2026-03-15", messageCount: 10, sessionCount: 1, toolCallCount: 1),
            ],
            dailyModelTokens: [
                .init(date: "2026-03-15", tokensByModel: ["claude-opus-4-6": 50]),
            ]
        )
        #expect(StatsCacheLoader.isStale(cache, latestSessionDay: "2026-08-28"))
        #expect(!StatsCacheLoader.isStale(cache, latestSessionDay: "2026-03-15"))
        #expect(!StatsCacheLoader.isStale(cache, latestSessionDay: nil))
    }

    @Test
    func loadAnalytics_staleCache_recomputesFromTranscripts() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("stale-cache-\(UUID().uuidString)")
        let projectDir = root.appendingPathComponent("projects").appendingPathComponent("proj")
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cache = Self.makeCache(
            lastComputedDate: "2026-03-15",
            dailyActivity: [
                .init(date: "2026-03-15", messageCount: 1, sessionCount: 1, toolCallCount: 0),
            ],
            dailyModelTokens: [
                .init(date: "2026-03-15", tokensByModel: ["claude-opus-4-6": 999]),
            ]
        )
        let cacheURL = root.appendingPathComponent("stats-cache.json")
        try JSONEncoder().encode(cache).write(to: cacheURL)

        let sessionId = UUID().uuidString
        let jsonl = """
        {"type":"user","timestamp":"2026-08-20T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"hi"}}
        {"type":"assistant","timestamp":"2026-08-20T10:00:05.000Z","message":{"id":"a1","model":"claude-opus-4-6","usage":{"input_tokens":7,"output_tokens":3},"content":[]}}
        """
        try jsonl.write(
            to: projectDir.appendingPathComponent("\(sessionId).jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let stats = try #require(StatsCacheLoader.loadAnalytics(
            cachePath: cacheURL.path,
            projectsPath: root.appendingPathComponent("projects").path
        ))

        #expect(stats.dailyModelTokens.contains { $0.date == "2026-08-20" })
        #expect(!stats.dailyModelTokens.contains { $0.date == "2026-03-15" && $0.tokensByModel["claude-opus-4-6"] == 999 })
        let model = try #require(stats.modelUsage["claude-opus-4-6"])
        #expect(model.inputTokens == 7)
        #expect(model.outputTokens == 3)
    }

    @Test
    func loadAnalytics_freshCache_isKept() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("fresh-cache-\(UUID().uuidString)")
        let projectDir = root.appendingPathComponent("projects").appendingPathComponent("proj")
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let sessionId = UUID().uuidString
        try #"{"type":"user","timestamp":"2026-08-20T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"hi"}}"#
            .write(to: projectDir.appendingPathComponent("\(sessionId).jsonl"), atomically: true, encoding: .utf8)

        let latest = try #require(StatsComputer.latestSessionDay(
            projectsPath: root.appendingPathComponent("projects").path
        ))
        let cache = Self.makeCache(
            lastComputedDate: latest,
            dailyActivity: [
                .init(date: latest, messageCount: 42, sessionCount: 2, toolCallCount: 1),
            ],
            dailyModelTokens: [
                .init(date: latest, tokensByModel: ["kept-model": 1234]),
            ]
        )
        let cacheURL = root.appendingPathComponent("stats-cache.json")
        try JSONEncoder().encode(cache).write(to: cacheURL)

        let stats = try #require(StatsCacheLoader.loadAnalytics(
            cachePath: cacheURL.path,
            projectsPath: root.appendingPathComponent("projects").path
        ))
        #expect(stats.dailyModelTokens.first?.tokensByModel["kept-model"] == 1234)
        #expect(stats.dailyActivity.first?.messageCount == 42)
    }

    private static func makeCache(
        lastComputedDate: String,
        dailyActivity: [StatsCache.DailyActivity],
        dailyModelTokens: [StatsCache.DailyModelTokens]
    ) -> StatsCache {
        StatsCache(
            version: 2,
            lastComputedDate: lastComputedDate,
            dailyActivity: dailyActivity,
            dailyModelTokens: dailyModelTokens,
            modelUsage: [:],
            totalSessions: 1,
            totalMessages: 1,
            longestSession: StatsCache.LongestSession(
                sessionId: "s",
                duration: 1000,
                messageCount: 1,
                timestamp: "2026-03-15T00:00:00.000Z"
            ),
            firstSessionDate: "2026-03-15T00:00:00.000Z",
            hourCounts: [:],
            totalSpeculationTimeSavedMs: 0
        )
    }
}
