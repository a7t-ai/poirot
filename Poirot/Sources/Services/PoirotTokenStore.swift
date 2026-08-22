import Foundation

/// Read/write access to the OAuth token Poirot uses to query subscription usage. Abstracted
/// so the file-backed store can be swapped for an in-memory conformer in tests.
nonisolated protocol OAuthTokenStoring: Sendable {
    /// The stored token, or `nil` when none has been saved.
    func read() -> String?
    /// Persist `token`, replacing any existing value.
    func save(_ token: String)
    /// Remove the stored token.
    func delete()
}

/// Stores the usage OAuth token — the one the user generates with `claude setup-token` — in a
/// plain file inside Poirot's Application Support folder, readable only by the user (`0600`).
///
/// Deliberately **not** the macOS Keychain: a Keychain item prompts for authorization unless the
/// reading app is signed with a stable identity that's in the item's ACL, so unsigned/ad-hoc
/// builds re-prompt on every read even after "Always Allow". A file avoids that entirely — no
/// prompt in any build. It's the same posture Claude Code itself uses for `~/.claude/.credentials.json`.
///
/// Poirot never runs a login flow: the token is supplied by the user and used only as a Bearer
/// token against Anthropic's usage endpoint.
nonisolated struct PoirotTokenStore: OAuthTokenStoring {
    private let fileURL: URL

    /// - Parameter directory: overrides the storage directory (used by tests). Defaults to
    ///   `~/Library/Application Support/Poirot`.
    init(directory: URL? = nil) {
        fileURL = (directory ?? Self.defaultDirectory).appendingPathComponent("usage-token")
    }

    static var defaultDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Poirot", isDirectory: true)
    }

    func read() -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let token = String(data: data, encoding: .utf8)?
              .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty
        else { return nil }
        return token
    }

    func save(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        guard (try? data.write(to: fileURL, options: [.atomic])) != nil else { return }
        // Tighten to owner-only read/write; atomic writes can otherwise land at the umask default.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
