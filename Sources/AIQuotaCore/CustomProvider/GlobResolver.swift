import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Resolves a small glob syntax for `providers.json`'s `logGlob` field — enough for patterns like
/// `~/.glm/sessions/**/*.jsonl` (recursive) or `~/.glm/*.jsonl` (single directory). Not a general
/// glob engine: only one `**` segment is supported, which covers every real CLI log layout we've
/// seen (Claude Code, Codex, and any imitator of that convention).
enum GlobResolver {
    static func resolve(_ pattern: String) -> [URL] {
        let expanded = (pattern as NSString).expandingTildeInPath

        if let range = expanded.range(of: "**") {
            var prefix = String(expanded[expanded.startIndex..<range.lowerBound])
            if prefix.hasSuffix("/") { prefix.removeLast() }

            var suffix = String(expanded[range.upperBound...])
            if suffix.hasPrefix("/") { suffix.removeFirst() }

            return recursiveMatch(baseDir: prefix, suffixPattern: suffix)
        }

        let nsPath = expanded as NSString
        return singleLevelMatch(dir: nsPath.deletingLastPathComponent, pattern: nsPath.lastPathComponent)
    }

    private static func recursiveMatch(baseDir: String, suffixPattern: String) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: baseDir),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let url as URL in enumerator where fnmatch(suffixPattern, url.lastPathComponent, 0) == 0 {
            results.append(url)
        }
        return results
    }

    private static func singleLevelMatch(dir: String, pattern: String) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        return contents
            .filter { fnmatch(pattern, $0, 0) == 0 }
            .map { URL(fileURLWithPath: dir).appendingPathComponent($0) }
    }
}
