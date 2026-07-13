import Foundation

/// Fetches subscription rate-limit usage from Claude's OAuth usage endpoint, reusing the
/// token Claude Code already stored locally. No login flow, no API key, no stored secret of
/// our own — Poirot borrows the existing credential read-only.
nonisolated struct ClaudeUsageLoader: UsageLoading {
    static let endpoint = "https://api.anthropic.com/api/oauth/usage"
    /// Beta header the OAuth usage endpoint requires.
    static let betaHeader = "oauth-2025-04-20"
    static let apiVersion = "2023-06-01"

    nonisolated func loadUsage() async -> UsageResult {
        // Reuse the cached credential when possible so repeated background refreshes don't hit
        // the Keychain — and re-prompt for authorization — on every poll.
        guard let credentials = await ClaudeCredentialStore.shared.current() else {
            return .unauthenticated
        }
        // Poirot never refreshes tokens; if Claude Code hasn't refreshed its own, surface
        // the unauthenticated state rather than firing a request we know will 401.
        guard !credentials.isExpired() else {
            return .unauthenticated
        }
        guard let url = URL(string: Self.endpoint) else {
            return .failure
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse
        else {
            return .failure
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            // The cached token was rejected — drop it so the next attempt re-reads whatever
            // credential Claude Code has rotated to.
            await ClaudeCredentialStore.shared.invalidate()
            return .unauthenticated
        }
        if http.statusCode == 429 {
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
            return .rateLimited(retryAfter: retryAfter)
        }
        guard http.statusCode == 200, let usage = ClaudeUsage.parse(data) else {
            return .failure
        }
        return .success(usage)
    }
}
