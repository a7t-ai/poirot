import Foundation

/// Computes a `StatsCache` directly from local session transcripts, for setups where Claude
/// Code doesn't write `~/.claude/stats-cache.json`. Everything stays on-device — it just
/// re-reads the JSONL Poirot already has access to. Token totals are cache-inclusive, matching
/// how `StatsCache` reports them.
///
/// Scans main-thread sessions (UUID-named `.jsonl` files); sub-agent sidechains are skipped to
/// avoid double-counting, so heavy sub-agent usage is approximate.
nonisolated enum StatsComputer {
    static func compute(projectsPath: String) -> StatsCache? {
        let fm = FileManager.default
        guard let projectDirs = try? SessionLoader.projectDirectoryURLs(at: projectsPath) else {
            return nil
        }

        var agg = Aggregate()
        for dir in projectDirs {
            guard let files = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl"
                && UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil {
                agg.scan(file: file)
            }
        }

        return agg.makeStatsCache()
    }

    // MARK: - Formatters

    nonisolated(unsafe) private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let isoPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func parseTimestamp(_ string: String) -> Date? {
        isoFractional.date(from: string) ?? isoPlain.date(from: string)
    }

    // MARK: - Aggregate

    private struct Aggregate {
        struct Day {
            var messages = 0
            var sessions = 0
            var toolCalls = 0
        }

        struct Model {
            var input = 0
            var output = 0
            var cacheRead = 0
            var cacheCreation = 0
            var webSearch = 0
        }

        var days: [String: Day] = [:]
        var dayModelTokens: [String: [String: Int]] = [:]
        var models: [String: Model] = [:]
        var totalSessions = 0
        var totalMessages = 0
        var earliest: Date?
        var longest: StatsCache.LongestSession?

        mutating func scan(file: URL) {
            guard let data = try? Data(contentsOf: file),
                  let text = String(data: data, encoding: .utf8), !text.isEmpty
            else { return }

            let sessionId = file.deletingPathExtension().lastPathComponent
            var sessionStart: Date?
            var sessionEnd: Date?
            var sessionMessages = 0
            var sawRecord = false

            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let lineData = line.data(using: .utf8),
                      let record = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let type = record["type"] as? String,
                      type == "user" || type == "assistant",
                      record["isSidechain"] as? Bool != true
                else { continue }

                let message = record["message"] as? [String: Any]
                if type == "assistant", message?["model"] as? String == "<synthetic>" { continue }
                guard let timestamp = (record["timestamp"] as? String).flatMap(StatsComputer.parseTimestamp)
                else { continue }

                sawRecord = true
                sessionMessages += 1
                totalMessages += 1
                if sessionStart == nil || timestamp < sessionStart! { sessionStart = timestamp }
                if sessionEnd == nil || timestamp > sessionEnd! { sessionEnd = timestamp }
                if earliest == nil || timestamp < earliest! { earliest = timestamp }

                let day = StatsComputer.dayFormatter.string(from: timestamp)
                let hour = Calendar.current.component(.hour, from: timestamp)
                days[day, default: Day()].messages += 1
                hourCounts[hour, default: 0] += 1

                if type == "assistant" {
                    accumulateAssistant(message: message, day: day)
                }
            }

            guard sawRecord, let start = sessionStart, let end = sessionEnd else { return }
            totalSessions += 1
            let startDay = StatsComputer.dayFormatter.string(from: start)
            days[startDay, default: Day()].sessions += 1

            let duration = Int(end.timeIntervalSince(start) * 1000)
            if duration > (longest?.duration ?? -1) {
                longest = StatsCache.LongestSession(
                    sessionId: sessionId,
                    duration: duration,
                    messageCount: sessionMessages,
                    timestamp: StatsComputer.isoFractional.string(from: start)
                )
            }
        }

        var hourCounts: [Int: Int] = [:]

        private mutating func accumulateAssistant(message: [String: Any]?, day: String) {
            guard let message else { return }
            let model = message["model"] as? String ?? "unknown"

            if let content = message["content"] as? [[String: Any]] {
                let toolCalls = content.count { ($0["type"] as? String) == "tool_use" }
                if toolCalls > 0 { days[day, default: Day()].toolCalls += toolCalls }
            }

            guard let usage = message["usage"] as? [String: Any] else { return }
            let input = usage["input_tokens"] as? Int ?? 0
            let output = usage["output_tokens"] as? Int ?? 0
            let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
            let cacheCreation = usage["cache_creation_input_tokens"] as? Int ?? 0
            let webSearch = (usage["server_tool_use"] as? [String: Any])?["web_search_requests"] as? Int ?? 0

            var entry = models[model] ?? Model()
            entry.input += input
            entry.output += output
            entry.cacheRead += cacheRead
            entry.cacheCreation += cacheCreation
            entry.webSearch += webSearch
            models[model] = entry

            let total = input + output + cacheRead + cacheCreation
            dayModelTokens[day, default: [:]][model, default: 0] += total
        }

        func makeStatsCache() -> StatsCache? {
            guard totalSessions > 0, let earliest, let longest else { return nil }

            let dailyActivity = days
                .map { date, day in
                    StatsCache.DailyActivity(
                        date: date,
                        messageCount: day.messages,
                        sessionCount: day.sessions,
                        toolCallCount: day.toolCalls
                    )
                }
                .sorted { $0.date < $1.date }

            let dailyModelTokens = dayModelTokens
                .map { StatsCache.DailyModelTokens(date: $0.key, tokensByModel: $0.value) }
                .sorted { $0.date < $1.date }

            let modelUsage = models.mapValues { model in
                let contextWindow = (model.input + model.cacheRead + model.cacheCreation) > 200_000
                    ? 1_000_000 : 200_000
                return StatsCache.ModelUsage(
                    inputTokens: model.input,
                    outputTokens: model.output,
                    cacheReadInputTokens: model.cacheRead,
                    cacheCreationInputTokens: model.cacheCreation,
                    webSearchRequests: model.webSearch,
                    // Subscription usage has no per-call dollar cost; the dashboard renders this
                    // as "included in subscription".
                    costUSD: 0,
                    contextWindow: contextWindow,
                    maxOutputTokens: 32000
                )
            }

            let hourCountsStrings = Dictionary(
                uniqueKeysWithValues: hourCounts.map { (String($0.key), $0.value) }
            )

            return StatsCache(
                version: 1,
                lastComputedDate: StatsComputer.dayFormatter.string(from: Date()),
                dailyActivity: dailyActivity,
                dailyModelTokens: dailyModelTokens,
                modelUsage: modelUsage,
                totalSessions: totalSessions,
                totalMessages: totalMessages,
                longestSession: longest,
                firstSessionDate: StatsComputer.isoFractional.string(from: earliest),
                hourCounts: hourCountsStrings,
                totalSpeculationTimeSavedMs: 0
            )
        }
    }
}
