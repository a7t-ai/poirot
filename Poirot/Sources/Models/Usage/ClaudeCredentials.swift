import Foundation

/// Claude Code's OAuth credentials, as persisted by the CLI itself. Poirot only ever
/// *reads* these — it never logs in, refreshes, or writes them back (see `ClaudeCredentialsReader`).
nonisolated struct ClaudeCredentials: Sendable, Equatable {
    let accessToken: String
    let expiresAt: Date
    let subscriptionType: String?

    /// Whether the access token is past its expiry. Poirot does not refresh tokens;
    /// when expired it waits for Claude Code to refresh its own credential.
    func isExpired(now: Date = Date()) -> Bool {
        now >= expiresAt
    }

    /// Parses the credential JSON stored both in the macOS Keychain item and in
    /// `~/.claude/.credentials.json`. The keys are already camelCase on disk, so no
    /// key-decoding strategy is applied. Returns `nil` when the body is malformed or
    /// carries an empty token.
    nonisolated static func parse(_ data: Data) -> ClaudeCredentials? {
        guard let dto = try? JSONDecoder().decode(CredentialsDTO.self, from: data) else {
            return nil
        }
        let oauth = dto.claudeAiOauth
        guard !oauth.accessToken.isEmpty else { return nil }

        return ClaudeCredentials(
            accessToken: oauth.accessToken,
            expiresAt: Date(timeIntervalSince1970: oauth.expiresAt / 1000),
            subscriptionType: oauth.subscriptionType
        )
    }
}

// MARK: - Decoding DTO

nonisolated private struct CredentialsDTO: Decodable {
    nonisolated struct OAuth: Decodable {
        let accessToken: String
        /// Milliseconds since the Unix epoch.
        let expiresAt: Double
        let subscriptionType: String?
    }

    let claudeAiOauth: OAuth
}
