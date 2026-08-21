@testable import Poirot
import SnapshotTesting
import SwiftUI
import Testing

// MARK: - Standard Sizes

enum ScreenshotSize {
    static let fullApp = CGSize(width: 1280, height: 820)
    static let mainContent = CGSize(width: 1020, height: 820)
    static let sidebar = CGSize(width: 260, height: 820)
    static let component = CGSize(width: 600, height: 400)
    static let componentWide = CGSize(width: 800, height: 400)
    static let componentCollapsed = CGSize(width: 600, height: 80)
    static let componentHeader = CGSize(width: 800, height: 120)
    static let badge = CGSize(width: 200, height: 40)
    static let toast = CGSize(width: 500, height: 80)
    static let settings = CGSize(width: 560, height: 360)
    static let onboarding = CGSize(width: 520, height: 480)
    static let help = CGSize(width: 540, height: 620)
    static let diff = CGSize(width: 600, height: 300)
    static let emptyState = CGSize(width: 600, height: 300)
}

// MARK: - Snapshot Helpers

/// Synchronous snapshot — use for views that don't rely on .task / .onAppear async loading.
func snapshotView<V: View>(
    _ view: V,
    size: CGSize,
    named name: String,
    record isRecording: Bool = false,
    colorScheme: ColorScheme = .dark
) {
    let hostingView = NSHostingController(
        rootView: view
            .preferredColorScheme(colorScheme)
            .frame(width: size.width, height: size.height)
    )
    hostingView.view.frame = CGRect(origin: .zero, size: size)

    assertSnapshot(
        of: hostingView,
        as: .image(precision: 0.99, size: size),
        named: name,
        record: isRecording
    )
}

/// Async snapshot — attaches the view to a window and uses Task.sleep to yield the MainActor,
/// allowing SwiftUI .task / .onAppear async modifiers to execute before capturing.
/// - `scrollFraction`: scroll the first NSScrollView to this fraction (0 = top, 1 = bottom).
func snapshotView<V: View>(
    _ view: V,
    size: CGSize,
    named name: String,
    record isRecording: Bool = false,
    delay: TimeInterval,
    colorScheme: ColorScheme = .dark,
    scrollFraction: CGFloat? = nil,
    precision: Float = 0.99
) async throws {
    let hostingView = NSHostingController(
        rootView: view
            .preferredColorScheme(colorScheme)
            .environment(\.disableAnimations, true)
            .frame(width: size.width, height: size.height)
    )
    hostingView.view.frame = CGRect(origin: .zero, size: size)

    let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: size),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    window.contentViewController = hostingView
    window.makeKeyAndOrderFront(nil)

    try await Task.sleep(for: .seconds(delay))

    if let fraction = scrollFraction,
       let scrollView = findScrollView(in: hostingView.view) {
        let docHeight = scrollView.documentView?.frame.height ?? 0
        let clipHeight = scrollView.contentView.bounds.height
        let maxY = max(0, docHeight - clipHeight)
        let targetY = maxY * fraction
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        // Allow layout pass after scroll
        try await Task.sleep(for: .milliseconds(200))
    }

    assertSnapshot(
        of: hostingView,
        as: .image(precision: precision, size: size),
        named: name,
        record: isRecording
    )
}

/// Finds the most scrollable NSScrollView (largest scrollable range) in a view hierarchy.
/// This avoids picking the sidebar's scroll view when the main content is the intended target.
private func findScrollView(in view: NSView) -> NSScrollView? {
    var all: [NSScrollView] = []
    collectScrollViews(in: view, into: &all)
    // Pick the scroll view with the most scrollable content
    return all.max { a, b in
        let aRange = (a.documentView?.frame.height ?? 0) - a.contentView.bounds.height
        let bRange = (b.documentView?.frame.height ?? 0) - b.contentView.bounds.height
        return aRange < bRange
    }
}

private func collectScrollViews(in view: NSView, into result: inout [NSScrollView]) {
    if let sv = view as? NSScrollView { result.append(sv) }
    for subview in view.subviews { collectScrollViews(in: subview, into: &result) }
}

// MARK: - App State Factory

func makeAppState(
    projects: [Project] = ScreenshotData.projects,
    selectedSession: Session? = nil,
    selectedNav: NavigationItem = .sessions,
    isLoadingProjects: Bool = false,
    isLoadingMoreProjects: Bool = false,
    isSearchPresented: Bool = false,
    selectedProject: String? = nil,
    isSessionSearchActive: Bool = false,
    sessionSearchQuery: String = "",
    isToolFilterActive: Bool = false,
    activeToolFilters: Set<String> = [],
    toastQueue: [Toast] = [],
    configProjectPath: String? = nil
) -> AppState {
    let state = AppState()
    state.projects = projects
    state.selectedSession = selectedSession
    state.selectedNav = selectedNav
    state.isLoadingProjects = isLoadingProjects
    state.isLoadingMoreProjects = isLoadingMoreProjects
    state.isSearchPresented = isSearchPresented
    state.selectedProject = selectedProject
    state.isSessionSearchActive = isSessionSearchActive
    state.sessionSearchQuery = sessionSearchQuery
    state.isToolFilterActive = isToolFilterActive
    state.activeToolFilters = activeToolFilters
    state.toastQueue = toastQueue
    state.configProjectPath = configProjectPath
    return state
}

// MARK: - Environment Wrapper

func withEnvironment<V: View>(
    _ view: V,
    state: AppState? = nil,
    provider: any ProviderDescribing = ClaudeCodeProvider(),
    historyLoader: (any HistoryLoading)? = nil,
    usageStore: UsageStore = .preview(.idle(note: nil)),
    memorySources: MemorySourcesStore = .previewEmpty()
) -> some View {
    let appState = state ?? makeAppState()
    let result = view
        .environment(appState)
        .environment(\.provider, provider)
        .environment(usageStore)
        .environment(memorySources)
    if let historyLoader {
        return AnyView(result.environment(\.historyLoader, historyLoader))
    }
    return AnyView(result)
}

// MARK: - Composite App View (Sidebar + Detail)

// NavigationSplitView doesn't render its sidebar in NSHostingController snapshots.
// This helper manually composes sidebar + detail side-by-side for full-app screenshots.

func compositeAppView<Detail: View>(
    state: AppState? = nil,
    provider: any ProviderDescribing = ClaudeCodeProvider(),
    historyLoader: (any HistoryLoading)? = nil,
    usageStore: UsageStore = .preview(.idle(note: nil)),
    memorySources: MemorySourcesStore = .previewEmpty(),
    @ViewBuilder detail: () -> Detail
) -> some View {
    let appState = state ?? makeAppState()
    let view = HStack(spacing: 0) {
        SidebarView()
            .frame(width: 260)
            .background(PoirotTheme.Colors.bgSidebar)
        Divider()
        detail()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .environment(appState)
    .environment(\.provider, provider)
    .environment(usageStore)
    .environment(memorySources)

    if let historyLoader {
        return AnyView(view.environment(\.historyLoader, historyLoader))
    }
    return AnyView(view)
}
