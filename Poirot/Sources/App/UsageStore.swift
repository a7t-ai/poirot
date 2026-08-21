import Foundation
import Observation

/// Shared, observable source of truth for Claude subscription usage. A single instance is
/// created in `PoirotApp` and injected into both the analytics dashboard and the menu bar.
///
/// Usage is **opt-in** and requests use a token the user generates with `claude setup-token`
/// and pastes into Poirot (stored in Poirot's own Keychain item — see `PoirotTokenStore`).
/// Fetches happen only on an explicit user action (Enable / Load / Refresh) or the background
/// poll once `.loaded` — never on appear, tab-switch, or launch. The last good snapshot is
/// persisted (just utilization + reset times, all local), so on relaunch the gauges show from
/// cache. Any access failure drops back to the idle state.
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
    static let intervalKey = "usageRefreshIntervalMinutes"
    private static let snapshotKey = "usageSnapshot"
    private static let snapshotDateKey = "usageSnapshotDate"

    private(set) var state: State = .idle(note: nil)
    private(set) var lastUpdated: Date?
    /// Whether the user has opted in. Off by default — nothing is read or fetched until on.
    private(set) var isEnabled: Bool
    /// Whether a usage token (from `claude setup-token`) is currently stored. Drives the
    /// dashboard's "add your token" prompt vs. the normal load/refresh affordance.
    private(set) var hasToken: Bool
    /// User-chosen background cadence. `.manual` means the poll is off and the user reloads
    /// on demand. Persisted; change it through `setRefreshInterval(_:)`.
    private(set) var refreshInterval: UsageRefreshInterval

    private let loader: any UsageLoading
    private let tokenStore: any OAuthTokenStoring
    private let defaults: UserDefaults
    /// Minimum spacing between non-forced refreshes, so repeated explicit taps don't hammer.
    private let throttle: TimeInterval
    /// Test hook: when set, forces the poll interval for non-manual cadences (so timer behavior
    /// is testable in well under a minute). `nil` in production, where `refreshInterval` rules.
    private let autoRefreshOverride: TimeInterval?
    /// Master switch for the background poll — off in previews and snapshot tests.
    private let autoRefreshEnabled: Bool
    private var autoRefreshTask: Task<Void, Never>?
    /// When set, no fetch happens until this instant — a server-imposed backoff after a 429
    /// (honoring `Retry-After`). Public so the dashboard can show a "retrying in Xm" countdown.
    /// Even an explicit refresh is suppressed while this is in the future: a request inside the
    /// window just earns another 429 and can extend Anthropic's lockout.
    private(set) var rateLimitedUntil: Date?
    /// Fallback backoff when the 429 response carries no `Retry-After`.
    private static let defaultRateLimitBackoff: TimeInterval = 300

    init(
        loader: any UsageLoading = ClaudeUsageLoader(),
        tokenStore: any OAuthTokenStoring = PoirotTokenStore(),
        throttle: TimeInterval = 30,
        autoRefreshOverride: TimeInterval? = nil,
        autoRefreshEnabled: Bool = true,
        defaults: UserDefaults = .standard
    ) {
        self.loader = loader
        self.tokenStore = tokenStore
        self.throttle = throttle
        self.autoRefreshOverride = autoRefreshOverride
        self.autoRefreshEnabled = autoRefreshEnabled
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        self.hasToken = tokenStore.read() != nil
        let storedMinutes = defaults.object(forKey: Self.intervalKey) as? Int
        self.refreshInterval = storedMinutes.flatMap(UsageRefreshInterval.init(rawValue:)) ?? .default
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
            autoRefreshEnabled: false,
            defaults: UserDefaults(suiteName: "fyi.poirot.preview") ?? .standard
        )
        store.isEnabled = enabled
        store.state = state
        store.lastUpdated = Date()
        return store
    }

    /// Effective poll interval in seconds, or `nil` when polling is off (disabled master switch
    /// or `.manual`). The test override only speeds up non-manual cadences.
    private var autoRefreshSeconds: TimeInterval? {
        guard autoRefreshEnabled, refreshInterval != .manual else { return nil }
        return autoRefreshOverride ?? refreshInterval.seconds
    }

    /// The most recently loaded usage, if any (survives across in-flight refreshes).
    var usage: ClaudeUsage? {
        if case let .loaded(usage) = state { return usage }
        return nil
    }

    /// When the background poll will next fetch, for the dashboard's "next in Xm" hint. `nil`
    /// when nothing is loaded yet, or when auto-refresh is off (`.manual`).
    var nextRefreshAt: Date? {
        guard case .loaded = state, refreshInterval != .manual,
              let lastUpdated, let seconds = refreshInterval.seconds
        else { return nil }
        return lastUpdated.addingTimeInterval(seconds)
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
        rateLimitedUntil = nil
        state = .idle(note: nil)
    }

    // MARK: - Token

    /// Save the OAuth token (from `claude setup-token`) into Poirot's own Keychain item and, if
    /// usage is already enabled, load immediately with it. Blank input is ignored.
    func saveToken(_ token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tokenStore.save(trimmed)
        hasToken = true
        if isEnabled { await refresh(force: true) }
    }

    /// Forget the stored token and drop back to the idle state so the dashboard prompts for a
    /// new one. Leaves the opt-in flag untouched.
    func clearToken() {
        tokenStore.delete()
        hasToken = false
        rateLimitedUntil = nil
        if isEnabled {
            clearSnapshot()
            lastUpdated = nil
            state = .idle(note: nil)
        }
    }

    // MARK: - Background auto-refresh

    /// Change the background cadence (or turn it off with `.manual`). Persists the choice and
    /// reconfigures the running poll so it takes effect immediately.
    func setRefreshInterval(_ interval: UsageRefreshInterval) {
        guard interval != refreshInterval else { return }
        refreshInterval = interval
        defaults.set(interval.rawValue, forKey: Self.intervalKey)
        stopAutoRefresh()
        startAutoRefresh() // no-op for `.manual`, otherwise restarts at the new cadence
    }

    /// Start silently polling for fresh usage. Idempotent, and a no-op when disabled, in manual
    /// mode, or with polling turned off. Ticks only re-fetch while `.loaded`, so the timer never
    /// triggers a Keychain read out of an idle state.
    func startAutoRefresh() {
        guard isEnabled, autoRefreshTask == nil,
              let interval = autoRefreshSeconds, interval > 0
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
        // The usage endpoint rate-limits how often it can be queried, and punishes bursts with a
        // long lockout. After a 429 we hold off until the server's Retry-After elapses — for
        // explicit taps too, since a request inside the window only earns another 429.
        if let rateLimitedUntil, Date() < rateLimitedUntil {
            return
        }

        let hadData = usage != nil
        if !hadData { state = .loading }

        switch await loader.loadUsage() {
        case let .success(usage):
            let now = Date()
            rateLimitedUntil = nil
            state = .loaded(usage)
            lastUpdated = now
            saveSnapshot(usage, date: now)
            // Any successful load (Load button, Try again, toolbar refresh) keeps the poll alive.
            startAutoRefresh()

        case .unauthenticated:
            // No usable token → forget the snapshot and return to idle. The note distinguishes
            // "you haven't added one yet" from "the one you added was rejected/expired".
            clearSnapshot()
            lastUpdated = nil
            state = .idle(note: hasToken
                ? "Your usage token was rejected — run `claude setup-token` again and update it in Settings › Usage."
                : "Add your usage token in Settings › Usage to see your limits.")

        case let .rateLimited(retryAfter):
            // Back off before the next poll; keep any cached gauges rather than dropping them.
            rateLimitedUntil = Date().addingTimeInterval(retryAfter ?? Self.defaultRateLimitBackoff)
            if !hadData {
                state = .idle(note: "Anthropic is limiting usage checks right now — try again in a few minutes.")
            }

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
