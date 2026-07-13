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

@Suite("ClaudeCredentialStore")
struct ClaudeCredentialStoreTests {
    /// Counts how many times the store fell through to an actual credential read. Safe to mutate
    /// unsynchronized because every call is serialized through the store's actor isolation.
    private nonisolated final class ReaderSpy: @unchecked Sendable {
        private(set) var calls = 0
        private let credential: ClaudeCredentials?
        init(_ credential: ClaudeCredentials?) { self.credential = credential }
        func read() -> ClaudeCredentials? {
            calls += 1
            return credential
        }
    }

    private static func creds(expiresIn seconds: TimeInterval) -> ClaudeCredentials {
        ClaudeCredentials(
            accessToken: "tok",
            expiresAt: Date().addingTimeInterval(seconds),
            subscriptionType: "max"
        )
    }

    @Test
    func current_readsOnce_whileTokenValid() async {
        let spy = ReaderSpy(Self.creds(expiresIn: 3600))
        let store = ClaudeCredentialStore(reader: { spy.read() })

        _ = await store.current()
        _ = await store.current()

        // Second call is served from cache — no Keychain hit, so no re-prompt.
        #expect(spy.calls == 1)
    }

    @Test
    func current_reReads_whenCachedTokenExpired() async {
        let spy = ReaderSpy(Self.creds(expiresIn: -10))
        let store = ClaudeCredentialStore(reader: { spy.read() })

        _ = await store.current()
        _ = await store.current()

        #expect(spy.calls == 2)
    }

    @Test
    func invalidate_forcesReRead() async {
        let spy = ReaderSpy(Self.creds(expiresIn: 3600))
        let store = ClaudeCredentialStore(reader: { spy.read() })

        _ = await store.current()
        await store.invalidate()
        _ = await store.current()

        #expect(spy.calls == 2)
    }

    @Test
    func current_returnsNil_andDoesNotCache_whenNoCredential() async {
        let spy = ReaderSpy(nil)
        let store = ClaudeCredentialStore(reader: { spy.read() })

        let first = await store.current()
        let second = await store.current()

        #expect(first == nil)
        #expect(second == nil)
        #expect(spy.calls == 2)
    }
}
