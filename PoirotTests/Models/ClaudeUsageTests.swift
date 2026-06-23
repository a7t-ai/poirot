@testable import Poirot
import Foundation
import Testing

@Suite("ClaudeUsage")
struct ClaudeUsageTests {
    // MARK: - Fixtures

    /// The real payload shape returned by `GET /api/oauth/usage` (values from a live call),
    /// including fields Poirot ignores (`limits`, dollar amounts) to prove the decoder
    /// tolerates them.
    private static let realPayload = """
    {
      "five_hour": {"utilization": 20.0, "resets_at": "2026-06-22T23:40:00.705258+00:00",
        "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
      "seven_day": {"utilization": 30.0, "resets_at": "2026-06-22T20:59:59.705282+00:00",
        "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
      "seven_day_oauth_apps": null,
      "seven_day_opus": null,
      "seven_day_sonnet": {"utilization": 0.0, "resets_at": null,
        "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
      "limits": [
        {"kind": "session", "group": "session", "percent": 20, "severity": "normal",
         "resets_at": "2026-06-22T23:40:00.705258+00:00", "scope": null, "is_active": false}
      ],
      "spend": {"used": {"amount_minor": 0, "currency": "USD", "exponent": 2},
        "limit": null, "percent": 0, "severity": "normal", "enabled": false},
      "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null,
        "utilization": null, "currency": null}
    }
    """

    // MARK: - Parsing

    @Test
    func parse_realPayload_extractsWindows() throws {
        let usage = try #require(ClaudeUsage.parse(Data(Self.realPayload.utf8)))

        #expect(usage.fiveHour.utilization == 20.0)
        #expect(usage.sevenDay.utilization == 30.0)
        #expect(usage.fiveHour.resetsAt != nil)
        #expect(usage.sevenDay.resetsAt != nil)
    }

    @Test
    func parse_realPayload_handlesPerModelWindows() throws {
        let usage = try #require(ClaudeUsage.parse(Data(Self.realPayload.utf8)))

        // Opus window is null in the payload; Sonnet is present with a null reset time.
        #expect(usage.sevenDayOpus == nil)
        #expect(usage.sevenDaySonnet?.utilization == 0.0)
        #expect(usage.sevenDaySonnet?.resetsAt == nil)
    }

    @Test
    func parse_realPayload_parsesDisabledSpendAndExtra() throws {
        let usage = try #require(ClaudeUsage.parse(Data(Self.realPayload.utf8)))

        #expect(usage.spend?.enabled == false)
        #expect(usage.spend?.usedDollars == 0)
        #expect(usage.extraUsage?.enabled == false)
    }

    @Test
    func parse_enabledSpend_computesDollarsFromMinorUnits() throws {
        let json = """
        {
          "five_hour": {"utilization": 10.0, "resets_at": null},
          "seven_day": {"utilization": 10.0, "resets_at": null},
          "spend": {"used": {"amount_minor": 1234, "currency": "USD", "exponent": 2},
            "limit": null, "percent": 42.5, "severity": "warning", "enabled": true}
        }
        """
        let usage = try #require(ClaudeUsage.parse(Data(json.utf8)))

        #expect(usage.spend?.enabled == true)
        #expect(usage.spend?.usedDollars == 12.34)
        #expect(usage.spend?.utilization == 42.5)
        #expect(usage.spend?.currency == "USD")
    }

    @Test
    func parse_missingRequiredWindow_returnsNil() {
        let json = #"{"seven_day": {"utilization": 30.0, "resets_at": null}}"#
        #expect(ClaudeUsage.parse(Data(json.utf8)) == nil)
    }

    @Test
    func parse_emptyData_returnsNil() {
        #expect(ClaudeUsage.parse(Data()) == nil)
        #expect(ClaudeUsage.parse(Data("not json".utf8)) == nil)
    }

    // MARK: - Date Parsing

    @Test
    func parseResetDate_microsecondsWithOffset() throws {
        let date = try #require(ClaudeUsage.parseResetDate("2026-06-22T23:40:00.705258+00:00"))

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        #expect(formatter.string(from: date) == "2026-06-22T23:40:00Z")
    }

    @Test
    func parseResetDate_millisecondsWithZulu() throws {
        let date = try #require(ClaudeUsage.parseResetDate("2026-01-13T19:55:30.879Z"))

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        #expect(formatter.string(from: date) == "2026-01-13T19:55:30Z")
    }

    @Test
    func parseResetDate_garbage_returnsNil() {
        #expect(ClaudeUsage.parseResetDate("nonsense") == nil)
    }

    // MARK: - UsageWindow Derived Values

    @Test
    func usageWindow_fractionAndPercent() {
        #expect(UsageWindow(utilization: 20, resetsAt: nil).fraction == 0.2)
        #expect(UsageWindow(utilization: 20, resetsAt: nil).percent == 20)
        // Clamps above 100.
        #expect(UsageWindow(utilization: 150, resetsAt: nil).fraction == 1.0)
    }

    @Test
    func usageWindow_severityThresholds() {
        #expect(UsageWindow(utilization: 0, resetsAt: nil).severity == .normal)
        #expect(UsageWindow(utilization: 79.9, resetsAt: nil).severity == .normal)
        #expect(UsageWindow(utilization: 80, resetsAt: nil).severity == .warning)
        #expect(UsageWindow(utilization: 94.9, resetsAt: nil).severity == .warning)
        #expect(UsageWindow(utilization: 95, resetsAt: nil).severity == .critical)
        #expect(UsageWindow(utilization: 100, resetsAt: nil).severity == .critical)
    }

    // MARK: - Countdown Formatting

    @Test
    func usageCountdown_format() {
        #expect(UsageCountdown.format(2 * 86400 + 6 * 3600) == "2d 6h")
        #expect(UsageCountdown.format(3 * 3600 + 14 * 60) == "3h 14m")
        #expect(UsageCountdown.format(12 * 60) == "12m")
        #expect(UsageCountdown.format(30) == "<1m")
        #expect(UsageCountdown.format(-100) == "<1m")
    }

    @Test
    func usageWindow_timeUntilReset() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let future = UsageWindow(utilization: 10, resetsAt: now.addingTimeInterval(3600))
        let past = UsageWindow(utilization: 10, resetsAt: now.addingTimeInterval(-10))
        let none = UsageWindow(utilization: 10, resetsAt: nil)

        #expect(future.timeUntilReset(now: now) == 3600)
        #expect(past.timeUntilReset(now: now) == 0)
        #expect(none.timeUntilReset(now: now) == nil)
    }
}
