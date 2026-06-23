import Foundation

/// Per-conversation context-window usage, derived entirely from the local transcript's
/// per-turn `usage` data — no network, no Keychain. "Context" here is the prompt side of a
/// turn (fresh input + cache reads + cache writes); the most recent turn reflects how full
/// the window was when the conversation last ran.
nonisolated struct ContextUsage: Sendable, Equatable {
    /// Standard Claude context window; the 1M tier is a beta only some models/turns use.
    static let standardWindow = 200_000
    static let extendedWindow = 1_000_000

    /// Context size of the most recent turn that carried usage.
    let current: Int
    /// Largest context size seen across the conversation.
    let peak: Int
    let window: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheCreationTokens: Int
    /// Context size per turn, in order — for the growth sparkline.
    let series: [Int]

    var isEmpty: Bool { series.isEmpty }

    /// How full the window is right now (0...1).
    var fraction: Double {
        window > 0 ? min(max(Double(current) / Double(window), 0), 1) : 0
    }

    var percent: Int { Int((fraction * 100).rounded()) }

    /// Fraction (0...1) of all prompt tokens served from cache across the conversation.
    var cacheHitRate: Double {
        let promptTotal = inputTokens + cacheReadTokens + cacheCreationTokens
        return promptTotal > 0 ? Double(cacheReadTokens) / Double(promptTotal) : 0
    }

    static func from(_ messages: [Message]) -> ContextUsage {
        let usages = messages.compactMap(\.tokenUsage)
        let series = usages.map(\.contextTokens).filter { $0 > 0 }
        let peak = series.max() ?? 0
        // Infer the window from observed usage: a turn that exceeded the standard tier must
        // have been on the extended (1M) window.
        let window = peak > standardWindow ? extendedWindow : standardWindow

        return ContextUsage(
            current: series.last ?? 0,
            peak: peak,
            window: window,
            inputTokens: usages.reduce(0) { $0 + $1.input },
            outputTokens: usages.reduce(0) { $0 + $1.output },
            cacheReadTokens: usages.reduce(0) { $0 + $1.cacheRead },
            cacheCreationTokens: usages.reduce(0) { $0 + $1.cacheCreation },
            series: series
        )
    }
}
