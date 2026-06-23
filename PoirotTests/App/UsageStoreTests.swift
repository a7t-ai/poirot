@testable import Poirot
import Foundation
import Testing

@MainActor
@Suite("UsageStore")
struct UsageStoreTests {
    private static let sampleUsage = ClaudeUsage(
        fiveHour: UsageWindow(utilization: 20, resetsAt: nil),
        sevenDay: UsageWindow(utilization: 30, resetsAt: nil),
        sevenDayOpus: nil,
        sevenDaySonnet: nil,
        spend: nil,
        extraUsage: nil
    )

    /// A throwaway defaults suite so opt-in/snapshot persistence never touches `.standard` or
    /// leaks between tests.
    private static func freshDefaults(enabled: Bool) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "UsageStoreTests-\(UUID().uuidString)")!
        defaults.set(enabled, forKey: UsageStore.enabledKey)
        return defaults
    }

    private static func isIdle(_ state: UsageStore.State) -> Bool {
        if case .idle = state { return true }
        return false
    }

    // MARK: - Opt-in gating

    @Test
    func refresh_whenDisabled_doesNotFetch() async {
        let mock = UsageLoadingMock()
        mock.loadUsageReturnValue = .success(Self.sampleUsage)
        let store = UsageStore(loader: mock, throttle: 0, defaults: Self.freshDefaults(enabled: false))

        await store.refresh(force: true)

        #expect(!store.isEnabled)
        #expect(mock.loadUsageCallsCount == 0)
        #expect(Self.isIdle(store.state))
    }

    @Test
    func enable_fetchesAndPersists() async {
        let mock = UsageLoadingMock()
        mock.loadUsageReturnValue = .success(Self.sampleUsage)
        let defaults = Self.freshDefaults(enabled: false)
        let store = UsageStore(loader: mock, throttle: 0, defaults: defaults)

        await store.enable()

        #expect(store.isEnabled)
        #expect(mock.loadUsageCallsCount == 1)
        #expect(store.state == .loaded(Self.sampleUsage))
        #expect(defaults.bool(forKey: UsageStore.enabledKey))
    }

    // MARK: - Persistence (rule 2: no Keychain read on restart)

    @Test
    func restoresSnapshotOnInit_withoutFetching() async {
        let defaults = Self.freshDefaults(enabled: true)
        let writer = UsageLoadingMock()
        writer.loadUsageReturnValue = .success(Self.sampleUsage)
        await UsageStore(loader: writer, throttle: 0, defaults: defaults).refresh()

        // A brand-new store (simulating relaunch) restores the snapshot and never calls the loader.
        let reader = UsageLoadingMock()
        let restored = UsageStore(loader: reader, throttle: 0, defaults: defaults)

        #expect(restored.usage == Self.sampleUsage)
        #expect(reader.loadUsageCallsCount == 0)
    }

    @Test
    func disabledStore_doesNotRestoreSnapshot() async {
        let defaults = Self.freshDefaults(enabled: true)
        let writer = UsageLoadingMock()
        writer.loadUsageReturnValue = .success(Self.sampleUsage)
        await UsageStore(loader: writer, throttle: 0, defaults: defaults).refresh()

        // Opt back out → snapshot is forgotten and not restored.
        defaults.set(false, forKey: UsageStore.enabledKey)
        let restored = UsageStore(loader: UsageLoadingMock(), throttle: 0, defaults: defaults)

        #expect(restored.usage == nil)
    }

    // MARK: - Fetch outcomes

    @Test
    func refresh_success_setsLoaded() async {
        let mock = UsageLoadingMock()
        mock.loadUsageReturnValue = .success(Self.sampleUsage)
        let store = UsageStore(loader: mock, throttle: 0, defaults: Self.freshDefaults(enabled: true))

        await store.refresh()

        #expect(store.state == .loaded(Self.sampleUsage))
        #expect(store.usage == Self.sampleUsage)
    }

    @Test
    func refresh_unauthenticated_clearsSnapshotAndGoesIdle() async {
        let defaults = Self.freshDefaults(enabled: true)
        let mock = UsageLoadingMock()
        mock.loadUsageReturnValue = .success(Self.sampleUsage)
        let store = UsageStore(loader: mock, throttle: 0, defaults: defaults)
        await store.refresh()

        mock.loadUsageReturnValue = .unauthenticated
        await store.refresh(force: true)

        guard case let .idle(note) = store.state else {
            Issue.record("expected idle after unauthenticated")
            return
        }
        #expect(note != nil)
        // Snapshot was cleared, so a relaunch shows the Load state rather than stale gauges.
        let restored = UsageStore(loader: UsageLoadingMock(), throttle: 0, defaults: defaults)
        #expect(restored.usage == nil)
    }

    @Test
    func refresh_failureFromIdle_goesIdleWithNote() async {
        let mock = UsageLoadingMock()
        mock.loadUsageReturnValue = .failure
        let store = UsageStore(loader: mock, throttle: 0, defaults: Self.freshDefaults(enabled: true))

        await store.refresh()

        guard case let .idle(note) = store.state else {
            Issue.record("expected idle after failure")
            return
        }
        #expect(note != nil)
    }

    @Test
    func refresh_networkFailureAfterLoaded_keepsStaleData() async {
        let mock = UsageLoadingMock()
        mock.loadUsageReturnValue = .success(Self.sampleUsage)
        let store = UsageStore(loader: mock, throttle: 0, defaults: Self.freshDefaults(enabled: true))
        await store.refresh()

        mock.loadUsageReturnValue = .failure
        await store.refresh(force: true)

        // Transient network failure keeps the cached gauges rather than dropping to Load.
        #expect(store.usage == Self.sampleUsage)
    }

    @Test
    func disable_clearsStateAndStops() async {
        let mock = UsageLoadingMock()
        mock.loadUsageReturnValue = .success(Self.sampleUsage)
        let store = UsageStore(loader: mock, throttle: 0, defaults: Self.freshDefaults(enabled: true))
        await store.refresh()

        store.disable()

        #expect(!store.isEnabled)
        #expect(Self.isIdle(store.state))
    }

    // MARK: - Throttle

    @Test
    func refresh_withinThrottleWindow_skipsSecondFetch() async {
        let mock = UsageLoadingMock()
        mock.loadUsageReturnValue = .success(Self.sampleUsage)
        let store = UsageStore(loader: mock, throttle: 1000, defaults: Self.freshDefaults(enabled: true))

        await store.refresh()
        await store.refresh()

        #expect(mock.loadUsageCallsCount == 1)
    }

    @Test
    func refresh_force_bypassesThrottle() async {
        let mock = UsageLoadingMock()
        mock.loadUsageReturnValue = .success(Self.sampleUsage)
        let store = UsageStore(loader: mock, throttle: 1000, defaults: Self.freshDefaults(enabled: true))

        await store.refresh()
        await store.refresh(force: true)

        #expect(mock.loadUsageCallsCount == 2)
    }

    @Test
    func preview_pinsStateWithoutFetching() async {
        let store = UsageStore.preview(.loaded(Self.sampleUsage))

        await store.refresh()

        #expect(store.isEnabled)
        #expect(store.usage == Self.sampleUsage)
    }
}
