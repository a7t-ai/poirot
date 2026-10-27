@testable import Poirot
import Foundation
import Testing

@Suite("AppState Lazy Loading", .serialized)
struct AppStateLazyLoadingTests {
    // MARK: - Helpers

    /// AppState writes these settings to the test host's real defaults; restore them after a test.
    private func preservingDefaults(_ body: () throws -> Void) rethrows {
        let keys = ["loadBatchSize", "showAgentSessions"]
        let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value {
                    UserDefaults.standard.set(value, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
        try body()
    }

    /// A fresh state with a known batch size and no load running.
    private func makeState(batchSize: LoadBatchSize = .ten, availableProjects: Int = 0) -> AppState {
        let state = AppState()
        state.loadBatchSize = batchSize
        state.availableProjectCount = availableProjects
        state.isLoadingMoreProjects = false
        return state
    }

    /// Project folders, most recently active first: p0, p1, ...
    private func directories(_ count: Int) -> [URL] {
        (0 ..< count).map { URL(fileURLWithPath: "/projects/p\($0)") }
    }

    private func makeSession(id: String, isSidechain: Bool = false) -> Session {
        Session(
            id: id,
            projectPath: "/test/path",
            messages: [],
            startedAt: .now,
            model: nil,
            totalTokens: 0,
            isSidechain: isSidechain
        )
    }

    private func makeProject(id: String, sessions: [Session]? = nil, unloaded: Int = 0) -> Project {
        Project(
            id: id,
            name: id,
            path: "/\(id)",
            sessions: sessions ?? [makeSession(id: "\(id)-s0")],
            unloadedSessionCount: unloaded
        )
    }

    private func storeProjects(_ ids: Range<Int>, in state: AppState) {
        for index in ids {
            state.storeLoadedProject(makeProject(id: "p\(index)"), sessionLimit: state.sessionLimit(for: "p\(index)"))
        }
    }

    // MARK: - Batch Size

    @Test
    func batchSize_setsProjectTarget() {
        preservingDefaults {
            #expect(makeState(batchSize: .ten).projectLoadTarget == 10)
            #expect(makeState(batchSize: .all).projectLoadTarget == .max)
        }
    }

    @Test
    func batchSize_persistsAcrossLaunches() {
        preservingDefaults {
            _ = makeState(batchSize: .forty)
            #expect(AppState().loadBatchSize == .forty)
        }
    }

    @Test
    func changingBatchSize_startsOverWithOneBatch() {
        preservingDefaults {
            let state = makeState(batchSize: .ten, availableProjects: 50)
            state.loadMoreProjects()
            state.loadMoreSessions(for: "p0")

            state.loadBatchSize = .fifty

            #expect(state.projectLoadTarget == 50)
            #expect(state.sessionLimits.isEmpty)
            #expect(state.sessionLimit(for: "p0") == 50)
        }
    }

    // MARK: - More Projects

    @Test
    func hasMoreProjects_onlyWhenFoldersRemainBeyondTarget() {
        preservingDefaults {
            #expect(makeState(batchSize: .ten, availableProjects: 25).hasMoreProjects)
            #expect(!makeState(batchSize: .ten, availableProjects: 10).hasMoreProjects)
            #expect(!makeState(batchSize: .all, availableProjects: 500).hasMoreProjects)
        }
    }

    @Test
    func loadMoreProjects_growsTargetByOneBatchUntilEveryFolderFits() {
        preservingDefaults {
            let state = makeState(batchSize: .ten, availableProjects: 25)

            state.loadMoreProjects()
            #expect(state.projectLoadTarget == 20)
            state.loadMoreProjects()
            #expect(state.projectLoadTarget == 30)
            state.loadMoreProjects()
            #expect(state.projectLoadTarget == 30)
        }
    }

    @Test
    func loadMoreProjects_ignoredWhileALoadIsRunning() {
        preservingDefaults {
            let state = makeState(batchSize: .ten, availableProjects: 25)
            state.isLoadingMoreProjects = true

            state.loadMoreProjects()

            #expect(state.projectLoadTarget == 10)
        }
    }

    // MARK: - Directories To Load

    @Test
    func projectDirectoriesToLoad_firstPassTakesOneBatch() {
        preservingDefaults {
            let state = makeState(batchSize: .ten)
            let pending = state.projectDirectoriesToLoad(from: directories(25), isRefresh: true)
            #expect(pending == directories(10))
        }
    }

    @Test
    func projectDirectoriesToLoad_nextBatchSkipsLoadedFolders() {
        preservingDefaults {
            let state = makeState(batchSize: .ten, availableProjects: 25)
            storeProjects(0 ..< 10, in: state)

            state.loadMoreProjects()
            let pending = state.projectDirectoriesToLoad(from: directories(25), isRefresh: false)

            #expect(pending == Array(directories(20)[10...]))
        }
    }

    @Test
    func projectDirectoriesToLoad_refreshReparsesTheWholeWindow() {
        preservingDefaults {
            let state = makeState(batchSize: .ten, availableProjects: 25)
            storeProjects(0 ..< 10, in: state)

            let pending = state.projectDirectoriesToLoad(from: directories(25), isRefresh: true)

            #expect(pending == directories(10))
        }
    }

    @Test
    func projectDirectoriesToLoad_moreSessionsReloadsOnlyThatProject() {
        preservingDefaults {
            let state = makeState(batchSize: .ten, availableProjects: 25)
            storeProjects(0 ..< 10, in: state)

            state.loadMoreSessions(for: "p3")
            let pending = state.projectDirectoriesToLoad(from: directories(25), isRefresh: false)

            #expect(pending.map(\.lastPathComponent) == ["p3"])
        }
    }

    // MARK: - Session Limits

    @Test
    func sessionLimit_defaultsToBatchSizeAndGrowsPerProject() {
        preservingDefaults {
            let state = makeState(batchSize: .twenty)
            #expect(state.sessionLimit(for: "p0") == 20)

            state.loadMoreSessions(for: "p0")

            #expect(state.sessionLimit(for: "p0") == 40)
            #expect(state.sessionLimit(for: "p1") == 20)
        }
    }

    @Test
    func isLoadingSessions_trueUntilTheLargerLimitLands() {
        preservingDefaults {
            let state = makeState(batchSize: .twenty)
            state.storeLoadedProject(makeProject(id: "p0", unloaded: 30), sessionLimit: 20)
            #expect(!state.isLoadingSessions(for: "p0"))

            state.loadMoreSessions(for: "p0")
            #expect(state.isLoadingSessions(for: "p0"))

            state.storeLoadedProject(makeProject(id: "p0", unloaded: 10), sessionLimit: 40)
            #expect(!state.isLoadingSessions(for: "p0"))
        }
    }

    // MARK: - Store And Trim

    @Test
    func storeLoadedProject_replacesTheExistingCopy() {
        preservingDefaults {
            let state = makeState()
            state.storeLoadedProject(makeProject(id: "p0"), sessionLimit: 10)

            let twoSessions = [makeSession(id: "a"), makeSession(id: "b")]
            state.storeLoadedProject(makeProject(id: "p0", sessions: twoSessions), sessionLimit: 10)

            #expect(state.projects.count == 1)
            #expect(state.projects.first?.sessions.count == 2)
        }
    }

    @Test
    func trimLoadedProjects_dropsFoldersOutsideTheWindow() {
        preservingDefaults {
            let state = makeState(batchSize: .ten, availableProjects: 25)
            storeProjects(0 ..< 12, in: state)

            state.trimLoadedProjects(to: directories(25))

            #expect(state.projects.map(\.id) == (0 ..< 10).map { "p\($0)" })

            // Dropped folders load again once the window grows back over them
            state.loadMoreProjects()
            let pending = state.projectDirectoriesToLoad(from: directories(25), isRefresh: false)
            #expect(pending.first?.lastPathComponent == "p10")
        }
    }

    @Test
    func trimLoadedProjects_dropsDeletedFolders() {
        preservingDefaults {
            let state = makeState(batchSize: .ten, availableProjects: 3)
            storeProjects(0 ..< 3, in: state)

            state.trimLoadedProjects(to: directories(3).filter { $0.lastPathComponent != "p1" })

            #expect(state.projects.map(\.id) == ["p0", "p2"])
        }
    }

    // MARK: - Filters Keep The Unloaded Count

    @Test
    func filteredSortedProjects_hidingAgentSessionsKeepsUnloadedCount() {
        preservingDefaults {
            let state = makeState()
            state.showAgentSessions = false
            let sessions = [makeSession(id: "main"), makeSession(id: "agent", isSidechain: true)]
            state.projects = [makeProject(id: "p0", sessions: sessions, unloaded: 7)]

            let visible = state.filteredSortedProjects

            #expect(visible.first?.sessions.map(\.id) == ["main"])
            #expect(visible.first?.unloadedSessionCount == 7)
        }
    }

    @Test
    func filteredSortedProjects_sessionCountSortIncludesUnloadedSessions() {
        preservingDefaults {
            let state = makeState()
            state.projectSortOption = .sessionCount
            let three = (0 ..< 3).map { makeSession(id: "s\($0)") }
            state.projects = [
                makeProject(id: "three-loaded", sessions: three),
                makeProject(id: "one-loaded-ten-more", unloaded: 10),
            ]

            #expect(state.filteredSortedProjects.map(\.id) == ["one-loaded-ten-more", "three-loaded"])
        }
    }

    // MARK: - Deletes

    @Test
    func deleteSession_lastLoadedSessionWithOlderOnDisk_requestsReload() {
        preservingDefaults {
            let state = makeState()
            let session = makeSession(id: "only")
            state.projects = [makeProject(id: "p0", sessions: [session], unloaded: 5)]
            let refreshID = state.refreshID

            state.deleteSession(session)

            #expect(state.projects.isEmpty)
            #expect(state.refreshID != refreshID)
        }
    }

    @Test
    func deleteSession_lastSessionWithNothingOlder_doesNotReload() {
        preservingDefaults {
            let state = makeState()
            let session = makeSession(id: "only")
            state.projects = [makeProject(id: "p0", sessions: [session])]
            let refreshID = state.refreshID

            state.deleteSession(session)

            #expect(state.refreshID == refreshID)
        }
    }

    @Test
    func deleteProject_forgetsItsLoadingState() {
        preservingDefaults {
            let state = makeState(batchSize: .ten, availableProjects: 5)
            // An ID with no folder under ~/.claude/projects, so the delete touches nothing on disk
            let project = makeProject(id: "poirot-test-\(UUID().uuidString)")
            state.storeLoadedProject(project, sessionLimit: 10)
            state.loadMoreSessions(for: project.id)

            state.deleteProject(project)

            #expect(state.availableProjectCount == 4)
            #expect(state.sessionLimits[project.id] == nil)
            #expect(!state.isLoadingSessions(for: project.id))
        }
    }
}
