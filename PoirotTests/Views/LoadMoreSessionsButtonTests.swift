@testable import Poirot
import Testing

@Suite("LoadMoreSessionsButton")
struct LoadMoreSessionsButtonTests {
    @Test
    func title_fewerThanOneBatchLeft_showsAllOfThem() {
        #expect(LoadMoreSessionsButton.title(remaining: 14, batch: 20) == "Show 14 older sessions")
    }

    @Test
    func title_exactlyOneBatchLeft_showsAllOfThem() {
        #expect(LoadMoreSessionsButton.title(remaining: 20, batch: 20) == "Show 20 older sessions")
    }

    @Test
    func title_oneLeft_isSingular() {
        #expect(LoadMoreSessionsButton.title(remaining: 1, batch: 20) == "Show 1 older session")
    }

    @Test
    func title_moreThanOneBatchLeft_showsBatchOfTotal() {
        #expect(LoadMoreSessionsButton.title(remaining: 54, batch: 20) == "Show 20 of 54 older sessions")
    }
}
