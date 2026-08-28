import Foundation
import Observation

@Observable
final class MenuBarState {
    var recentSessions: [(project: Project, session: Session)] = []
    var searchQuery: String = ""
    var stats: StatsCache?

    func loadStats() async {
        let loaded = await Task.detached {
            StatsCacheLoader.loadAnalytics(projectsPath: SessionLoader().claudeProjectsPath)
        }.value
        stats = loaded
    }

    var filteredSessions: [(project: Project, session: Session)] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return recentSessions }
        return recentSessions.filter { pair in
            HighlightedText.fuzzyMatch(pair.session.title, query: trimmed) != nil
                || HighlightedText.fuzzyMatch(pair.project.name, query: trimmed) != nil
        }
    }

    private static let maxRecentSessions = 10

    func loadRecentSessions(from projects: [Project]) {
        recentSessions = Array(
            projects
                .flatMap { project in project.sessions.map { (project: project, session: $0) } }
                .sorted { $0.session.startedAt > $1.session.startedAt }
                .prefix(Self.maxRecentSessions)
        )
    }
}
