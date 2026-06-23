@testable import Poirot
import Foundation
import Testing

@Suite("ClaudeCredentials")
struct ClaudeCredentialsTests {
    /// Mirrors the on-disk / Keychain shape (camelCase keys, `expiresAt` in epoch ms).
    private static let sample = """
    {
      "claudeAiOauth": {
        "accessToken": "sk-ant-oat-abc123",
        "refreshToken": "sk-ant-ort-xyz789",
        "expiresAt": 1782144420074,
        "scopes": ["user:inference", "user:profile"],
        "subscriptionType": "max",
        "rateLimitTier": "default_claude_max_5x"
      }
    }
    """

    @Test
    func parse_sample_extractsToken() throws {
        let credentials = try #require(ClaudeCredentials.parse(Data(Self.sample.utf8)))

        #expect(credentials.accessToken == "sk-ant-oat-abc123")
        #expect(credentials.subscriptionType == "max")
        #expect(credentials.expiresAt.timeIntervalSince1970 == 1_782_144_420.074)
    }

    @Test
    func parse_emptyToken_returnsNil() {
        let json = #"{"claudeAiOauth": {"accessToken": "", "expiresAt": 1782144420074}}"#
        #expect(ClaudeCredentials.parse(Data(json.utf8)) == nil)
    }

    @Test
    func parse_malformed_returnsNil() {
        #expect(ClaudeCredentials.parse(Data()) == nil)
        #expect(ClaudeCredentials.parse(Data(#"{"unexpected": true}"#.utf8)) == nil)
    }

    @Test
    func isExpired_comparesAgainstNow() {
        let credentials = ClaudeCredentials(
            accessToken: "t",
            expiresAt: Date(timeIntervalSince1970: 1_000_000),
            subscriptionType: nil
        )

        #expect(credentials.isExpired(now: Date(timeIntervalSince1970: 1_000_001)))
        #expect(!credentials.isExpired(now: Date(timeIntervalSince1970: 999_999)))
    }
}
