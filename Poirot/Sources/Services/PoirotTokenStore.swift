import Foundation
import Security

/// Read/write access to the OAuth token Poirot uses to query subscription usage. Abstracted
/// so the Keychain-backed store can be swapped for an in-memory conformer in tests.
nonisolated protocol OAuthTokenStoring: Sendable {
    /// The stored token, or `nil` when none has been saved.
    func read() -> String?
    /// Persist `token`, replacing any existing value.
    func save(_ token: String)
    /// Remove the stored token.
    func delete()
}

/// Stores the usage OAuth token — the one the user generates with `claude setup-token` — in a
/// Keychain item that **Poirot itself creates and owns**. Because Poirot owns the item, reading
/// it back never surfaces the macOS authorization dialog. This deliberately replaces reading
/// Claude Code's own credential item, which re-prompted for authorization on every launch even
/// after "Always Allow".
///
/// Poirot never runs a login flow: the token is supplied by the user and used only as a Bearer
/// token against Anthropic's usage endpoint.
nonisolated struct PoirotTokenStore: OAuthTokenStoring {
    /// Stable, build-independent Keychain service name. Deliberately not the bundle id, which
    /// varies per worktree — a constant keeps the saved token across builds and app updates.
    static let service = "fyi.poirot.usage-oauth-token"
    static let account = "oauth"

    func read() -> String? { Self.read() }
    func save(_ token: String) { Self.save(token) }
    func delete() { Self.delete() }

    static var hasToken: Bool { read() != nil }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty
        else { return nil }
        return token
    }

    static func save(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        // Replace any existing value so the item's ACL is (re)owned by the current build.
        delete()
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
