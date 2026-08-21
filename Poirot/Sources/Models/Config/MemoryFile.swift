import Foundation

nonisolated struct MemoryFile: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let filename: String
    let content: String
    let fileURL: URL
    let projectID: String
    /// Display label for a user-added folder source; `nil` for per-project memory files (whose
    /// label is resolved from the project list instead).
    var sourceLabel: String? = nil

    /// Whether this file came from a user-added folder rather than a project's memory dir.
    var isCustomSource: Bool {
        projectID.hasPrefix(Self.customSourcePrefix)
    }

    /// Prefix marking a `projectID` as a custom folder source (`custom:<path>`).
    static let customSourcePrefix = "custom:"

    /// Whether this is the main MEMORY.md entrypoint file.
    var isMain: Bool {
        filename.uppercased() == "MEMORY.MD"
    }

    /// A human-readable display name derived from the filename.
    /// e.g. "debugging.md" → "Debugging", "MEMORY.md" → "MEMORY"
    static func displayName(from filename: String) -> String {
        let stem = (filename as NSString).deletingPathExtension
        if stem.uppercased() == "MEMORY" { return "MEMORY" }
        return stem.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
