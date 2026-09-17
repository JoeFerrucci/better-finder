import Foundation

public enum FileTree {
    /// Builds rows from scanned metadata without performing filesystem traversal.
    public static func visibleEntries(
        entries: [FileEntry], root: URL, text: String, imagesOnly: Bool,
        expanded: Set<URL>, sortOrder: [KeyPathComparator<FileEntry>], flattened: Bool
    ) -> [FileEntry] {
        let rootPath = root.standardizedFileURL.path
        let prefix = rootPath == "/" ? "/" : rootPath + "/"
        let scoped = entries.filter {
            let path = $0.url.standardizedFileURL.path
            return path != rootPath && path.hasPrefix(prefix)
        }
        let order = sortOrder + [KeyPathComparator(\FileEntry.name)]
        func sorted(_ values: [FileEntry]) -> [FileEntry] {
            values.sorted {
                for comparator in order {
                    let result = comparator.compare($0, $1)
                    if result != .orderedSame { return result == .orderedAscending }
                }
                return $0.url.path < $1.url.path
            }
        }
        let matches = scoped.filter { FileQuery.matches($0, text: text, imagesOnly: imagesOnly) }
        if flattened { return sorted(matches) }

        let byPath = Dictionary(scoped.map { ($0.url.standardizedFileURL.path, $0) }, uniquingKeysWith: { first, _ in first })
        var retained = Set<String>()
        for entry in matches {
            retained.insert(entry.url.standardizedFileURL.path)
            var parent = entry.url.standardizedFileURL.deletingLastPathComponent()
            while parent.path != rootPath && parent.path.hasPrefix(prefix) {
                if byPath[parent.path]?.isDirectory == true { retained.insert(parent.path) }
                let next = parent.deletingLastPathComponent()
                if next.path == parent.path { break }
                parent = next
            }
        }
        let children = Dictionary(grouping: byPath.values.filter { retained.contains($0.url.standardizedFileURL.path) }) {
            $0.url.standardizedFileURL.deletingLastPathComponent().path
        }
        let expandedPaths = Set(expanded.map { $0.standardizedFileURL.path })
        var pending = Array(sorted(children[rootPath] ?? []).reversed())
        var result: [FileEntry] = []
        while let entry = pending.popLast() {
            result.append(entry)
            let path = entry.url.standardizedFileURL.path
            if entry.isDirectory && expandedPaths.contains(path) {
                pending.append(contentsOf: sorted(children[path] ?? []).reversed())
            }
        }
        return result
    }
}
