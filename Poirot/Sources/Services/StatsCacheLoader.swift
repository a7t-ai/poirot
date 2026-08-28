import Foundation

/// Loads the pre-computed stats cache from `~/.claude/stats-cache.json`.
nonisolated enum StatsCacheLoader {
    private static let defaultPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/stats-cache.json"
    }()

    /// Loads and decodes the stats cache. Returns `nil` when the file is missing or malformed.
    static func load(from path: String? = nil) -> StatsCache? {
        let filePath = path ?? defaultPath
        let url = URL(fileURLWithPath: filePath)

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(StatsCache.self, from: data)
    }

    /// Analytics source of truth. Claude Code's `stats-cache.json` is known to stop
    /// advancing (`lastComputedDate` stuck, token series truncated) while session
    /// transcripts keep growing — so a cache is used only when it actually covers
    /// the latest local session day.
    static func loadAnalytics(cachePath: String? = nil, projectsPath: String) -> StatsCache? {
        let cache = load(from: cachePath)
        let latestSessionDay = StatsComputer.latestSessionDay(projectsPath: projectsPath)
        if let cache, !isStale(cache, latestSessionDay: latestSessionDay) {
            return cache
        }
        return StatsComputer.compute(projectsPath: projectsPath) ?? cache
    }

    /// `true` when the cache's activity/token series does not cover the latest
    /// transcript day, or when tokens stop earlier than daily activity.
    static func isStale(_ cache: StatsCache, latestSessionDay: String?) -> Bool {
        let lastActivity = cache.dailyActivity.map(\.date).max() ?? ""
        let lastTokens = cache.dailyModelTokens.map(\.date).max() ?? ""

        if !lastActivity.isEmpty, lastTokens < lastActivity {
            return true
        }

        if let latestSessionDay {
            if lastTokens < latestSessionDay { return true }
            if lastActivity < latestSessionDay { return true }
        }

        return false
    }
}
