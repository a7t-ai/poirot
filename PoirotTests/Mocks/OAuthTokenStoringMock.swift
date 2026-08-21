@testable import Poirot

/// In-memory `OAuthTokenStoring` so tests never touch the real Keychain.
final class OAuthTokenStoringMock: OAuthTokenStoring, @unchecked Sendable {
    var token: String?

    init(token: String? = nil) { self.token = token }

    func read() -> String? { token }
    func save(_ token: String) { self.token = token }
    func delete() { token = nil }
}
