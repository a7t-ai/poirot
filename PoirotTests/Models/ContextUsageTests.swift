@testable import Poirot
import Foundation
import Testing

@Suite("ContextUsage")
struct ContextUsageTests {
    private func message(_ usage: TokenUsage?) -> Message {
        Message(
            id: UUID().uuidString,
            role: .assistant,
            content: [],
            timestamp: Date(timeIntervalSince1970: 0),
            model: nil,
            tokenUsage: usage
        )
    }

    @Test
    func from_computesCurrentPeakAndSeries() {
        let messages = [
            message(TokenUsage(input: 10, output: 5, cacheRead: 1000, cacheCreation: 200)), // ctx 1210
            message(TokenUsage(input: 20, output: 8, cacheRead: 5000, cacheCreation: 300)), // ctx 5320
            message(nil), // no usage → skipped
            message(TokenUsage(input: 5, output: 2, cacheRead: 3000, cacheCreation: 100)), // ctx 3105
        ]

        let ctx = ContextUsage.from(messages)

        #expect(ctx.series == [1210, 5320, 3105])
        #expect(ctx.current == 3105) // most recent turn
        #expect(ctx.peak == 5320)
        #expect(ctx.window == 200_000) // peak under the standard tier
    }

    @Test
    func from_infersExtendedWindowAbove200k() {
        let ctx = ContextUsage.from([
            message(TokenUsage(input: 2, output: 213, cacheRead: 437_861, cacheCreation: 2414)),
        ])

        #expect(ctx.current == 440_277)
        #expect(ctx.window == 1_000_000)
        #expect(ctx.percent == 44)
    }

    @Test
    func cacheHitRate_aggregatesAcrossTurns() {
        let messages = [
            message(TokenUsage(input: 100, output: 0, cacheRead: 300, cacheCreation: 100)), // prompt 500
            message(TokenUsage(input: 0, output: 0, cacheRead: 500, cacheCreation: 0)), // prompt 500
        ]

        let ctx = ContextUsage.from(messages)

        // total cacheRead 800 / total prompt 1000
        #expect(ctx.cacheHitRate == 0.8)
    }

    @Test
    func from_noUsage_isEmpty() {
        let ctx = ContextUsage.from([message(nil)])

        #expect(ctx.isEmpty)
        #expect(ctx.current == 0)
        #expect(ctx.fraction == 0)
    }
}
