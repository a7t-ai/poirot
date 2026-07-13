@testable import Poirot
import Testing

@Suite("ClaudeModelCatalog")
struct ClaudeModelCatalogTests {
    @Test
    func friendlyName_mapsCurrentIds() {
        #expect(ClaudeModelCatalog.friendlyName(for: "claude-opus-4-8-20260514") == "Opus 4.8")
        #expect(ClaudeModelCatalog.friendlyName(for: "claude-sonnet-5-20251101") == "Sonnet 5")
        #expect(ClaudeModelCatalog.friendlyName(for: "claude-haiku-4-5-20251001") == "Haiku 4.5")
        #expect(ClaudeModelCatalog.friendlyName(for: "claude-fable-5") == "Fable 5")
    }

    @Test
    func friendlyName_handlesLegacyOrdering() {
        // Older ids put the version numbers before the family name.
        #expect(ClaudeModelCatalog.friendlyName(for: "claude-3-5-sonnet-20241022") == "Sonnet 3.5")
        #expect(ClaudeModelCatalog.friendlyName(for: "claude-3-opus-20240229") == "Opus 3")
    }

    @Test
    func friendlyName_unknownId_passesThrough() {
        #expect(ClaudeModelCatalog.friendlyName(for: "gpt-4o") == "gpt-4o")
    }

    @Test
    func models_includeAllCurated_evenWithNoSessions() {
        let names = ClaudeModelCatalog.models(discoveredIds: []).map(\.displayName)
        #expect(names.contains("Fable 5"))
        #expect(names.contains("Opus 4.8"))
        #expect(names.count == ClaudeModelCatalog.curated.count)
    }

    @Test
    func models_appendDiscovered_withoutDuplicatingCurated() {
        let models = ClaudeModelCatalog.models(discoveredIds: [
            "claude-opus-4-8-20260514",   // already curated -> not duplicated
            "claude-3-5-sonnet-20241022", // discovered -> appended once
            "claude-3-5-sonnet-20241022", // duplicate -> deduped
            "",                            // empty -> ignored
        ])
        let names = models.map(\.displayName)

        #expect(names.filter { $0 == "Opus 4.8" }.count == 1)
        #expect(names.filter { $0 == "Sonnet 3.5" }.count == 1)
        // Curated set plus exactly one newly-discovered model.
        #expect(names.count == ClaudeModelCatalog.curated.count + 1)
    }
}
