@testable import Poirot
import Foundation
import Testing

@Suite("PoirotTokenStore")
struct PoirotTokenStoreTests {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("poirot-token-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test
    func save_thenRead_roundTripsTrimmed() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PoirotTokenStore(directory: dir)

        store.save("  sk-ant-oat01-abc  ")

        #expect(store.read() == "sk-ant-oat01-abc")
    }

    @Test
    func read_whenMissing_returnsNil() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(PoirotTokenStore(directory: dir).read() == nil)
    }

    @Test
    func save_writesOwnerOnlyFile() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PoirotTokenStore(directory: dir)

        store.save("tok")

        let attrs = try FileManager.default.attributesOfItem(
            atPath: dir.appendingPathComponent("usage-token").path
        )
        #expect((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test
    func delete_removesToken() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PoirotTokenStore(directory: dir)
        store.save("tok")

        store.delete()

        #expect(store.read() == nil)
    }

    @Test
    func save_blank_isIgnored() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PoirotTokenStore(directory: dir)

        store.save("   ")

        #expect(store.read() == nil)
    }
}
