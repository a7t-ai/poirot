import Foundation
import Observation

/// Observable list of extra folders the user has added as memory sources, on top of the
/// per-project `~/.claude/projects/<hash>/memory/` directories Poirot discovers automatically.
///
/// Poirot is not sandboxed, so the folders are stored as plain paths (no security-scoped
/// bookmarks needed) and read directly. A single instance is created in `PoirotApp` and shared
/// with the Memory screen and Settings.
@MainActor
@Observable
final class MemorySourcesStore {
    /// UserDefaults key for the persisted folder paths. Read directly by `ClaudeConfigLoader`
    /// so memory counts stay correct even before this store is constructed.
    nonisolated static let foldersKey = "customMemoryFolders"

    private(set) var folders: [URL]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.folders = Self.loadFolders(from: defaults)
    }

    /// Add a folder as a memory source. No-op if it's already present.
    func add(_ url: URL) {
        let folder = url.standardizedFileURL
        guard !folders.contains(where: { $0.standardizedFileURL == folder }) else { return }
        folders.append(folder)
        persist()
    }

    /// Remove a previously added folder.
    func remove(_ url: URL) {
        let folder = url.standardizedFileURL
        folders.removeAll { $0.standardizedFileURL == folder }
        persist()
    }

    private func persist() {
        defaults.set(folders.map(\.path), forKey: Self.foldersKey)
    }

    /// A store backed by a throwaway defaults suite — for previews and snapshot tests, so it
    /// never reads or writes the real `.standard` folder list.
    static func previewEmpty() -> MemorySourcesStore {
        MemorySourcesStore(defaults: UserDefaults(suiteName: "fyi.poirot.preview.memory") ?? .standard)
    }

    /// The persisted folder paths, resolved to URLs. `nonisolated` so non-UI code (counts,
    /// loaders) can read them without hopping to the main actor or holding the instance.
    nonisolated static func loadFolders(from defaults: UserDefaults = .standard) -> [URL] {
        (defaults.stringArray(forKey: foldersKey) ?? []).map { URL(fileURLWithPath: $0) }
    }
}
