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
