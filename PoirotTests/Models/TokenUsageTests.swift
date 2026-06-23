@testable import Poirot
import Testing

@Suite("TokenUsage")
struct TokenUsageTests {
    // MARK: - Total

    @Test
    func total_sumsInputAndOutput() {
        let usage = TokenUsage(input: 100, output: 200)
        #expect(usage.total == 300)
    }

    // MARK: - Formatted

    @Test
    func formatted_below1000_returnsPlainInt() {
        let usage = TokenUsage(input: 400, output: 99)
        #expect(usage.formatted == "499")
    }

    @Test
    func formatted_exactly1000_returns1_0k() {
        let usage = TokenUsage(input: 500, output: 500)
        #expect(usage.formatted == "1.0k")
    }

    @Test
    func formatted_above1000_returnsDecimalK() {
        let usage = TokenUsage(input: 1000, output: 500)
        #expect(usage.formatted == "1.5k")
    }

    @Test
    func formatted_zeroTokens_returnsZero() {
        let usage = TokenUsage(input: 0, output: 0)
        #expect(usage.formatted == "0")
    }

    @Test
    func formatted_largeValue_correctFormat() {
        let usage = TokenUsage(input: 50000, output: 75000)
        #expect(usage.formatted == "125.0k")
    }

    // MARK: - Context tokens & cache

    @Test
    func contextTokens_sumsPromptSide() {
        let usage = TokenUsage(input: 2, output: 213, cacheRead: 437_861, cacheCreation: 2414)
        // Prompt side only (output excluded): 2 + 437861 + 2414
        #expect(usage.contextTokens == 440_277)
    }

    @Test
    func cacheHitRate_fractionOfPromptFromCache() {
        let usage = TokenUsage(input: 100, output: 50, cacheRead: 300, cacheCreation: 100)
        // cacheRead / (input + cacheRead + cacheCreation) = 300 / 500
        #expect(usage.cacheHitRate == 0.6)
    }

    @Test
    func cacheHitRate_noPrompt_isZero() {
        #expect(TokenUsage(input: 0, output: 0).cacheHitRate == 0)
    }

    @Test
    func legacyInit_defaultsCacheToZero() {
        let usage = TokenUsage(input: 100, output: 200)
        #expect(usage.cacheRead == 0)
        #expect(usage.cacheCreation == 0)
        #expect(usage.contextTokens == 100)
    }
}
