import Foundation
import UniformTypeIdentifiers

public struct FileEntry: Identifiable, Sendable {
    public var id: URL { url }
    public var modifiedSort: Date { modified ?? .distantPast }
    public var accessedSort: Date { accessed ?? .distantPast }
    public var createdSort: Date { created ?? .distantPast }
    public var addedSort: Date { added ?? .distantPast }
    public let url: URL
    public let name: String
    public let size: Int64
    public let modified: Date?
    public let accessed: Date?
    public let created: Date?
    public let added: Date?
    public let kind: String
    public let isDirectory: Bool
    public let isImage: Bool

    public init(url: URL, name: String, size: Int64, modified: Date?, accessed: Date?, created: Date?, kind: String, isDirectory: Bool, isImage: Bool, added: Date? = nil) {
        self.url = url
        self.name = name
        self.size = size
        self.modified = modified
        self.accessed = accessed
        self.created = created
        self.added = added
        self.kind = kind
        self.isDirectory = isDirectory
        self.isImage = isImage
    }
}

public enum FileQuery {
    public static func matches(_ entry: FileEntry, text: String, imagesOnly: Bool) -> Bool {
        let tokens = text.split(whereSeparator: \.isWhitespace)
        let imageTokens = ["kind:image", "kind:images"]
        let requiresImage = imagesOnly || tokens.contains { imageTokens.contains($0.lowercased()) }
        let nameQuery = tokens.filter { !imageTokens.contains($0.lowercased()) }.joined(separator: " ")
        return (!requiresImage || entry.isImage) && (nameQuery.isEmpty || entry.name.localizedStandardContains(nameQuery))
    }
}

public struct ScanResult: Sendable {
    public let entries: [FileEntry]
    public let skippedCount: Int
}

public enum FileScanner {
    private static let keys: Set<URLResourceKey> = [
        .nameKey, .fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey,
        .contentModificationDateKey,
        .contentAccessDateKey, .creationDateKey, .addedToDirectoryDateKey
    ]

    // Explicitly execute synchronous filesystem work outside the UI actor.
    @concurrent public static func scanAsync(folder: URL, recursive: Bool) async throws -> ScanResult {
        try scan(folder: folder, recursive: recursive)
    }

    public static func scan(folder: URL, recursive: Bool) throws -> ScanResult {
        let manager = FileManager.default
        var entries: [FileEntry] = []
        var skipped = 0
        func append(_ url: URL) throws {
            try Task.checkCancellation()
            do {
                let values = try url.resourceValues(forKeys: keys)
                let typeValues = try? url.resourceValues(forKeys: [.contentTypeKey, .localizedTypeDescriptionKey])
                let contentType = typeValues?.contentType ?? UTType(filenameExtension: url.pathExtension)
                let directory = values.isDirectory == true && values.isPackage != true
                entries.append(FileEntry(
                    url: url, name: values.name ?? url.lastPathComponent,
                    size: Int64(values.fileSize ?? 0), modified: values.contentModificationDate,
                    accessed: values.contentAccessDate, created: values.creationDate,
                    kind: directory ? "Folder" : (typeValues?.localizedTypeDescription ?? contentType?.localizedDescription ?? "File"),
                    isDirectory: directory, isImage: !directory && contentType?.conforms(to: .image) == true,
                    added: values.addedToDirectoryDate
                ))
            } catch { skipped += 1 }
        }
        // Validate the root explicitly; enumerators otherwise silently fail on denied access.
        let children = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        if recursive {
            guard let enumerator = manager.enumerator(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in
                skipped += 1
                return true
            }) else { throw CocoaError(.fileReadUnknown) }
            for case let url as URL in enumerator {
                if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                    enumerator.skipDescendants()
                }
                try append(url)
            }
        } else {
            for url in children { try append(url) }
        }
        return ScanResult(entries: entries, skippedCount: skipped)
    }
}
