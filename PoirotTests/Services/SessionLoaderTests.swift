@testable import Poirot
import Foundation
import Testing

@Suite("SessionLoader")
struct SessionLoaderTests {
    // MARK: - Helpers

    private func makeTempProjectDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("poirot-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeProjectWithJSONL(
        in baseDir: URL,
        projectDirName: String,
        sessionId: String,
        jsonlContent: String,
        indexJSON: String? = nil
    ) throws {
        let projectDir = baseDir.appendingPathComponent(projectDirName)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let jsonlFile = projectDir.appendingPathComponent("\(sessionId).jsonl")
        try jsonlContent.write(to: jsonlFile, atomically: true, encoding: .utf8)

        if let indexJSON {
            let indexFile = projectDir.appendingPathComponent("sessions-index.json")
            try indexJSON.write(to: indexFile, atomically: true, encoding: .utf8)
        }
    }

    private func userRecord(
        content: String,
        timestamp: String = "2026-01-28T10:00:00.000Z"
    ) -> String {
        let record: [String: Any] = [
            "type": "user",
            "uuid": UUID().uuidString,
            "timestamp": timestamp,
            "isSidechain": false,
            "message": ["role": "user", "content": content],
        ]
        let data = try! JSONSerialization.data(withJSONObject: record) // swiftlint:disable:this force_try
        return String(data: data, encoding: .utf8)!
    }

    private func assistantRecord(
        text: String,
        msgId: String = "msg_test",
        model: String = "claude-opus-4-6",
        timestamp: String = "2026-01-28T10:01:00.000Z",
        inputTokens: Int = 100,
        outputTokens: Int = 50
    ) -> String {
        let record: [String: Any] = [
            "type": "assistant",
            "uuid": UUID().uuidString,
            "timestamp": timestamp,
            "isSidechain": false,
            "message": [
                "id": msgId,
                "role": "assistant",
                "model": model,
                "content": [["type": "text", "text": text]],
                "usage": ["input_tokens": inputTokens, "output_tokens": outputTokens],
            ] as [String: Any],
        ]
        let data = try! JSONSerialization.data(withJSONObject: record) // swiftlint:disable:this force_try
        return String(data: data, encoding: .utf8)!
    }

    private func simpleJSONL(
        userText: String = "Hello",
        assistantText: String = "Hi there",
        userTimestamp: String = "2026-01-28T10:00:00.000Z",
        assistantTimestamp: String = "2026-01-28T10:01:00.000Z"
    ) -> String {
        [
            userRecord(content: userText, timestamp: userTimestamp),
            assistantRecord(text: assistantText, timestamp: assistantTimestamp),
        ].joined(separator: "\n")
    }

    // MARK: - Original Tests

    @Test
    func discoverProjects_nonExistentPath_returnsEmpty() throws {
        let loader = SessionLoader(claudeProjectsPath: "/nonexistent/path/\(UUID().uuidString)")
        let projects = try loader.discoverProjects()
        #expect(projects.isEmpty)
    }

