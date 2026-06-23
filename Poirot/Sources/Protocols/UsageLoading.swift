import Foundation

/// Outcome of a usage fetch. Distinguishes "we have no valid token" (a benign,
/// expected state Poirot surfaces as a prompt) from a transient failure.
nonisolated enum UsageResult: Sendable, Equatable {
    case success(ClaudeUsage)
    /// No credentials found, the token is expired, or the endpoint rejected it (401/403).
    case unauthenticated
    /// Network or decoding failure — worth retrying.
    case failure
}

/// Loads subscription rate-limit usage. Abstracted for dependency injection and testing.
protocol UsageLoading: Sendable {
    nonisolated func loadUsage() async -> UsageResult
}
