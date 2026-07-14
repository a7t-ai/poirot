import Foundation

/// A Claude model as shown on the Models screen: a friendly display name plus optional curated
/// copy. Models discovered only in session transcripts (not curated) carry an empty description.
nonisolated struct ClaudeModelInfo: Identifiable, Hashable, Sendable {
    let displayName: String
    let description: String
    let strengths: [String]

    var id: String { displayName }

    init(displayName: String, description: String = "", strengths: [String] = []) {
        self.displayName = displayName
        self.description = description
        self.strengths = strengths
    }
}

/// The set of Claude models Poirot shows. Rather than a single hardcoded array, the catalog
/// combines a curated set of current models — so a new one like Fable appears with a real
/// description even before you've used it — with any model discovered in your own session
/// transcripts, so a model you start using shows up on its own. Fully local: no network call and
/// no `/v1/models` lookup.
nonisolated enum ClaudeModelCatalog {
    /// Curated current models, most capable first. The copy is a starting point — tweak freely.
    static let curated: [ClaudeModelInfo] = [
        ClaudeModelInfo(
            displayName: "Opus 4.8",
            description: "Most capable Claude model for complex reasoning, large-codebase work, and multi-step tasks.",
            strengths: [
                "Complex multi-step reasoning",
                "Large codebase analysis",
                "Architecture design",
                "Nuanced debugging",
            ]
        ),
        ClaudeModelInfo(
            displayName: "Sonnet 5",
            description: "Balanced speed and capability for everyday coding and conversation.",
            strengths: [
                "Fast interactive coding",
                "Code generation",
                "Refactoring",
                "Everyday tasks",
            ]
        ),
        ClaudeModelInfo(
            displayName: "Haiku 4.5",
            description: "Fastest, lightest Claude model for quick, low-latency tasks.",
            strengths: [
                "Fastest response time",
                "Simple lookups",
                "Quick edits",
                "Low-latency workflows",
            ]
        ),
        ClaudeModelInfo(
            displayName: "Fable 5",
            description: "Anthropic's most advanced model for demanding reasoning and long-horizon agentic work.",
            strengths: [
                "Ambitious coding projects",
                "Long-horizon agentic work",
                "Deep research and analysis",
                "Document and diagram understanding",
            ]
        ),
    ]

    /// Display names of the curated models — the baseline list used by search and counts.
    static var curatedNames: [String] { curated.map(\.displayName) }

    /// Model Poirot assumes as the default when none is configured.
    static let defaultModelName = "Opus 4.8"

    /// Maps a raw session model id to a friendly display name, e.g. `claude-opus-4-8-20260514`
    /// → `Opus 4.8` and the older `claude-3-5-sonnet-20241022` → `Sonnet 3.5`. Version digits are
    /// gathered from the short numeric segments (the long date/build stamp is ignored), so it is
    /// robust to Anthropic's family-first and family-last id orderings. Unknown ids pass through.
    static func friendlyName(for modelId: String) -> String {
        let lower = modelId.lowercased()
        let families = [("opus", "Opus"), ("sonnet", "Sonnet"), ("haiku", "Haiku"), ("fable", "Fable")]
        guard let (_, label) = families.first(where: { lower.contains($0.0) }) else {
            return modelId
        }
        var stripped = lower
        if stripped.hasPrefix("claude-") {
            stripped = String(stripped.dropFirst("claude-".count))
        }
        // Short numeric segments are version parts; a >= 6-digit segment is the date/build stamp.
        let version = stripped
            .split(separator: "-")
            .map(String.init)
            .filter { $0.allSatisfy(\.isNumber) && $0.count < 6 }
            .joined(separator: ".")
        return version.isEmpty ? label : "\(label) \(version)"
    }

    /// The full model list to display: curated models first, then any distinct model found in
    /// `discoveredIds` that the curated set doesn't already cover (deduped by friendly name).
    static func models(discoveredIds: [String]) -> [ClaudeModelInfo] {
        var result = curated
        var seen = Set(curated.map(\.displayName))
        for id in discoveredIds where !id.isEmpty {
            let name = friendlyName(for: id)
            guard seen.insert(name).inserted else { continue }
            result.append(ClaudeModelInfo(displayName: name))
        }
        return result
    }
}