    @Test
    func discoverProjects_emptyDirectory_returnsEmpty() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        #expect(projects.isEmpty)
    }

    @Test
    func discoverProjects_withSubdirectories_returnsProjects() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try FileManager.default.createDirectory(
            at: tmpDir.appendingPathComponent("project-alpha"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: tmpDir.appendingPathComponent("project-beta"),
            withIntermediateDirectories: true
        )

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        #expect(projects.count == 2)

        let names = Set(projects.map(\.name))
        #expect(names.contains("project-alpha"))
        #expect(names.contains("project-beta"))
    }

    @Test
    func discoverProjects_skipsFiles_onlyIncludesDirectories() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try FileManager.default.createDirectory(
            at: tmpDir.appendingPathComponent("real-project"),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(
            atPath: tmpDir.appendingPathComponent("not-a-project.txt").path,
            contents: Data("hello".utf8)
        )

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        #expect(projects.count == 1)
        #expect(projects[0].name == "real-project")
    }

    // MARK: - JSONL Parsing Integration

    @Test
    func discoverProjects_withJSONLFiles_parsesSessions() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let sessionId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        try makeProjectWithJSONL(
            in: tmpDir,
            projectDirName: "test-project",
            sessionId: sessionId,
            jsonlContent: simpleJSONL()
        )

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        #expect(projects.count == 1)
        #expect(projects[0].sessions.count == 1)

        let session = projects[0].sessions[0]
        #expect(session.id == sessionId)
        // Lazy loading: messages are empty, title comes from cachedTitle
        #expect(session.messages.isEmpty)
        #expect(session.title == "Hello")
        #expect(session.fileURL != nil)
    }

    @Test
    func discoverProjects_fallbackPath_loadsAgentFiles() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let projectDir = tmpDir.appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let validId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        let validFile = projectDir.appendingPathComponent("\(validId).jsonl")
        try simpleJSONL().write(to: validFile, atomically: true, encoding: .utf8)

        let agentId = "e7b2889f"
        let agentFile = projectDir.appendingPathComponent("agent-\(agentId).jsonl")
        try simpleJSONL().write(to: agentFile, atomically: true, encoding: .utf8)

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        #expect(projects[0].sessions.count == 2)

        let mainSession = projects[0].sessions.first { $0.id == validId }
        #expect(mainSession != nil)
        #expect(mainSession?.isSidechain == false)
        #expect(mainSession?.agentId == nil)

        let agentSession = projects[0].sessions.first { $0.id == "agent-\(agentId)" }
        #expect(agentSession != nil)
        #expect(agentSession?.isSidechain == true)
        #expect(agentSession?.agentId == agentId)
    }

    @Test
    func discoverProjects_sessionsSortedDescending() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let projectDir = tmpDir.appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let oldId = "00000000-0000-0000-0000-000000000001"
        let oldFile = projectDir.appendingPathComponent("\(oldId).jsonl")
        try simpleJSONL(userTimestamp: "2026-01-01T10:00:00.000Z", assistantTimestamp: "2026-01-01T10:01:00.000Z")
            .write(to: oldFile, atomically: true, encoding: .utf8)

        let newId = "00000000-0000-0000-0000-000000000002"
        let newFile = projectDir.appendingPathComponent("\(newId).jsonl")
        try simpleJSONL(userTimestamp: "2026-02-01T10:00:00.000Z", assistantTimestamp: "2026-02-01T10:01:00.000Z")
            .write(to: newFile, atomically: true, encoding: .utf8)

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        let sessions = projects[0].sessions
        #expect(sessions.count == 2)
        #expect(sessions[0].id == newId)
        #expect(sessions[1].id == oldId)
    }

    @Test
    func discoverProjects_usesOriginalPathFromIndex() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let sessionId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        let indexJSON = """
        {
            "version": 1,
            "entries": [
                {
                    "sessionId": "\(sessionId)",
                    "created": "2026-01-28T10:00:00.000Z",
                    "isSidechain": false,
                    "projectPath": "/Users/dev/projects/my-cool-app",
                    "firstPrompt": "Hello from index"
                }
            ]
        }
        """

        try makeProjectWithJSONL(
            in: tmpDir,
            projectDirName: "-Users-dev-projects-my-cool-app",
            sessionId: sessionId,
            jsonlContent: simpleJSONL(),
            indexJSON: indexJSON
        )

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        #expect(projects[0].name == "my-cool-app")
        #expect(projects[0].path == "/Users/dev/projects/my-cool-app")

        // Index fast path: session is built via parseSummary — title from JSONL content
        let session = projects[0].sessions[0]
        #expect(session.messages.isEmpty)
        #expect(session.title == "Hello")
        #expect(session.fileURL != nil)
    }

    @Test
    func discoverProjects_withMissingIndex_usesFallback() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let sessionId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        try makeProjectWithJSONL(
            in: tmpDir,
            projectDirName: "-Users-dev-projects-my-app",
            sessionId: sessionId,
            jsonlContent: simpleJSONL()
        )

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        #expect(projects[0].name == "dev-projects-my-app")
    }

    @Test
    func discoverProjects_emptyJSONLFile_producesNoSession() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let projectDir = tmpDir.appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let sessionId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        let emptyFile = projectDir.appendingPathComponent("\(sessionId).jsonl")
        try "".write(to: emptyFile, atomically: true, encoding: .utf8)

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        #expect(projects[0].sessions.isEmpty)
    }

    // MARK: - Index Fast Path

    @Test
    func discoverProjects_indexPath_includesSidechainEntries() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let mainId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        let sidechainId = "b2c3d4e5-f6a7-8901-bcde-f12345678901"
        let agentId = "e7b2889f"
        let indexJSON = """
        {
            "version": 1,
            "entries": [
                {
                    "sessionId": "\(mainId)",
                    "created": "2026-01-28T10:00:00.000Z",
                    "isSidechain": false,
                    "projectPath": "/test/project",
                    "firstPrompt": "Main session"
                },
                {
                    "sessionId": "\(sidechainId)",
                    "created": "2026-01-28T11:00:00.000Z",
                    "isSidechain": true,
                    "agentId": "\(agentId)",
                    "projectPath": "/test/project"
                }
            ]
        }
        """

        let projectDir = tmpDir.appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Create both JSONL files
        try simpleJSONL().write(
            to: projectDir.appendingPathComponent("\(mainId).jsonl"),
            atomically: true, encoding: .utf8
        )
        try simpleJSONL().write(
            to: projectDir.appendingPathComponent("\(sidechainId).jsonl"),
            atomically: true, encoding: .utf8
        )

        let indexFile = projectDir.appendingPathComponent("sessions-index.json")
        try indexJSON.write(to: indexFile, atomically: true, encoding: .utf8)

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        #expect(projects[0].sessions.count == 2)

        // Sidechain session should have agentId and isSidechain set
        let sidechain = projects[0].sessions.first { $0.id == sidechainId }
        #expect(sidechain != nil)
        #expect(sidechain?.isSidechain == true)
        #expect(sidechain?.agentId == agentId)

        // Main session should not be sidechain
        let main = projects[0].sessions.first { $0.id == mainId }
        #expect(main != nil)
        #expect(main?.isSidechain == false)
        #expect(main?.agentId == nil)
    }

    @Test
    func discoverProjects_indexPath_loadsAllSessions() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let projectDir = tmpDir.appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Create 25 sessions via index
        var entries: [[String: Any]] = []
        for i in 0 ..< 25 {
            let sessionId = String(format: "00000000-0000-0000-0000-%012d", i)
            let created = String(format: "2026-01-%02dT10:00:00.000Z", i + 1)
            entries.append([
                "sessionId": sessionId,
                "created": created,
                "isSidechain": false,
                "projectPath": "/test/project",
            ])
            let jsonlFile = projectDir.appendingPathComponent("\(sessionId).jsonl")
            try simpleJSONL(userTimestamp: created).write(to: jsonlFile, atomically: true, encoding: .utf8)
        }

        let index: [String: Any] = ["version": 1, "entries": entries]
        let indexData = try JSONSerialization.data(withJSONObject: index)
        try indexData.write(to: projectDir.appendingPathComponent("sessions-index.json"))

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        #expect(projects[0].sessions.count == 25)
    }

    @Test
    func discoverProjects_fallbackPath_usesHeaderParse() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let sessionId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        // No index — forces fallback path (header-only parse)
        try makeProjectWithJSONL(
            in: tmpDir,
            projectDirName: "test-project",
            sessionId: sessionId,
            jsonlContent: simpleJSONL(userText: "Fallback title")
        )

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        let session = projects[0].sessions[0]
        #expect(session.messages.isEmpty)
        #expect(session.title == "Fallback title")
        #expect(session.fileURL != nil)
    }

    // MARK: - First Prompt

    @Test
    func discoverProjects_indexPath_passesFirstPromptToSession() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let sessionId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        let indexJSON = """
        {
            "version": 1,
            "entries": [
                {
                    "sessionId": "\(sessionId)",
                    "created": "2026-01-28T10:00:00.000Z",
                    "isSidechain": false,
                    "projectPath": "/test/project",
                    "firstPrompt": "Fix the login bug"
                }
            ]
        }
        """

        try makeProjectWithJSONL(
            in: tmpDir,
            projectDirName: "test-project",
            sessionId: sessionId,
            jsonlContent: simpleJSONL(),
            indexJSON: indexJSON
        )

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        let session = projects[0].sessions[0]
        #expect(session.firstPrompt == "Fix the login bug")
    }

    @Test
    func discoverProjects_indexPath_nilFirstPromptWhenMissing() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let sessionId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        let indexJSON = """
        {
            "version": 1,
            "entries": [
                {
                    "sessionId": "\(sessionId)",
                    "created": "2026-01-28T10:00:00.000Z",
                    "isSidechain": false,
                    "projectPath": "/test/project"
                }
            ]
        }
        """

        try makeProjectWithJSONL(
            in: tmpDir,
            projectDirName: "test-project",
            sessionId: sessionId,
            jsonlContent: simpleJSONL(),
            indexJSON: indexJSON
        )

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        let session = projects[0].sessions[0]
        #expect(session.firstPrompt == nil)
    }

    @Test
    func discoverProjects_fallbackPath_firstPromptIsNil() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let sessionId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        // No index — forces fallback path
        try makeProjectWithJSONL(
            in: tmpDir,
            projectDirName: "test-project",
            sessionId: sessionId,
            jsonlContent: simpleJSONL()
        )

        let loader = SessionLoader(claudeProjectsPath: tmpDir.path)
        let projects = try loader.discoverProjects()
        let session = projects[0].sessions[0]
        #expect(session.firstPrompt == nil)
    }

    // MARK: - Recent Activity Order

    private func setModificationDate(_ date: Date, of url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    private func sessionId(_ index: Int) -> String {
        String(format: "00000000-0000-0000-0000-%012d", index)
    }

    @Test
    func projectDirectoriesByRecentActivity_ordersByNewestTranscript() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Transcript ages in seconds; "newer" has an old transcript but also the most recent one
        let now = Date()
        let layout: [(folder: String, ages: [TimeInterval])] = [
            ("older", [3000]),
            ("newer", [5000, 100]),
            ("middle", [2000]),
        ]
        for (folder, ages) in layout {
            let projectDir = tmpDir.appendingPathComponent(folder)
            try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
            for (index, age) in ages.enumerated() {
                let file = projectDir.appendingPathComponent("\(sessionId(index)).jsonl")
                try simpleJSONL().write(to: file, atomically: true, encoding: .utf8)
                try setModificationDate(now.addingTimeInterval(-age), of: file)
            }
        }

        let ordered = try SessionLoader.projectDirectoriesByRecentActivity(at: tmpDir.path)
        #expect(ordered.map(\.lastPathComponent) == ["newer", "middle", "older"])
    }

    @Test
    func projectDirectoriesByRecentActivity_folderWithoutTranscripts_usesFolderDate() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let now = Date()
        let withTranscript = tmpDir.appendingPathComponent("with-transcript")
        try FileManager.default.createDirectory(at: withTranscript, withIntermediateDirectories: true)
        let file = withTranscript.appendingPathComponent("\(sessionId(1)).jsonl")
        try simpleJSONL().write(to: file, atomically: true, encoding: .utf8)
        try setModificationDate(now.addingTimeInterval(-1000), of: file)

        let empty = tmpDir.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        try setModificationDate(now.addingTimeInterval(-10), of: empty)

        let ordered = try SessionLoader.projectDirectoriesByRecentActivity(at: tmpDir.path)
        #expect(ordered.map(\.lastPathComponent) == ["empty", "with-transcript"])
    }

    @Test
    func projectDirectoriesByRecentActivity_nonExistentPath_returnsEmpty() throws {
        let ordered = try SessionLoader.projectDirectoriesByRecentActivity(at: "/nonexistent/\(UUID().uuidString)")
        #expect(ordered.isEmpty)
    }

    // MARK: - Session Limit

    /// A project without an index holding `count` sessions. Session `i` started on day `i + 1`
    /// and was last written `count - i` hours ago, so the highest index is the newest.
    private func makeFallbackProject(in tmpDir: URL, sessionCount count: Int) throws -> URL {
        let projectDir = tmpDir.appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let now = Date()
        for index in 0 ..< count {
            let file = projectDir.appendingPathComponent("\(sessionId(index)).jsonl")
            let started = String(format: "2026-01-%02dT10:00:00.000Z", index + 1)
            try simpleJSONL(userTimestamp: started).write(to: file, atomically: true, encoding: .utf8)
            try setModificationDate(now.addingTimeInterval(Double(index - count) * 3600), of: file)
        }
        return projectDir
    }

    @Test
    func loadProject_fallbackPath_keepsNewestSessionsUnderLimit() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let projectDir = try makeFallbackProject(in: tmpDir, sessionCount: 5)

        let project = try #require(SessionLoader.loadProject(at: projectDir, sessionLimit: 2))
        #expect(project.sessions.map(\.id) == [sessionId(4), sessionId(3)])
        #expect(project.unloadedSessionCount == 3)
    }

    /// Rewrites session `index` as a transcript with no messages (what a session closed before its
    /// first prompt leaves), keeping its modification date.
    private func replaceWithNoMessageTranscript(_ index: Int, in projectDir: URL) throws {
        let file = projectDir.appendingPathComponent("\(sessionId(index)).jsonl")
        let date = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
        try [
            #"{"type":"permission-mode","permissionMode":"default"}"#,
            #"{"type":"last-prompt","by":"user"}"#,
        ].joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        if let date { try setModificationDate(date, of: file) }
    }

    @Test
    func loadProject_limitCountsConversationsNotTranscripts() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        // 12 transcripts, 11 conversations: the 5th newest (index 7) never got a prompt
        let projectDir = try makeFallbackProject(in: tmpDir, sessionCount: 12)
        try replaceWithNoMessageTranscript(7, in: projectDir)

        let project = try #require(SessionLoader.loadProject(at: projectDir, sessionLimit: 10))

        #expect(project.sessions.count == 10)
        #expect(!project.sessions.contains { $0.id == sessionId(7) })
        #expect(project.sessions.last?.id == sessionId(1))
        #expect(project.unloadedSessionCount == 1)
    }

    @Test
    func loadProject_unloadedCountSkipsOlderTranscriptsWithoutConversation() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        // The oldest transcript (index 0) never got a prompt, so only one older conversation is left
        let projectDir = try makeFallbackProject(in: tmpDir, sessionCount: 12)
        try replaceWithNoMessageTranscript(0, in: projectDir)

        let project = try #require(SessionLoader.loadProject(at: projectDir, sessionLimit: 10))

        #expect(project.sessions.count == 10)
        #expect(project.unloadedSessionCount == 1)
    }

    @Test
    func loadProject_withoutLimit_loadsEverySession() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let projectDir = try makeFallbackProject(in: tmpDir, sessionCount: 5)

        let project = try #require(SessionLoader.loadProject(at: projectDir))
        #expect(project.sessions.count == 5)
        #expect(project.unloadedSessionCount == 0)
    }

    @Test
    func loadProject_limit_loadsSubagentsOnlyForLoadedSessions() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let projectDir = try makeFallbackProject(in: tmpDir, sessionCount: 2)

        // Each main session ran one subagent
        for index in 0 ..< 2 {
            let subagents = projectDir
                .appendingPathComponent(sessionId(index))
                .appendingPathComponent("subagents")
            try FileManager.default.createDirectory(at: subagents, withIntermediateDirectories: true)
            let agentFile = subagents.appendingPathComponent("agent-a\(index).jsonl")
            try simpleJSONL().write(to: agentFile, atomically: true, encoding: .utf8)
        }

        let project = try #require(SessionLoader.loadProject(at: projectDir, sessionLimit: 1))
        #expect(project.sessions.filter { !$0.isSidechain }.map(\.id) == [sessionId(1)])
        #expect(project.sessions.filter(\.isSidechain).compactMap(\.parentSessionId) == [sessionId(1)])
        #expect(project.unloadedSessionCount == 1)
    }

    @Test
    func loadProject_indexPath_keepsNewestEntriesUnderLimit() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let projectDir = tmpDir.appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        var entries: [[String: Any]] = []
        for index in 0 ..< 25 {
            let created = String(format: "2026-01-%02dT10:00:00.000Z", index + 1)
            entries.append([
                "sessionId": sessionId(index),
                "created": created,
                "isSidechain": false,
                "projectPath": "/test/project",
            ])
            let file = projectDir.appendingPathComponent("\(sessionId(index)).jsonl")
            try simpleJSONL(userTimestamp: created).write(to: file, atomically: true, encoding: .utf8)
        }
        // The two newest entries point at transcripts that no longer exist
        for index in 25 ..< 27 {
            entries.append([
                "sessionId": sessionId(index),
                "created": String(format: "2026-02-%02dT10:00:00.000Z", index - 24),
                "isSidechain": false,
                "projectPath": "/test/project",
            ])
        }
        let index: [String: Any] = ["version": 1, "entries": entries]
        try JSONSerialization.data(withJSONObject: index)
            .write(to: projectDir.appendingPathComponent("sessions-index.json"))

        let project = try #require(SessionLoader.loadProject(at: projectDir, sessionLimit: 10))
        #expect(project.sessions.count == 10)
        #expect(project.sessions.first?.id == sessionId(24))
        #expect(project.sessions.last?.id == sessionId(15))
        #expect(project.unloadedSessionCount == 15)
    }

    @Test
    func loadProject_indexPath_limitCountsConversationsNotTranscripts() throws {
        let tmpDir = try makeTempProjectDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let projectDir = tmpDir.appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        var entries: [[String: Any]] = []
        for index in 0 ..< 12 {
            let created = String(format: "2026-01-%02dT10:00:00.000Z", index + 1)
            entries.append([
                "sessionId": sessionId(index),
                "created": created,
                "isSidechain": false,
                "projectPath": "/test/project",
            ])
            let file = projectDir.appendingPathComponent("\(sessionId(index)).jsonl")
            try simpleJSONL(userTimestamp: created).write(to: file, atomically: true, encoding: .utf8)
        }
        // The 4th newest entry never got a prompt
        try replaceWithNoMessageTranscript(8, in: projectDir)
        let index: [String: Any] = ["version": 1, "entries": entries]
        try JSONSerialization.data(withJSONObject: index)
            .write(to: projectDir.appendingPathComponent("sessions-index.json"))

        let project = try #require(SessionLoader.loadProject(at: projectDir, sessionLimit: 10))

        #expect(project.sessions.count == 10)
        #expect(project.sessions.last?.id == sessionId(1))
        #expect(project.unloadedSessionCount == 1)
    }
}
