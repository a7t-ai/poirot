@testable import Poirot
import Testing

@Suite("LoadBatchSize")
struct LoadBatchSizeTests {
    // MARK: - Cases

    @Test
    func allCases_matchSettingsChoicesInOrder() {
        #expect(LoadBatchSize.allCases.map(\.limit) == [10, 20, 40, 50, 100, .max])
    }

    @Test
    func default_isTen() {
        #expect(LoadBatchSize.default == .ten)
    }

    @Test
    func all_hasNoLimit() {
        #expect(LoadBatchSize.all.limit == .max)
    }

    // MARK: - Labels

    @Test
    func labels_matchExpected() {
        #expect(LoadBatchSize.ten.label == "10 at a time")
        #expect(LoadBatchSize.hundred.label == "100 at a time")
        #expect(LoadBatchSize.all.label == "All at once")
    }
}
