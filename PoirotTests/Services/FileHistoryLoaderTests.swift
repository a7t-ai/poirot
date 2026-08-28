@testable import Poirot
import Foundation
import Testing

@Suite("FileHistoryLoader")
struct FileHistoryLoaderTests {
    private func makeHarness() throws -> (root: URL, projects: URL, history: URL, sessionId: String) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("fh-\(UUID().uuidString)")
        let projects = root.appendingPathComponent("projects")
        let projectDir = projects.appendingPathComponent("proj")
        let history = root.appendingPathComponent("file-history")
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let sessionId = UUID().uuidString
        try fm.createDirectory(
            at: history.appendingPathComponent(sessionId),
            withIntermediateDirectories: true
        )
        return (root, projects, history, sessionId)
    }

    private func writeJSONL(_ content: String, sessionId: String, projects: URL) throws {
        try content.write(
            to: projects.appendingPathComponent("proj").appendingPathComponent("\(sessionId).jsonl"),
            atomically: true,
            encoding: .utf8
        )
    }

    @Test
    func load_includesDeltaVersionsMissingFromSnapshots() throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        // Snapshot only has v2; v1 lives on the newer file-history-delta records.
        let jsonl = """
        {"type":"file-history-snapshot","messageId":"s1","snapshot":{"trackedFileBackups":{"src/a.swift":{"backupFileName":"aaa@v2","version":2,"backupTime":"2026-08-26T12:11:06.199Z"}}}}
        {"type":"file-history-delta","messageId":"d1","trackingPath":"src/a.swift","backup":{"backupFileName":"aaa@v1","version":1,"backupTime":"2026-08-26T12:00:00.000Z"}}
        {"type":"file-history-delta","messageId":"d2","trackingPath":"src/b.swift","backup":{"backupFileName":"bbb@v1","version":1,"backupTime":"2026-08-26T13:00:00Z"}}
        {"type":"file-history-delta","messageId":"d3","trackingPath":"src/c.swift","backup":{"backupFileName":null,"version":1,"backupTime":"2026-08-26T14:00:00.000Z"}}
        """
        try writeJSONL(jsonl, sessionId: harness.sessionId, projects: harness.projects)

        let loader = FileHistoryLoader(
            claudeProjectsPath: harness.projects.path,
            claudeFileHistoryPath: harness.history.path
        )
        let entries = loader.loadFileHistory(for: harness.sessionId, projectPath: "/tmp")

        #expect(entries.map(\.fileName).sorted() == ["src/a.swift", "src/b.swift"])

        let fileA = try #require(entries.first { $0.fileName == "src/a.swift" })
        #expect(fileA.versions.map(\.version) == [1, 2])
        #expect(fileA.versions.map(\.backupFileName) == ["aaa@v1", "aaa@v2"])

        let fileB = try #require(entries.first { $0.fileName == "src/b.swift" })
        #expect(fileB.versions.map(\.version) == [1])
        #expect(entries.contains { $0.fileName == "src/c.swift" } == false)
    }

    @Test
    func load_deltaOnlySession_stillReturnsFiles() throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        let jsonl = """
        {"type":"file-history-snapshot","messageId":"s1","snapshot":{"trackedFileBackups":{}}}
        {"type":"file-history-delta","messageId":"d1","trackingPath":"index.html","backup":{"backupFileName":"abc@v1","version":1,"backupTime":"2026-08-27T18:54:00.854Z"}}
        """
        try writeJSONL(jsonl, sessionId: harness.sessionId, projects: harness.projects)

        let loader = FileHistoryLoader(
            claudeProjectsPath: harness.projects.path,
            claudeFileHistoryPath: harness.history.path
        )
        let entries = loader.loadFileHistory(for: harness.sessionId, projectPath: "/tmp")
        #expect(entries.count == 1)
        #expect(entries.first?.fileName == "index.html")
        #expect(entries.first?.versions.first?.backupFileName == "abc@v1")
    }

    @Test
    func sameFile_treatsRelativeAsSuffixOfAbsolute() {
        #expect(FileHistoryLoader.sameFile("src/a.swift", "/Users/me/proj/src/a.swift"))
        #expect(FileHistoryLoader.sameFile("/Users/me/proj/src/a.swift", "src/a.swift"))
        #expect(!FileHistoryLoader.sameFile("src/a.swift", "lib/a.swift"))
        #expect(!FileHistoryLoader.sameFile("src/a.swift", "src/b.swift"))
    }

    @Test
    func load_mergesRelativeAndAbsolutePathsForSameFile() throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        let jsonl = """
        {"type":"file-history-snapshot","messageId":"s1","snapshot":{"trackedFileBackups":{"/Users/me/proj/src/a.swift":{"backupFileName":"aaa@v2","version":2,"backupTime":"2026-08-26T12:11:06.199Z"}}}}
        {"type":"file-history-delta","messageId":"d1","trackingPath":"src/a.swift","backup":{"backupFileName":"aaa@v1","version":1,"backupTime":"2026-08-26T12:00:00.000Z"}}
        """
        try writeJSONL(jsonl, sessionId: harness.sessionId, projects: harness.projects)

        let loader = FileHistoryLoader(
            claudeProjectsPath: harness.projects.path,
            claudeFileHistoryPath: harness.history.path
        )
        let entries = loader.loadFileHistory(for: harness.sessionId, projectPath: "/tmp")
        #expect(entries.count == 1)
        #expect(entries.first?.fileName == "/Users/me/proj/src/a.swift")
        #expect(entries.first?.versions.map(\.version) == [1, 2])
    }

    @Test
    func loadFileContent_readsBackup() throws {
        let harness = try makeHarness()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        let backup = harness.history
            .appendingPathComponent(harness.sessionId)
            .appendingPathComponent("abc@v1")
        try "hello v1".write(to: backup, atomically: true, encoding: .utf8)

        let loader = FileHistoryLoader(
            claudeProjectsPath: harness.projects.path,
            claudeFileHistoryPath: harness.history.path
        )
        #expect(loader.loadFileContent(for: harness.sessionId, backupFileName: "abc@v1") == "hello v1")
        #expect(loader.loadFileContent(for: harness.sessionId, backupFileName: "missing") == nil)
    }
}
