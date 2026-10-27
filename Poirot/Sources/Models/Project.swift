import Foundation

nonisolated struct Project: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let sessions: [Session]
    /// Sessions on disk left unparsed by the session limit; zero once every session is loaded.
    var unloadedSessionCount = 0

    var recentSession: Session? {
        sessions.max(by: { $0.startedAt < $1.startedAt })
    }

    /// The same project holding `sessions` instead, used by filters that narrow the list.
    func withSessions(_ sessions: [Session]) -> Project {
        Project(id: id, name: name, path: path, sessions: sessions, unloadedSessionCount: unloadedSessionCount)
    }
}
