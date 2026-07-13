import SwiftUI

enum HighlightedText {
    // MARK: - Exact substring highlighting

    static func attributedString(_ text: String, query: String) -> AttributedString {
        var result = AttributedString(text)
        guard !query.isEmpty else { return result }

        var searchStart = result.startIndex
        while searchStart < result.endIndex {
            guard let range = result[searchStart ..< result.endIndex].range(of: query, options: .caseInsensitive)
            else { break }
            result[range].backgroundColor = PoirotTheme.Colors.accent.opacity(0.35)
            result[range].foregroundColor = .white
            searchStart = range.upperBound
        }
        return result
    }

    // MARK: - Exact substring matching

    /// Case-insensitive substring match, scored for ranking. Returns `nil` when `query` isn't
    /// contained in `text`. This is the "Match Word" counterpart to `fuzzyMatch` — no scattered
    /// subsequence hits, so searching `ssh` won't drag in "se**ss**ion" or "swiftUI s**h**ell".
    /// Higher scores for a match at the start or just after a word boundary.
    static func substringMatch(_ text: String, query: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let lower = text.lowercased()
        let qLower = query.lowercased()
        guard let range = lower.range(of: qLower) else { return nil }

        var score = 100
        if range.lowerBound == lower.startIndex {
            score += 40
        } else {
            let before = lower.index(before: range.lowerBound)
            let boundaries: Set<Character> = [" ", "-", "/", ".", "_", ":"]
            if boundaries.contains(lower[before]) { score += 20 }
        }
        // Nudge shorter hosts ahead — a hit in a tight title beats one buried in a large blob.
        score -= min(lower.count / 20, 30)
        return score
    }

    // MARK: - Fuzzy matching

    struct FuzzyResult {
        let indices: [String.Index]
        let score: Int
    }

    /// Fuzzy-matches `query` against `text`. Returns matched indices and a score (higher is better).
    ///
    /// Short queries (< 2 chars) fall back to exact substring matching.
    ///
    /// Scoring:
    /// - +10 per matched character
    /// - +5 bonus for consecutive matches
    /// - +8 bonus for matching at the start of the string
    /// - +3 bonus for matching after a word boundary (space, dash, slash, dot, underscore)
    /// - -1 penalty per gap character between matches
    ///
    /// Matches below a minimum score threshold (query length x 5) are rejected to avoid noisy scattered matches.
    static func fuzzyMatch(_ text: String, query: String) -> FuzzyResult? {
        guard !query.isEmpty else { return FuzzyResult(indices: [], score: 0) }

        // Single character: require exact substring, not fuzzy
        if query.count < 2 {
            let lower = text.lowercased()
            let qLower = query.lowercased()
            guard let range = lower.range(of: qLower) else { return nil }
            return FuzzyResult(indices: [range.lowerBound], score: 10)
        }

        let textLower = text.lowercased()
        let queryLower = query.lowercased()

        var matchedIndices: [String.Index] = []
        var textIndex = textLower.startIndex
        var queryIndex = queryLower.startIndex
        var score = 0
        var previousMatchIndex: String.Index?

        while textIndex < textLower.endIndex, queryIndex < queryLower.endIndex {
            if textLower[textIndex] == queryLower[queryIndex] {
                matchedIndices.append(textIndex)
                score += 10

                if textIndex == textLower.startIndex {
                    score += 8
                } else if let prev = previousMatchIndex, textLower.index(after: prev) == textIndex {
                    score += 5
                } else {
                    let before = textLower.index(before: textIndex)
                    let separators: Set<Character> = [" ", "-", "/", ".", "_"]
                    if separators.contains(textLower[before]) {
                        score += 3
                    }
                }

                if let prev = previousMatchIndex {
                    let gap = textLower.distance(from: prev, to: textIndex) - 1
                    score -= gap
                }

                previousMatchIndex = textIndex
                queryIndex = queryLower.index(after: queryIndex)
            }
            textIndex = textLower.index(after: textIndex)
        }

        guard queryIndex == queryLower.endIndex else { return nil }

        // Reject weak scattered matches: require at least 5 points per query character
        let minScore = query.count * 5
        guard score >= minScore else { return nil }

        return FuzzyResult(indices: matchedIndices, score: score)
    }

    /// Best fuzzy score for a project: max of project name score and all session title scores.
    static func bestScore(projectName: String, sessionTitles: [String], query: String) -> Int {
        var best = fuzzyMatch(projectName, query: query)?.score ?? Int.min
        for title in sessionTitles {
            if let result = fuzzyMatch(title, query: query) {
                best = max(best, result.score)
            }
        }
        return best
    }

    /// Highlights individual fuzzy-matched characters.
    static func fuzzyAttributedString(_ text: String, query: String) -> AttributedString {
        var result = AttributedString(text)
        guard let match = fuzzyMatch(text, query: query), !match.indices.isEmpty else {
            return result
        }

        for textIndex in match.indices {
            let offset = text.distance(from: text.startIndex, to: textIndex)
            let attrStart = result.index(result.startIndex, offsetByCharacters: offset)
            let attrEnd = result.index(attrStart, offsetByCharacters: 1)
            result[attrStart ..< attrEnd].backgroundColor = PoirotTheme.Colors.accent.opacity(0.35)
            result[attrStart ..< attrEnd].foregroundColor = .white
        }
        return result
    }
}
