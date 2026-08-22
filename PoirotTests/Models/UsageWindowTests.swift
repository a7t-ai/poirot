@testable import Poirot
import Foundation
import Testing

@Suite("UsageWindow")
struct UsageWindowTests {
    @Test
    func fractionAndPercent() {
        #expect(UsageWindow(utilization: 20, resetsAt: nil).fraction == 0.2)
        #expect(UsageWindow(utilization: 20, resetsAt: nil).percent == 20)
        // Clamps above 100.
        #expect(UsageWindow(utilization: 150, resetsAt: nil).fraction == 1.0)
    }

    @Test
    func severityThresholds() {
        #expect(UsageWindow(utilization: 0, resetsAt: nil).severity == .normal)
        #expect(UsageWindow(utilization: 79.9, resetsAt: nil).severity == .normal)
        #expect(UsageWindow(utilization: 80, resetsAt: nil).severity == .warning)
        #expect(UsageWindow(utilization: 94.9, resetsAt: nil).severity == .warning)
        #expect(UsageWindow(utilization: 95, resetsAt: nil).severity == .critical)
        #expect(UsageWindow(utilization: 100, resetsAt: nil).severity == .critical)
    }

    @Test
    func timeUntilReset() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let future = UsageWindow(utilization: 10, resetsAt: now.addingTimeInterval(3600))
        let past = UsageWindow(utilization: 10, resetsAt: now.addingTimeInterval(-10))
        let none = UsageWindow(utilization: 10, resetsAt: nil)

        #expect(future.timeUntilReset(now: now) == 3600)
        #expect(past.timeUntilReset(now: now) == 0)
        #expect(none.timeUntilReset(now: now) == nil)
    }
}
