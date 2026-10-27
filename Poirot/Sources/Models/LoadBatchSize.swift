import Foundation

/// How many project folders the session list loads at a time, and how many sessions each
/// project starts with. `all` turns batching off and loads everything at launch.
nonisolated enum LoadBatchSize: Int, CaseIterable, Identifiable {
    case ten = 10
    case twenty = 20
    case forty = 40
    case fifty = 50
    case hundred = 100
    case all = 0

    static let `default`: LoadBatchSize = .ten

    var id: Int { rawValue }

    /// Items per batch; `Int.max` for `all`.
    var limit: Int {
        self == .all ? .max : rawValue
    }

    var label: String {
        switch self {
        case .all: String(localized: "All at once")
        default: String(localized: "\(rawValue) at a time")
        }
    }
}
