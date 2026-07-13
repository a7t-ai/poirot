import Foundation
import Security

/// Reads the OAuth credentials that Claude Code already stores locally — Poirot never
/// runs its own login flow. The macOS Keychain item is authoritative (Claude Code keeps
/// it fresh on every refresh); the on-disk file is a fallback that can lag behind.
///
/// The first Keychain read from Poirot may surface the standard macOS authorization
/// dialog ("Allow / Always Allow"). That is a system credential-access prompt, not a
/// Claude login. Poirot only reads — it never writes Claude Code's credentials.
nonisolated enum ClaudeCredentialsReader {
    /// Keychain generic-password service name used by the Claude Code CLI.
    static let keychainService = "Claude Code-credentials"

    private static var defaultFilePath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/.credentials.json"
    }

    /// Reads credentials, preferring the Keychain and falling back to the file.
    /// - Parameter filePath: overrides the fallback file path (used by tests).
    static func read(filePath: String? = nil) -> ClaudeCredentials? {
        if let data = keychainData(), let credentials = ClaudeCredentials.parse(data) {
            return credentials
        }
        return readFromFile(filePath ?? defaultFilePath)
    }

    /// Reads credentials only from a JSON file. Never touches the Keychain, so it never
    /// triggers an authorization prompt — handy for tests and as a fallback.
    static func readFromFile(_ path: String) -> ClaudeCredentials? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return ClaudeCredentials.parse(data)
    }

    private static func keychainData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }
}

/// In-memory cache for Claude Code's credential so background usage refreshes don't hit the
/// Keychain — and re-trigger the macOS authorization dialog — on every poll. The Keychain is
/// read only when the cache is empty or the cached token is about to expire; otherwise the
/// same token is reused for the rest of its lifetime. On an auth failure the caller invalidates
/// the cache so the next read picks up a token Claude Code has since rotated.
actor ClaudeCredentialStore {
    static let shared = ClaudeCredentialStore()

    /// Re-read slightly before the token's stated expiry so a nearly-dead token is never sent.
    private static let expiryMargin: TimeInterval = 60

    private let reader: @Sendable () -> ClaudeCredentials?
    private var cached: ClaudeCredentials?

    init(reader: @escaping @Sendable () -> ClaudeCredentials? = { ClaudeCredentialsReader.read() }) {
        self.reader = reader
    }

    /// Returns a usable credential, reading the Keychain only when necessary. Calls made within
    /// the token's lifetime reuse the cached value and never touch the Keychain (so no prompt).
    func current(now: Date = Date()) -> ClaudeCredentials? {
        if let cached, !cached.isExpired(now: now.addingTimeInterval(Self.expiryMargin)) {
            return cached
        }
        let fresh = reader()
        cached = fresh
        return fresh
    }

    /// Drops the cached credential so the next `current()` re-reads the Keychain. Call after an
    /// authorization failure, when Claude Code has most likely rotated the token.
    func invalidate() {
        cached = nil
    }
}
