import Foundation

// MARK: - Usage Severity

/// Coarse severity buckets derived from a gauge's utilization percentage.
/// Pure value type — the color mapping lives in the view layer (see `UsageGaugeRing`).
nonisolated enum UsageSeverity: Sendable, Equatable {
    case normal
    case warning
    case critical

    /// Utilization (0–100) at or above which a gauge is considered "warning".
    static let warningThreshold: Double = 80
    /// Utilization (0–100) at or above which a gauge is considered "critical".
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

/// A utilization gauge value used by the conversation context card's ring.
///
/// `utilization` is expressed as a **percentage in 0...100** (e.g. `20.0` means 20% used),
/// not a 0...1 fraction.
nonisolated struct UsageWindow: Sendable, Equatable, Codable {
    let utilization: Double
    let resetsAt: Date?

    /// Utilization clamped to the 0...1 range for progress views.
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
