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
        #expect(UsageRefreshInterval.oneMinute.seconds == 60)
        #expect(UsageRefreshInterval.fiveMinutes.seconds == 300)
        #expect(UsageRefreshInterval.thirtyMinutes.seconds == 1800)
    }

    @Test
    func shortLabel_isCompactMinutes() {
        #expect(UsageRefreshInterval.twoMinutes.shortLabel == "2m")
        #expect(UsageRefreshInterval.tenMinutes.shortLabel == "10m")
    }

    @Test
    func rawValueRoundTrips() {
        for interval in UsageRefreshInterval.allCases {
            #expect(UsageRefreshInterval(rawValue: interval.rawValue) == interval)
        }
    }
}
