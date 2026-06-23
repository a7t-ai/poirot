import Foundation

// MARK: - Usage Severity

/// Coarse severity buckets derived from a window's utilization percentage.
/// Pure value type — the color mapping lives in the view layer (see `UsageGaugeCard`).
nonisolated enum UsageSeverity: Sendable, Equatable {
    case normal
    case warning
    case critical

    /// Utilization (0–100) at or above which a window is considered "warning".
    static let warningThreshold: Double = 80
    /// Utilization (0–100) at or above which a window is considered "critical".
    static let criticalThreshold: Double = 95

    init(utilization: Double) {
        switch utilization {
        case ..<Self.warningThreshold: self = .normal
        case ..<Self.criticalThreshold: self = .warning
        default: self = .critical
        }
    }
}

// MARK: - Usage Window

/// A single rate-limit window (e.g. the rolling 5-hour or 7-day window) as reported
/// by Claude's OAuth usage endpoint.
///
/// `utilization` is the raw value from the API, expressed as a **percentage in 0...100**
/// (e.g. `20.0` means 20% used) — not a 0...1 fraction.
nonisolated struct UsageWindow: Sendable, Equatable, Codable {
    let utilization: Double
    let resetsAt: Date?

    /// Utilization clamped to the 0...1 range for `Gauge` and progress views.
    var fraction: Double { min(max(utilization / 100, 0), 1) }

    /// Utilization rounded to a whole percent for display.
    var percent: Int { Int(utilization.rounded()) }

    var severity: UsageSeverity { UsageSeverity(utilization: utilization) }

    /// Seconds until this window resets, or `nil` when no reset time is known.
    /// Never negative — a past reset time clamps to `0`.
    func timeUntilReset(now: Date = Date()) -> TimeInterval? {
        guard let resetsAt else { return nil }
        return max(0, resetsAt.timeIntervalSince(now))
    }
}

// MARK: - Countdown Formatting

/// Formats a remaining-time interval for usage reset countdowns. Shared by the dashboard
/// and the menu bar so both read identically.
nonisolated enum UsageCountdown {
    /// Human-friendly remaining time: `"2d 6h"`, `"3h 14m"`, `"12m"`, or `"<1m"`.
    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }
}

// MARK: - Spend & Extra Usage

/// Dollar spend against a cap. Only meaningful for accounts that have spend limits enabled
/// (most subscription plans report `enabled == false`).
nonisolated struct UsageSpend: Sendable, Equatable, Codable {
    let enabled: Bool
    let utilization: Double
    let usedDollars: Double
    let currency: String
}

/// Pay-as-you-go "extra usage" credits beyond the subscription allowance.
nonisolated struct ExtraUsage: Sendable, Equatable, Codable {
    let enabled: Bool
    let utilization: Double?
    let usedCredits: Double?
}

// MARK: - Claude Usage

/// Snapshot of subscription rate-limit utilization returned by
/// `GET https://api.anthropic.com/api/oauth/usage`.
nonisolated struct ClaudeUsage: Sendable, Equatable, Codable {
    let fiveHour: UsageWindow
    let sevenDay: UsageWindow
    /// Per-model weekly windows, present only on plans that scope them.
    let sevenDayOpus: UsageWindow?
    let sevenDaySonnet: UsageWindow?
    /// Dollar spend / extra credits, present only when the account enables them.
    let spend: UsageSpend?
    let extraUsage: ExtraUsage?

    /// Parses the raw JSON body of the usage endpoint. Returns `nil` when the body
    /// is malformed or is missing the required `five_hour` / `seven_day` windows.
    nonisolated static func parse(_ data: Data) -> ClaudeUsage? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let dto = try? decoder.decode(UsageResponseDTO.self, from: data),
              let fiveHour = window(from: dto.fiveHour),
              let sevenDay = window(from: dto.sevenDay)
        else { return nil }

        return ClaudeUsage(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            sevenDayOpus: window(from: dto.sevenDayOpus),
            sevenDaySonnet: window(from: dto.sevenDaySonnet),
            spend: spend(from: dto.spend),
            extraUsage: extraUsage(from: dto.extraUsage)
        )
    }

    private static func spend(from dto: UsageResponseDTO.Spend?) -> UsageSpend? {
        guard let dto else { return nil }
        let used = dto.used
        let dollars: Double = if let minor = used?.amountMinor {
            Double(minor) / pow(10, Double(used?.exponent ?? 2))
        } else {
            0
        }
        return UsageSpend(
            enabled: dto.enabled ?? false,
            utilization: dto.percent ?? 0,
            usedDollars: dollars,
            currency: used?.currency ?? "USD"
        )
    }

    private static func extraUsage(from dto: UsageResponseDTO.ExtraUsage?) -> ExtraUsage? {
        guard let dto else { return nil }
        return ExtraUsage(
            enabled: dto.isEnabled ?? false,
            utilization: dto.utilization,
            usedCredits: dto.usedCredits
        )
    }

    private static func window(from dto: UsageResponseDTO.Window?) -> UsageWindow? {
        guard let dto, let utilization = dto.utilization else { return nil }
        return UsageWindow(
            utilization: utilization,
            resetsAt: dto.resetsAt.flatMap(parseResetDate)
        )
    }

    /// Parses the ISO-8601 reset timestamps. The endpoint returns microsecond precision
    /// with an explicit offset (e.g. `2026-06-22T23:40:00.705258+00:00`), which
    /// `ISO8601DateFormatter` rejects, so fractional seconds are stripped first.
    nonisolated static func parseResetDate(_ string: String) -> Date? {
        let normalized = string.replacingOccurrences(
            of: #"\.\d+"#,
            with: "",
            options: .regularExpression
        )
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: normalized)
    }
}

// MARK: - Decoding DTO

/// Mirrors the subset of the usage endpoint payload we consume. Decoded with
/// `.convertFromSnakeCase`, so `five_hour` → `fiveHour`, `resets_at` → `resetsAt`, etc.
/// Unused fields (`limits`, `spend`, dollar amounts, …) are intentionally ignored.
nonisolated private struct UsageResponseDTO: Decodable {
    nonisolated struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?
    }

    nonisolated struct Money: Decodable {
        let amountMinor: Int?
        let currency: String?
        let exponent: Int?
    }

    nonisolated struct Spend: Decodable {
        let used: Money?
        let percent: Double?
        let enabled: Bool?
    }

    nonisolated struct ExtraUsage: Decodable {
        let isEnabled: Bool?
        let utilization: Double?
        let usedCredits: Double?
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let sevenDayOpus: Window?
    let sevenDaySonnet: Window?
    let spend: Spend?
    let extraUsage: ExtraUsage?
}
