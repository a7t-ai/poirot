import Foundation

/// A single versioned backup of a file from a Claude Code session.
nonisolated struct FileVersion: Identifiable, Hashable {
    let id: String
    let fileName: String
    let sessionId: String
    let version: Int
    let backupTime: Date
    let contentHash: String
    let backupFileName: String

    init(
        fileName: String,
        sessionId: String,
        version: Int,
        backupTime: Date,
        contentHash: String,
        backupFileName: String
    ) {
        self.id = "\(sessionId)-\(backupFileName)"
        self.fileName = fileName
        self.sessionId = sessionId
        self.version = version
        self.backupTime = backupTime
        self.contentHash = contentHash
        self.backupFileName = backupFileName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileVersion, rhs: FileVersion) -> Bool {
        lhs.id == rhs.id
    }
}

/// Groups all versions of a single file within a session.
nonisolated struct FileHistoryEntry: Identifiable, Hashable {
    let id: String
    let fileName: String
    let versions: [FileVersion]

    var editCount: Int { versions.count }

    var latestVersion: FileVersion? { versions.last }

    init(fileName: String, versions: [FileVersion]) {
        self.id = fileName
        self.fileName = fileName
        self.versions = versions.sorted { lhs, rhs in
            if lhs.version != rhs.version { return lhs.version < rhs.version }
            return lhs.backupTime < rhs.backupTime
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileHistoryEntry, rhs: FileHistoryEntry) -> Bool {
        lhs.id == rhs.id
    }
}
