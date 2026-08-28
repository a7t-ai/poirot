@testable import Poirot
import Testing

@Suite("LineDiff")
struct LineDiffTests {
    @Test
    func identicalStrings_allContext() {
        let lines = LineDiff.diff(old: "a\nb\nc", new: "a\nb\nc")
        #expect(lines.count == 3)
        #expect(lines.allSatisfy { $0.kind == .context })
    }

    @Test
    func emptyOld_allAdded() {
        let lines = LineDiff.diff(oldLines: [], newLines: ["a", "b"])
        let added = lines.filter { $0.kind == .added }
        #expect(added.count == 2)
        #expect(lines.filter { $0.kind == .removed }.isEmpty)
    }

    @Test
    func emptyNew_allRemoved() {
        let lines = LineDiff.diff(oldLines: ["a", "b"], newLines: [])
        let removed = lines.filter { $0.kind == .removed }
        #expect(removed.count == 2)
        #expect(lines.filter { $0.kind == .added }.isEmpty)
    }

    @Test
    func singleLineChange_oneRemovedOneAdded() {
        let lines = LineDiff.diff(old: "hello", new: "world")
        #expect(lines.filter { $0.kind == .removed }.count == 1)
        #expect(lines.filter { $0.kind == .added }.count == 1)
        #expect(lines.first { $0.kind == .removed }?.text == "hello")
        #expect(lines.first { $0.kind == .added }?.text == "world")
    }

    @Test
    func insertionInMiddle_preservesContext() {
        let lines = LineDiff.diff(old: "a\nc", new: "a\nb\nc")
        #expect(lines.count == 3)
        #expect(lines[0] == DiffLine(id: lines[0].id, kind: .context, text: "a", oldLineNumber: 1, newLineNumber: 1))
        #expect(lines[1].kind == .added)
        #expect(lines[1].text == "b")
        #expect(lines[2].kind == .context)
        #expect(lines[2].text == "c")
    }

    @Test
    func deletionInMiddle_preservesContext() {
        let lines = LineDiff.diff(old: "a\nb\nc", new: "a\nc")
        #expect(lines.count == 3)
        #expect(lines[0].kind == .context)
        #expect(lines[1].kind == .removed)
        #expect(lines[1].text == "b")
        #expect(lines[2].kind == .context)
    }

    @Test
    func lineNumbers_correctForContext() {
        let lines = LineDiff.diff(old: "a\nb\nc", new: "a\nb\nc")
        #expect(lines[0].oldLineNumber == 1)
        #expect(lines[0].newLineNumber == 1)
        #expect(lines[1].oldLineNumber == 2)
        #expect(lines[1].newLineNumber == 2)
        #expect(lines[2].oldLineNumber == 3)
        #expect(lines[2].newLineNumber == 3)
    }

    @Test
    func lineNumbers_nilForAddedRemoved() {
        let lines = LineDiff.diff(old: "old", new: "new")
        let removed = lines.first { $0.kind == .removed }!
        let added = lines.first { $0.kind == .added }!
        #expect(removed.oldLineNumber == 1)
        #expect(removed.newLineNumber == nil)
        #expect(added.oldLineNumber == nil)
        #expect(added.newLineNumber == 1)
    }

    @Test
    func sequentialIds() {
        let lines = LineDiff.diff(old: "a\nb", new: "a\nc")
        for (index, line) in lines.enumerated() {
            #expect(line.id == index)
        }
    }

    @Test
    func unifiedText_formatsCorrectly() {
        let lines = LineDiff.diff(old: "a\nb", new: "a\nc")
        let text = LineDiff.unifiedText(from: lines)
        #expect(text.contains(" a"))
        #expect(text.contains("-b"))
        #expect(text.contains("+c"))
    }

    @Test
    func bothEmpty_producesEmptyContextLine() {
        let lines = LineDiff.diff(old: "", new: "")
        #expect(lines.count == 1)
        #expect(lines[0].kind == .context)
        #expect(lines[0].text.isEmpty)
    }

    @Test
    func prefixAndSuffixPreserved_middleReplacement() {
        let old = "keep\nchange me\nalso keep"
        let new = "keep\nchanged\nalso keep"
        let lines = LineDiff.diff(old: old, new: new)
        #expect(lines.first?.kind == .context)
        #expect(lines.first?.text == "keep")
        #expect(lines.last?.kind == .context)
        #expect(lines.last?.text == "also keep")
        #expect(lines.contains { $0.kind == .removed && $0.text == "change me" })
        #expect(lines.contains { $0.kind == .added && $0.text == "changed" })
    }

    @Test
    func trailingInsertion_doesNotDropContext() {
        let lines = LineDiff.diff(old: "a\nb", new: "a\nb\nc")
        #expect(lines.map(\.kind) == [.context, .context, .added])
        #expect(lines.map(\.text) == ["a", "b", "c"])
        #expect(lines[2].newLineNumber == 3)
    }
}
