import Foundation

/// Fetches subscription rate-limit usage from Claude's OAuth usage endpoint, using the token
/// the user generates with `claude setup-token` and pastes into Poirot. No login flow, no API
/// key — the token is read from Poirot's own Keychain item (see `PoirotTokenStore`).
nonisolated struct ClaudeUsageLoader: UsageLoading {
    static let endpoint = "https://api.anthropic.com/api/oauth/usage"
    /// Beta header the OAuth usage endpoint requires.
    static let betaHeader = "oauth-2025-04-20"
    static let apiVersion = "2023-06-01"

    private let tokenStore: any OAuthTokenStoring

    init(tokenStore: any OAuthTokenStoring = PoirotTokenStore()) {
        self.tokenStore = tokenStore
    }

    nonisolated func loadUsage() async -> UsageResult {
        // Reads Poirot's own Keychain item, which Poirot owns — no authorization prompt.
        guard let token = tokenStore.read(), !token.isEmpty else {
            return .unauthenticated
        }
        guard let url = URL(string: Self.endpoint) else {
            return .failure
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse
        else {
            return .failure
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            // Token rejected or expired — the user needs to generate a fresh one with
            // `claude setup-token` and update it in Settings.
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
