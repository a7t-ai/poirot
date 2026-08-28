import Foundation

/// Loads versioned file snapshots from Claude Code's file history.
///
/// Session JSONL files contain `file-history-snapshot` entries that map
/// file names to content hashes. The actual file content lives in
/// `~/.claude/file-history/<sessionId>/<hash@vN>`.
nonisolated struct FileHistoryLoader: FileHistoryLoading {
    let claudeProjectsPath: String
    let claudeFileHistoryPath: String

    init(claudeProjectsPath: String? = nil, claudeFileHistoryPath: String? = nil) {
        self.claudeProjectsPath = claudeProjectsPath ?? Self.defaultProjectsPath
        self.claudeFileHistoryPath = claudeFileHistoryPath ?? Self.defaultFileHistoryPath
    }

    func loadFileHistory(for sessionId: String, projectPath: String) -> [FileHistoryEntry] {
        let backups = parseBackups(sessionId: sessionId, projectPath: projectPath)
        guard !backups.isEmpty else { return [] }

        // Group by file name, collecting all versions. Snapshot keys are often
        // absolute while delta `trackingPath` is relative (or the reverse) — treat
        // those as one file so consecutive diffs aren't computed against a gap.
        var grouped: [String: [FileVersion]] = [:]
        for backup in backups {
            let fileName = Self.canonicalFileName(backup.fileName, existing: Array(grouped.keys))
            if let previous = grouped.keys.first(where: { Self.sameFile($0, fileName) }),
               previous != fileName {
                grouped[fileName] = grouped.removeValue(forKey: previous)
            }
            let version = FileVersion(
                fileName: fileName,
                sessionId: sessionId,
                version: backup.version,
                backupTime: backup.backupTime,
                contentHash: backup.contentHash,
                backupFileName: backup.backupFileName
            )
            grouped[fileName, default: []].append(version)
        }

        // Deduplicate versions by backupFileName
        let entries = grouped.map { fileName, versions in
            var seen = Set<String>()
            let unique = versions
                .sorted { lhs, rhs in
                    if lhs.version != rhs.version { return lhs.version < rhs.version }
                    return lhs.backupTime < rhs.backupTime
                }
                .filter { seen.insert($0.backupFileName).inserted }
            return FileHistoryEntry(fileName: fileName, versions: unique)
        }

        return entries.sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
    }

    func loadFileContent(for sessionId: String, backupFileName: String) -> String? {
        let filePath = (claudeFileHistoryPath as NSString)
            .appendingPathComponent(sessionId)
            .appending("/\(backupFileName)")
        return try? String(contentsOfFile: filePath, encoding: .utf8)
    }

    // MARK: - Private

    private static let defaultProjectsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/projects"
    }()

    private static let defaultFileHistoryPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/file-history"
    }()

    nonisolated(unsafe) private static let dateFormatterFractional: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt
    }()

    nonisolated(unsafe) private static let dateFormatterPlain: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        return fmt
    }()

    private func parseBackups(sessionId: String, projectPath _: String) -> [FileBackup] {
        let fm = FileManager.default
        let projectsURL = URL(fileURLWithPath: claudeProjectsPath)

        // Find the project directory that contains this session's JSONL
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var jsonlURL: URL?
        for dir in projectDirs {
            let candidate = dir.appendingPathComponent("\(sessionId).jsonl")
            if fm.fileExists(atPath: candidate.path) {
                jsonlURL = candidate
                break
            }
        }

        guard let fileURL = jsonlURL,
              let data = try? Data(contentsOf: fileURL)
        else { return [] }

        let content = String(decoding: data, as: UTF8.self)
        var backups: [FileBackup] = []

        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String
            else { continue }

            switch type {
            case "file-history-snapshot":
                let tracked = (json["snapshot"] as? [String: Any])?["trackedFileBackups"] as? [String: [String: Any]]
                if let tracked {
                    for (fileName, backupData) in tracked {
                        if let backup = Self.parseBackup(fileName: fileName, data: backupData) {
                            backups.append(backup)
                        }
                    }
                }
            case "file-history-delta":
                // Claude Code now records per-edit versions as deltas; v1 (and other
                // intermediate backups) often live only here, not in snapshots.
                if let trackingPath = json["trackingPath"] as? String,
                   let backupData = json["backup"] as? [String: Any],
                   let backup = Self.parseBackup(fileName: trackingPath, data: backupData) {
                    backups.append(backup)
                }
            default:
                continue
            }
        }

        return backups
    }

    private static func parseBackup(fileName: String, data: [String: Any]) -> FileBackup? {
        guard let backupFileName = data["backupFileName"] as? String, !backupFileName.isEmpty else {
            return nil
        }
        let version = StatsComputer.intValue(from: data["version"])
        guard version > 0,
              let backupTimeStr = data["backupTime"] as? String,
              let backupTime = parseBackupTime(backupTimeStr)
        else { return nil }

        let contentHash = backupFileName.components(separatedBy: "@").first ?? backupFileName
        return FileBackup(
            fileName: fileName,
            backupFileName: backupFileName,
            version: version,
            backupTime: backupTime,
            contentHash: contentHash
        )
    }

    private static func parseBackupTime(_ string: String) -> Date? {
        dateFormatterFractional.date(from: string) ?? dateFormatterPlain.date(from: string)
    }

    /// True when two transcript paths refer to the same file (`src/a.swift` vs
    /// `/Users/me/proj/src/a.swift`).
    static func sameFile(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        let left = lhs.hasPrefix("/") ? lhs : "/" + lhs
        let right = rhs.hasPrefix("/") ? rhs : "/" + rhs
        return left.hasSuffix(right) || right.hasSuffix(left)
    }

    private static func canonicalFileName(_ name: String, existing: [String]) -> String {
        guard let match = existing.first(where: { sameFile($0, name) }) else { return name }
        return match.count >= name.count ? match : name
    }
}

// MARK: - Internal Types

private struct FileBackup {
    let fileName: String
    let backupFileName: String
    let version: Int
    let backupTime: Date
    let contentHash: String
}
