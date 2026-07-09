import Foundation

/// How often Poirot silently re-fetches usage once opted in. `manual` disables the background
/// poll entirely — the user reloads on demand with the refresh button.
enum UsageRefreshInterval: Int, CaseIterable, Identifiable, Sendable {
    case manual = 0
    case oneMinute = 1
    case twoMinutes = 2
    case fiveMinutes = 5
    case tenMinutes = 10
    case thirtyMinutes = 30

    /// Cadence for a fresh install: frequent enough to feel live, gentle enough not to hammer.
    static let `default`: UsageRefreshInterval = .fiveMinutes

    var id: Int { rawValue }

    /// Polling interval in seconds, or `nil` for manual (no background poll).
    var seconds: TimeInterval? {
        self == .manual ? nil : TimeInterval(rawValue) * 60
    }

    /// Full label for pickers and menus.
    var label: String {
        switch self {
        case .manual: "Manual"
        case .oneMinute: "Every minute"
        case .twoMinutes: "Every 2 minutes"
        case .fiveMinutes: "Every 5 minutes"
        case .tenMinutes: "Every 10 minutes"
        case .thirtyMinutes: "Every 30 minutes"
        }
    }

    /// Compact label for tight spots like the menu bar ("Manual", "5m").
    var shortLabel: String {
        self == .manual ? "Manual" : "\(rawValue)m"
    }
}
