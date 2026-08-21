@testable import Poirot
import Foundation
import Testing

@Suite("MemoryLoader")
struct MemoryLoaderTests {
    // MARK: - Load Memory Files

    @Test
    func loadMemoryFiles_returnsEmptyForMissingDirectory() {
        let files = ClaudeConfigLoader.loadMemoryFiles(
            projectDirName: "nonexistent-project-\(UUID().uuidString)"
        )
        #expect(files.isEmpty)
    }

    @Test
    func loadMemoryFiles_loadsMarkdownFiles() throws {
        let (projectDir, memoryDir) = try createTempMemoryDir()
        defer { try? FileManager.default.removeItem(at: projectDir) }

        try "# Main Memory".write(
            to: memoryDir.appendingPathComponent("MEMORY.md"),
            atomically: true, encoding: .utf8
        )
        try "# Debugging tips".write(
            to: memoryDir.appendingPathComponent("debugging.md"),
            atomically: true, encoding: .utf8
        )
        // Non-md file should be ignored
        try "not markdown".write(
            to: memoryDir.appendingPathComponent("notes.txt"),
            atomically: true, encoding: .utf8
        )

        let dirName = projectDir.lastPathComponent
        let files = ClaudeConfigLoader.loadMemoryFiles(projectDirName: dirName)

        #expect(files.count == 2)
        // MEMORY.md should be first (sorted to top)
        #expect(files.first?.isMain == true)
        #expect(files.first?.name == "MEMORY")
        #expect(files.first?.content == "# Main Memory")
    }

    @Test
    func loadMemoryFiles_memoryMdSortedFirst() throws {
        let (projectDir, memoryDir) = try createTempMemoryDir()
        defer { try? FileManager.default.removeItem(at: projectDir) }

        try "# Patterns".write(
            to: memoryDir.appendingPathComponent("patterns.md"),
            atomically: true, encoding: .utf8
        )
        try "# Main".write(
            to: memoryDir.appendingPathComponent("MEMORY.md"),
            atomically: true, encoding: .utf8
        )
        try "# Architecture".write(
            to: memoryDir.appendingPathComponent("architecture.md"),
            atomically: true, encoding: .utf8
        )

        let dirName = projectDir.lastPathComponent
        let files = ClaudeConfigLoader.loadMemoryFiles(projectDirName: dirName)

        #expect(files.count == 3)
        #expect(files[0].filename == "MEMORY.md")
        #expect(files[0].isMain == true)
        // Remaining files sorted alphabetically
        #expect(files[1].name == "Architecture")
        #expect(files[2].name == "Patterns")
    }

    @Test
    func loadMemoryFiles_setsProjectID() throws {
        let (projectDir, memoryDir) = try createTempMemoryDir()
        defer { try? FileManager.default.removeItem(at: projectDir) }

        try "# Test".write(
            to: memoryDir.appendingPathComponent("test.md"),
            atomically: true, encoding: .utf8
        )

        let dirName = projectDir.lastPathComponent
        let files = ClaudeConfigLoader.loadMemoryFiles(projectDirName: dirName)

        #expect(files.first?.projectID == dirName)
    }

    // MARK: - Custom Folder Sources

    @Test
    func loadMemoryFiles_customFolder_loadsMarkdownWithSourceLabel() throws {
        let folder = try createTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try "# Notes".write(to: folder.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)
        try "# Main".write(to: folder.appendingPathComponent("MEMORY.md"), atomically: true, encoding: .utf8)
        try "ignore".write(to: folder.appendingPathComponent("todo.txt"), atomically: true, encoding: .utf8)

        let files = ClaudeConfigLoader.loadMemoryFiles(customFolder: folder)

        let allCustom = files.allSatisfy { $0.isCustomSource }
        #expect(files.count == 2) // .txt ignored
        #expect(files.first?.isMain == true) // MEMORY.md sorted first
        #expect(allCustom)
        #expect(files.first?.sourceLabel == folder.lastPathComponent)
        #expect(files.first?.projectID == "custom:\(folder.path)")
    }

    @Test
    func customMemoryFileCount_countsOnlyMarkdown() throws {
        let folder = try createTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try "a".write(to: folder.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try "b".write(to: folder.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try "c".write(to: folder.appendingPathComponent("c.txt"), atomically: true, encoding: .utf8)

        #expect(ClaudeConfigLoader.customMemoryFileCount(folder: folder) == 2)
    }

    @Test
    func loadMemoryFiles_customFolder_missing_returnsEmpty() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("poirot-missing-\(UUID().uuidString)")
        #expect(ClaudeConfigLoader.loadMemoryFiles(customFolder: missing).isEmpty)
    }

    // MARK: - Helpers

    private func createTempMemoryDir() throws -> (projectDir: URL, memoryDir: URL) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectDir = home
            .appendingPathComponent(".claude/projects")
            .appendingPathComponent("test-memory-\(UUID().uuidString)")
        let memoryDir = projectDir.appendingPathComponent("memory")
        try FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        return (projectDir, memoryDir)
    }

    private func createTempFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("poirot-mem-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
