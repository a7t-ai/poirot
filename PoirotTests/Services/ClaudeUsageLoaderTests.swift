@testable import Poirot
import Testing

@Suite("ClaudeUsageLoader")
struct ClaudeUsageLoaderTests {
    /// With no token stored, the loader reports `.unauthenticated` without firing a request —
    /// the dashboard uses this to prompt the user to add a token.
    @Test
    func loadUsage_withoutToken_isUnauthenticated() async {
        let loader = ClaudeUsageLoader(tokenStore: OAuthTokenStoringMock(token: nil))

        let result = await loader.loadUsage()

        #expect(result == .unauthenticated)
    }
}
