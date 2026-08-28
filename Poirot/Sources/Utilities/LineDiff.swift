import Foundation

nonisolated struct DiffLine: Identifiable, Equatable {
    let id: Int
    let kind: Kind
    let text: String
    let oldLineNumber: Int?
    let newLineNumber: Int?

    enum Kind: Equatable {
        case context
        case added
        case removed
    }
}

nonisolated enum LineDiff {
    static func diff(old: String, new: String) -> [DiffLine] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        return diff(oldLines: oldLines, newLines: newLines)
    }

    static func diff(oldLines: [String], newLines: [String]) -> [DiffLine] {
        let changes = newLines.difference(from: oldLines)

        // Build lookup of removals and insertions by offset
        var removals: [Int: String] = [:]
        var insertions: [Int: String] = [:]
        for change in changes {
            switch change {
            case let .remove(offset, element, _):
                removals[offset] = element
            case let .insert(offset, element, _):
                insertions[offset] = element
            }
        }

        var result: [DiffLine] = []
        var oldIdx = 0
        var newIdx = 0

        while oldIdx < oldLines.count || newIdx < newLines.count {
            if oldIdx < oldLines.count, let text = removals[oldIdx] {
                result.append(DiffLine(
                    id: result.count,
                    kind: .removed,
                    text: text,
                    oldLineNumber: oldIdx + 1,
                    newLineNumber: nil
                ))
                oldIdx += 1
            } else if newIdx < newLines.count, let text = insertions[newIdx] {
                result.append(DiffLine(
                    id: result.count,
                    kind: .added,
                    text: text,
                    oldLineNumber: nil,
                    newLineNumber: newIdx + 1
                ))
                newIdx += 1
            } else if oldIdx < oldLines.count, newIdx < newLines.count {
                result.append(DiffLine(
                    id: result.count,
                    kind: .context,
                    text: newLines[newIdx],
                    oldLineNumber: oldIdx + 1,
                    newLineNumber: newIdx + 1
                ))
                oldIdx += 1
                newIdx += 1
            } else if oldIdx < oldLines.count {
                result.append(DiffLine(
                    id: result.count,
                    kind: .removed,
                    text: oldLines[oldIdx],
                    oldLineNumber: oldIdx + 1,
                    newLineNumber: nil
                ))
                oldIdx += 1
            } else {
                result.append(DiffLine(
                    id: result.count,
                    kind: .added,
                    text: newLines[newIdx],
                    oldLineNumber: nil,
                    newLineNumber: newIdx + 1
                ))
                newIdx += 1
            }
        }

        return result
    }

    static func unifiedText(from lines: [DiffLine]) -> String {
        lines.map { line in
            switch line.kind {
            case .context: " \(line.text)"
            case .added: "+\(line.text)"
            case .removed: "-\(line.text)"
            }
        }
        .joined(separator: "\n")
    }
}
