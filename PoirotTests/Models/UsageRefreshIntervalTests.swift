@testable import Poirot
import Testing

@Suite("UsageRefreshInterval")
struct UsageRefreshIntervalTests {
    @Test
    func manual_hasNoInterval() {
        #expect(UsageRefreshInterval.manual.seconds == nil)
        #expect(UsageRefreshInterval.manual.shortLabel == "Manual")
    }

    @Test
    func automatic_mapsMinutesToSeconds() {
        #expect(UsageRefreshInterval.fiveMinutes.seconds == 300)
        #expect(UsageRefreshInterval.twentyMinutes.seconds == 1200)
        #expect(UsageRefreshInterval.thirtyMinutes.seconds == 1800)
    }

    @Test
    func shortLabel_isCompactMinutes() {
        #expect(UsageRefreshInterval.tenMinutes.shortLabel == "10m")
        #expect(UsageRefreshInterval.twentyMinutes.shortLabel == "20m")
    }

    @Test
    func rawValueRoundTrips() {
        for interval in UsageRefreshInterval.allCases {
            #expect(UsageRefreshInterval(rawValue: interval.rawValue) == interval)
        }
    }
}
