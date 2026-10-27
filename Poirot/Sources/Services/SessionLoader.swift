import Foundation

/// Loads Claude Code session transcripts from ~/.claude/projects/
nonisolated struct SessionLoader: SessionLoading {
    let claudeProjectsPath: String

    init(claudeProjectsPath: String? = nil) {
        self.claudeProjectsPath = claudeProjectsPath ?? Self.defaultPath
    }

    /// Discovers all projects with JSONL transcript files
    func discoverProjects() throws -> [Project] {
        let fm = FileManager.default
        let projectsURL = URL(fileURLWithPath: claudeProjectsPath)

        guard fm.fileExists(atPath: projectsURL.path) else {
            return []
        }

        let contents = try fm.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return contents.compactMap { url -> Project? in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }

            return buildProject(at: url)
        }
    }

    // MARK: - Incremental Loading

    /// Returns project directory URLs — lightweight, no JSONL parsing
    nonisolated static func projectDirectoryURLs(at path: String) throws -> [URL] {
        let fm = FileManager.default
        let projectsURL = URL(fileURLWithPath: path)

        guard fm.fileExists(atPath: projectsURL.path) else { return [] }

        let contents = try fm.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return contents.filter { url in
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }
    }

    /// Project directory URLs, most recently active first. Activity is the newest modification
    /// date among a folder's transcripts, or the folder's own when it has none. Reads file
    /// metadata only, so it stays fast with thousands of sessions.
    nonisolated static func projectDirectoriesByRecentActivity(at path: String) throws -> [URL] {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]

        let dated = try projectDirectoryURLs(at: path).map { url -> (url: URL, date: Date) in
            let files = (try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )) ?? []
            let newestTranscript = files
                .filter { $0.pathExtension == "jsonl" }
                .compactMap { try? $0.resourceValues(forKeys: keys).contentModificationDate }
                .max()
            let folderDate = try? url.resourceValues(forKeys: keys).contentModificationDate
            return (url, newestTranscript ?? folderDate ?? .distantPast)
        }

        return dated
            .sorted { lhs, rhs in
                lhs.date == rhs.date
                    ? lhs.url.lastPathComponent < rhs.url.lastPathComponent
                    : lhs.date > rhs.date
            }
            .map(\.url)
    }

    /// Builds a single project from a directory URL — does file I/O. Parses only the newest
    /// `sessionLimit` sessions and counts the rest in `Project.unloadedSessionCount`.
    nonisolated static func loadProject(at directoryURL: URL, sessionLimit: Int = .max) -> Project? {
        let loader = SessionLoader()
        return loader.buildProject(at: directoryURL, sessionLimit: sessionLimit)
    }

    // MARK: - Private

    private static let defaultPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/projects"
    }()

    private static let uuidRegex = try? NSRegularExpression(
        pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
    )

    private static let agentPrefix = "agent-"

    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt
    }()

    private let parser = TranscriptParser()

    private func buildProject(at directoryURL: URL, sessionLimit: Int = .max) -> Project? {
        let fm = FileManager.default
        let dirName = directoryURL.lastPathComponent
        let index = readSessionsIndex(at: directoryURL)

        let projectName: String
        if let originalPath = index?.originalPath {
            projectName = (originalPath as NSString).lastPathComponent
        } else {
            projectName = decodeProjectPath(dirName)
        }

        let projectPath = index?.originalPath ?? ("/" + dirName.replacingOccurrences(of: "-", with: "/"))

        // Index fast path: use index to identify sessions, parseSummary for metadata
        if let entries = index?.entries, !entries.isEmpty {
            let transcriptURL = { (entry: SessionsIndex.Entry) in
                directoryURL.appendingPathComponent("\(entry.sessionId).jsonl")
            }
            // Newest first; entries whose transcript is gone are dropped before counting
            let sortedEntries = entries
                .filter { fm.fileExists(atPath: transcriptURL($0).path) }
                .sorted {
                    (Self.dateFormatter.date(from: $0.created) ?? .distantPast)
                        > (Self.dateFormatter.date(from: $1.created) ?? .distantPast)
                }
            let parseEntry = { (entry: SessionsIndex.Entry) in
                parser.parseSummary(
                    fileURL: transcriptURL(entry),
                    projectPath: projectPath,
                    sessionId: entry.sessionId,
                    indexStartedAt: Self.dateFormatter.date(from: entry.created),
                    firstPrompt: entry.firstPrompt,
                    agentId: entry.agentId,
                    isSidechain: entry.isSidechain
                )
            }
            let main = parseNewest(
                sortedEntries.filter { !$0.isSidechain },
                limit: sessionLimit,
                isSidechain: false,
                fileURL: transcriptURL,
                parse: parseEntry
            )
            let sidechains = parseNewest(
                sortedEntries.filter(\.isSidechain),
                limit: sessionLimit,
                isSidechain: true,
                fileURL: transcriptURL,
                parse: parseEntry
            )
            let unloadedCount = main.unloadedCount + sidechains.unloadedCount

            var sessions = main.sessions + sidechains.sessions
            // Scan subagent directories for each main session
            let mainSessionIds = main.sessions.map(\.id)
            for parentId in mainSessionIds {
                let agentSessions = loadSubAgentSessions(
                    parentSessionId: parentId,
                    directoryURL: directoryURL,
                    projectPath: projectPath
                )
                sessions.append(contentsOf: agentSessions)
            }

            sessions.sort { $0.startedAt > $1.startedAt }
            return Project(
                id: dirName,
                name: projectName,
                path: projectPath,
                sessions: sessions,
                unloadedSessionCount: unloadedCount
            )
        }

        // Fallback path: no index — parseSummary the most recent JSONL files
        guard let items = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return Project(id: dirName, name: projectName, path: projectPath, sessions: [])
        }

        let allJsonl = items.filter { $0.pathExtension == "jsonl" }

        let sortByDate: (URL, URL) -> Bool = { lhs, rhs in
            let keys: Set<URLResourceKey> = [.contentModificationDateKey]
            let lhsDate = (try? lhs.resourceValues(forKeys: keys))
                .flatMap(\.contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: keys))
                .flatMap(\.contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        let mainFiles = allJsonl
            .filter { isUUIDFilename($0.deletingPathExtension().lastPathComponent) }
            .sorted(by: sortByDate)

        let agentFiles = allJsonl
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix(Self.agentPrefix) }
            .sorted(by: sortByDate)

        let main = parseNewest(
            mainFiles,
            limit: sessionLimit,
            isSidechain: false,
            fileURL: { $0 },
            parse: { item in
                parser.parseSummary(
                    fileURL: item,
                    projectPath: projectPath,
                    sessionId: item.deletingPathExtension().lastPathComponent,
                    indexStartedAt: nil
                )
            }
        )
        let agents = parseNewest(
            agentFiles,
            limit: sessionLimit,
            isSidechain: true,
            fileURL: { $0 },
            parse: { item in
                let stem = item.deletingPathExtension().lastPathComponent
                return parser.parseSummary(
                    fileURL: item,
                    projectPath: projectPath,
                    sessionId: stem,
                    indexStartedAt: nil,
                    agentId: String(stem.dropFirst(Self.agentPrefix.count)),
                    isSidechain: true
                )
            }
        )

        var sessions = main.sessions + agents.sessions

        // Scan subagent directories for each main session
        let fallbackMainIds = main.sessions.map(\.id)
        for parentId in fallbackMainIds {
            let agentSessions = loadSubAgentSessions(
                parentSessionId: parentId,
                directoryURL: directoryURL,
                projectPath: projectPath
            )
            sessions.append(contentsOf: agentSessions)
        }

        sessions.sort { $0.startedAt > $1.startedAt }

        return Project(
            id: dirName,
            name: projectName,
            path: projectPath,
            sessions: sessions,
            unloadedSessionCount: main.unloadedCount + agents.unloadedCount
        )
    }

    /// Parses transcripts in order (newest first) until `limit` of them hold a conversation, so
    /// transcripts without one don't use up the limit. `unloadedCount` is how many of the rest
    /// hold a conversation, checked by reading each only up to its first message.
    private func parseNewest<Transcript>(
        _ transcripts: [Transcript],
        limit: Int,
        isSidechain: Bool,
        fileURL: (Transcript) -> URL,
        parse: (Transcript) -> Session?
    ) -> (sessions: [Session], unloadedCount: Int) {
        var sessions: [Session] = []
        var next = transcripts.startIndex
        while next < transcripts.endIndex, sessions.count < limit {
            if let session = parse(transcripts[next]) {
                sessions.append(session)
            }
            next += 1
        }
        let unloadedCount = transcripts[next...].count {
            parser.containsConversation(fileURL: fileURL($0), isSidechain: isSidechain)
        }
        return (sessions, unloadedCount)
    }

    private func readSessionsIndex(at directoryURL: URL) -> SessionsIndex? {
        let indexURL = directoryURL.appendingPathComponent("sessions-index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let entries: [SessionsIndex.Entry] = {
            guard let rawEntries = json["entries"] as? [[String: Any]] else { return [] }
            return rawEntries.compactMap { entry in
                guard let sessionId = entry["sessionId"] as? String,
                      let created = entry["created"] as? String
                else { return nil }
                let isSidechain = entry["isSidechain"] as? Bool ?? false
                let projectPath = entry["projectPath"] as? String
                let firstPrompt = entry["firstPrompt"] as? String
                let agentId = entry["agentId"] as? String
                return SessionsIndex.Entry(
                    sessionId: sessionId,
                    created: created,
                    isSidechain: isSidechain,
                    projectPath: projectPath,
                    firstPrompt: firstPrompt,
                    agentId: agentId
                )
            }
        }()

        let originalPath = entries.first?.projectPath
            ?? json["projectPath"] as? String

        return SessionsIndex(originalPath: originalPath, entries: entries)
    }

    // MARK: - Sub-Agent Loading

    private func loadSubAgentSessions(
        parentSessionId: String,
        directoryURL: URL,
        projectPath: String
    ) -> [Session] {
        let fm = FileManager.default
        let subagentsDir = directoryURL
            .appendingPathComponent(parentSessionId)
            .appendingPathComponent("subagents")

        guard fm.fileExists(atPath: subagentsDir.path) else { return [] }

        guard let files = try? fm.contentsOfDirectory(
            at: subagentsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let agentFiles = files.filter {
            $0.pathExtension == "jsonl"
                && $0.lastPathComponent.hasPrefix(Self.agentPrefix)
                && !$0.lastPathComponent.hasPrefix("\(Self.agentPrefix)acompact-")
        }

        var sessions: [Session] = []
        for file in agentFiles {
            let stem = file.deletingPathExtension().lastPathComponent
            let agentId = String(stem.dropFirst(Self.agentPrefix.count))
            let meta = parseAgentMeta(at: subagentsDir.appendingPathComponent("\(stem).meta.json"))

            if let session = parser.parseSummary(
                fileURL: file,
                projectPath: projectPath,
                sessionId: stem,
                indexStartedAt: nil,
                agentId: agentId,
                isSidechain: true,
                parentSessionId: parentSessionId,
                agentType: meta.agentType,
                agentDescription: meta.description
            ) {
                sessions.append(session)
            }
        }
        return sessions
    }

    private func parseAgentMeta(at url: URL) -> (agentType: String?, description: String?) {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return (nil, nil) }
        return (json["agentType"] as? String, json["description"] as? String)
    }

    private func isUUIDFilename(_ name: String) -> Bool {
        let range = NSRange(name.startIndex..., in: name)
        return Self.uuidRegex?.firstMatch(in: name, range: range) != nil
    }

    private func isSessionFilename(_ name: String) -> Bool {
        if isUUIDFilename(name) { return true }
        if name.hasPrefix(Self.agentPrefix) { return true }
        return false
    }

    private func decodeProjectPath(_ encoded: String) -> String {
        let fm = FileManager.default

        // Tokens from the encoded name (skip leading empty from the leading dash)
        let tokens = encoded.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        let parts = tokens.first?.isEmpty == true ? Array(tokens.dropFirst()) : tokens

        guard !parts.isEmpty else { return encoded }

        // Greedily reconstruct the real path by probing the filesystem.
        // At each position, try increasingly longer hyphenated segments
        // and pick the longest that exists as a directory on disk.
        var resolvedPath = ""
        var i = 0

        while i < parts.count {
            var bestEnd = -1

            for j in i ..< parts.count {
                let candidate = parts[i ... j].joined(separator: "-")
                let testPath = resolvedPath + "/" + candidate

                var isDir: ObjCBool = false
                if fm.fileExists(atPath: testPath, isDirectory: &isDir), isDir.boolValue {
                    bestEnd = j
                }
            }

            if bestEnd >= 0 {
                resolvedPath += "/" + parts[i ... bestEnd].joined(separator: "-")
                i = bestEnd + 1
            } else {
                // Remaining tokens form the last component (may no longer exist on disk)
                resolvedPath += "/" + parts[i...].joined(separator: "-")
                break
            }
        }

        return (resolvedPath as NSString).lastPathComponent
    }
}

nonisolated private struct SessionsIndex {
    let originalPath: String?
    let entries: [Entry]

    struct Entry {
        let sessionId: String
        let created: String
        let isSidechain: Bool
        let projectPath: String?
        let firstPrompt: String?
        let agentId: String?
    }
}
