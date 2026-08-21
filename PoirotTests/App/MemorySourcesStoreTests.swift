@testable import Poirot
import Foundation
import Testing

@MainActor
@Suite("MemorySourcesStore")
struct MemorySourcesStoreTests {
    /// A throwaway defaults suite so persistence never touches `.standard` or leaks between tests.
    private static func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "MemorySourcesStoreTests-\(UUID().uuidString)")!
    }

    @Test
    func add_appendsAndPersists() {
        let defaults = Self.freshDefaults()
        let store = MemorySourcesStore(defaults: defaults)

        store.add(URL(fileURLWithPath: "/tmp/poirot-a"))

        #expect(store.folders.map(\.path) == ["/tmp/poirot-a"])
        // Persisted → a freshly constructed store reads it back.
        let reloaded = MemorySourcesStore(defaults: defaults)
        #expect(reloaded.folders.map(\.path) == ["/tmp/poirot-a"])
    }

    @Test
    func add_ignoresDuplicates() {
        let store = MemorySourcesStore(defaults: Self.freshDefaults())
        let url = URL(fileURLWithPath: "/tmp/poirot-a")

        store.add(url)
        store.add(url)

        #expect(store.folders.count == 1)
    }

    @Test
    func remove_dropsFolder() {
        let store = MemorySourcesStore(defaults: Self.freshDefaults())
        let a = URL(fileURLWithPath: "/tmp/poirot-a")
        let b = URL(fileURLWithPath: "/tmp/poirot-b")
        store.add(a)
        store.add(b)

        store.remove(a)

        #expect(store.folders.map(\.path) == ["/tmp/poirot-b"])
    }

    @Test
    func loadFolders_readsPersistedPaths() {
        let defaults = Self.freshDefaults()
        defaults.set(["/tmp/one", "/tmp/two"], forKey: MemorySourcesStore.foldersKey)

        let folders = MemorySourcesStore.loadFolders(from: defaults)

        #expect(folders.map(\.path) == ["/tmp/one", "/tmp/two"])
    }
}
