@testable import Poirot
import Testing

@Suite("HighlightedText.substringMatch")
struct HighlightedTextSubstringTests {
    @Test
    func matches_caseInsensitiveSubstring() {
        #expect(HighlightedText.substringMatch("Fix SSH tunnel", query: "ssh") != nil)
        #expect(HighlightedText.substringMatch("fix ssh", query: "SSH") != nil)
    }

    @Test
    func rejects_scatteredSubsequence_thatFuzzyWouldMatch() {
        // "ssh" is a scattered subsequence of "swordfish" (s..s..h), so fuzzy matches it — the
        // source of the noisy results. Match Word must reject it (no contiguous "ssh").
        #expect(HighlightedText.fuzzyMatch("swordfish", query: "ssh") != nil)
        #expect(HighlightedText.substringMatch("swordfish", query: "ssh") == nil)
    }

    @Test
    func ranksPrefixOverBoundaryOverMid() {
        let prefix = HighlightedText.substringMatch("ssh config", query: "ssh") ?? 0
        let boundary = HighlightedText.substringMatch("fix ssh now", query: "ssh") ?? 0
        let mid = HighlightedText.substringMatch("misshapen", query: "ssh") ?? 0
        #expect(prefix > boundary)
        #expect(boundary > mid)
    }

    @Test
    func emptyQuery_returnsZero() {
        #expect(HighlightedText.substringMatch("anything", query: "") == 0)
    }
}
