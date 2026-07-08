import Foundation
import Observation

/// Shared, observable source of truth for Claude subscription usage. A single instance is
/// created in `PoirotApp` and injected into both the analytics dashboard and the menu bar.
///
/// Usage is **opt-in** and the Keychain is **only ever read on an explicit user action**
/// (Enable / Load / Refresh) — never on appear, tab-switch, or launch. The last good snapshot
/// is persisted (just utilization + reset times, all local), so on relaunch the gauges show
/// from cache without touching the Keychain. Any access failure drops back to the idle "Load"
/// state.
///
/// Once opted in **and** already holding loaded data, a background timer silently re-fetches on
/// `autoRefreshInterval` so the gauges and reset countdowns stay current (a window that already
/// reset stops lingering). The first tick fires one interval *after* the store starts — never
/// synchronously on launch/appear — and a tick only ever fires while the state is `.loaded`, so
/// the "no Keychain read out of nowhere" contract holds: the first read is always explicit.
@MainActor
@Observable
final class UsageStore {
    enum State: Equatable {
        /// Nothing loaded this session. `note` carries a one-line reason after a failed attempt.
        case idle(note: String?)
        case loading
        case loaded(ClaudeUsage)
    }

    static let enabledKey = "usageLimitsEnabled"
    private static let snapshotKey = "usageSnapshot"
    private static let snapshotDateKey = "usageSnapshotDate"

    private(set) var state: State = .idle(note: nil)
    private(set) var lastUpdated: Date?
    /// Whether the user has opted in. Off by default — nothing is read or fetched until on.
    private(set) var isEnabled: Bool

    private let loader: any UsageLoading
    private let defaults: UserDefaults
    /// Minimum spacing between non-forced refreshes, so repeated explicit taps don't hammer.
    private let throttle: TimeInterval
    /// How often to silently re-fetch once opted in and loaded. `nil` disables the timer
    /// entirely (previews and unit tests).
    private let autoRefreshInterval: TimeInterval?
    private var autoRefreshTask: Task<Void, Never>?

    init(
        loader: any UsageLoading = ClaudeUsageLoader(),
        throttle: TimeInterval = 30,
        autoRefreshInterval: TimeInterval? = 60,
        defaults: UserDefaults = .standard
    ) {
        self.loader = loader
        self.throttle = throttle
        self.autoRefreshInterval = autoRefreshInterval
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        // Restore the last snapshot so a relaunch shows gauges WITHOUT reading the Keychain.
        if isEnabled, let snapshot = Self.loadSnapshot(from: defaults) {
            state = .loaded(snapshot.usage)
            lastUpdated = snapshot.date
        }
        // Begin polling if already opted in. The first tick is a full interval away and only
        // fires while `.loaded`, so launch itself never reads the Keychain.
        if isEnabled { startAutoRefresh() }
    }

    /// A store pinned to a fixed state for previews and snapshot tests. Never fetches.
    static func preview(_ state: State, enabled: Bool = true) -> UsageStore {
        let store = UsageStore(
            throttle: .greatestFiniteMagnitude,
            autoRefreshInterval: nil,
            defaults: UserDefaults(suiteName: "fyi.poirot.preview") ?? .standard
        )
        store.isEnabled = enabled
        store.state = state
        store.lastUpdated = Date()
        return store
    }

    /// The most recently loaded usage, if any (survives across in-flight refreshes).
    var usage: ClaudeUsage? {
        if case let .loaded(usage) = state { return usage }
        return nil
    }

    /// Opt in and immediately fetch (the explicit first read), then keep it fresh in the background.
    func enable() async {
        setEnabled(true)
        await refresh(force: true)
        startAutoRefresh()
    }

    /// Opt back out: stop fetching and forget the cached snapshot.
    func disable() {
        setEnabled(false)
        stopAutoRefresh()
        clearSnapshot()
        lastUpdated = nil
        state = .idle(note: nil)
    }

    // MARK: - Background auto-refresh

    /// Start silently polling for fresh usage. Idempotent, and a no-op when disabled or when the
    /// timer is turned off (`autoRefreshInterval == nil`). Ticks only re-fetch while `.loaded`, so
    /// the timer never triggers a Keychain read out of an idle state.
    func startAutoRefresh() {
        guard isEnabled, autoRefreshTask == nil,
              let interval = autoRefreshInterval, interval > 0
        else { return }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard let self, !Task.isCancelled else { return }
                if case .loaded = self.state {
                    await self.refresh()
                }
            }
        }
    }

    /// Stop background polling. Called on opt-out; explicit loads restart it.
    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func setEnabled(_ value: Bool) {
        guard value != isEnabled else { return }
        isEnabled = value
        defaults.set(value, forKey: Self.enabledKey)
    }

    /// Reads the Keychain and fetches usage. Called from explicit user actions (Enable / Load /
    /// Refresh) and from the background timer once already `.loaded` — never on appear/launch — so
    /// navigating never prompts. Skips when a fetch happened within `throttle` seconds unless `force`.
    func refresh(force: Bool = false) async {
        guard isEnabled else { return }
        if case .loading = state { return }
        if !force, let lastUpdated, Date().timeIntervalSince(lastUpdated) < throttle {
            return
        }

        let hadData = usage != nil
        if !hadData { state = .loading }

        switch await loader.loadUsage() {
        case let .success(usage):
            let now = Date()
            state = .loaded(usage)
            lastUpdated = now
            saveSnapshot(usage, date: now)
            // Any successful load (Load button, Try again, toolbar refresh) keeps the poll alive.
            startAutoRefresh()

        case .unauthenticated:
            // Access problem → forget the snapshot and return to the idle Load state (rule 3).
            clearSnapshot()
            lastUpdated = nil
            state = .idle(note: "Couldn't read your Claude Code token — allow Keychain access, then load again.")

        case .failure:
            // Transient (e.g. network): keep any cached gauges; otherwise offer Load.
            if !hadData {
                state = .idle(note: "Couldn't reach Anthropic — check your connection, then load again.")
            }
        }
    }

    // MARK: - Snapshot persistence

    private struct Snapshot {
        let usage: ClaudeUsage
        let date: Date
    }

    private func saveSnapshot(_ usage: ClaudeUsage, date: Date) {
        guard let data = try? JSONEncoder().encode(usage) else { return }
        defaults.set(data, forKey: Self.snapshotKey)
        defaults.set(date, forKey: Self.snapshotDateKey)
    }

    private func clearSnapshot() {
        defaults.removeObject(forKey: Self.snapshotKey)
        defaults.removeObject(forKey: Self.snapshotDateKey)
    }

    private static func loadSnapshot(from defaults: UserDefaults) -> Snapshot? {
        guard let data = defaults.data(forKey: snapshotKey),
              let usage = try? JSONDecoder().decode(ClaudeUsage.self, from: data)
        else { return nil }
        let date = defaults.object(forKey: snapshotDateKey) as? Date ?? Date()
        return Snapshot(usage: usage, date: date)
    }
}
