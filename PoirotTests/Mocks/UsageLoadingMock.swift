@testable import Poirot

final class UsageLoadingMock: UsageLoading, @unchecked Sendable {
    // MARK: - loadUsage

    var loadUsageCallsCount = 0
    var loadUsageCalled: Bool { loadUsageCallsCount > 0 }
    var loadUsageReturnValue: UsageResult = .failure
    var loadUsageClosure: (() -> UsageResult)?

    nonisolated func loadUsage() async -> UsageResult {
        loadUsageCallsCount += 1
        if let loadUsageClosure { return loadUsageClosure() }
        return loadUsageReturnValue
    }
}
