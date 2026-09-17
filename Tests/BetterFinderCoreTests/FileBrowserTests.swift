import Foundation
import Testing
@testable import BetterFinderCore

struct FileBrowserTests {
    @Test(arguments: ["kind:image", "KIND:IMAGE", "kind:images", "  kind:image  "])
    func imageTokensFilterByType(query: String) {
        #expect(FileQuery.matches(entry("Photo.HEIC", image: true), text: query, imagesOnly: false))
        #expect(!FileQuery.matches(entry("Photo.txt"), text: query, imagesOnly: false))
    }

    @Test(arguments: ["kind:image holiday", "holiday kind:image", "HOLIDAY kind:images"])
    func imageTokenCombinesWithName(query: String) {
        #expect(FileQuery.matches(entry("Holiday Sunset.png", image: true), text: query, imagesOnly: false))
        #expect(!FileQuery.matches(entry("Portrait.png", image: true), text: query, imagesOnly: false))
        #expect(!FileQuery.matches(entry("Holiday.txt"), text: query, imagesOnly: false))
    }

    @Test func imageToggleIntersectsWithText() {
        #expect(FileQuery.matches(entry("Sunset.png", image: true), text: "SUNSET", imagesOnly: true))
        #expect(!FileQuery.matches(entry("Sunset.txt"), text: "SUNSET", imagesOnly: true))
        #expect(!FileQuery.matches(entry("Portrait.png", image: true), text: "SUNSET", imagesOnly: true))
        #expect(FileQuery.matches(entry("Notes.txt"), text: "", imagesOnly: false))
        #expect(!FileQuery.matches(entry("Notes.txt"), text: "", imagesOnly: true))
    }

    @Test func scanReadsMetadataAndOmitsHiddenEntries() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = folder.appendingPathComponent("Photo.PNG")
        try Data(repeating: 0, count: 123).write(to: image)
        try Data("hello".utf8).write(to: folder.appendingPathComponent("Notes.txt"))
        try Data().write(to: folder.appendingPathComponent(".hidden.png"))
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Child"), withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("Child/Nested.jpg"))

        let result = try FileScanner.scan(folder: folder, recursive: false)
        #expect(Set(result.entries.map(\.name)) == ["Photo.PNG", "Notes.txt", "Child"])
        #expect(result.skippedCount == 0)
        let photo = try #require(result.entries.first { $0.name == "Photo.PNG" })
        #expect(photo.size == 123)
        #expect(photo.isImage)
        #expect(!photo.isDirectory)
        #expect(photo.modified != nil)
        #expect(photo.created != nil)
        #expect(photo.accessed != nil)
        #expect(!photo.kind.isEmpty)
        #expect(photo.id == photo.url)
        let notes = try #require(result.entries.first { $0.name == "Notes.txt" })
        #expect(!notes.isImage)
    }

    @Test func recursiveScanAvoidsHiddenFoldersPackagesAndSymlinkLoops() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        for path in ["Child/Deep", ".Hidden", "Example.app/Contents"] {
            try FileManager.default.createDirectory(at: folder.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        for path in ["Top.png", "Child/Nested.jpg", "Child/Deep/Deep.heic", ".Hidden/Secret.png", "Example.app/Contents/Packaged.png"] {
            try Data().write(to: folder.appendingPathComponent(path))
        }
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("Child/Loop"), withDestinationURL: folder)

        let result = try FileScanner.scan(folder: folder, recursive: true)
        let images = result.entries.filter { FileQuery.matches($0, text: "kind:image", imagesOnly: false) }
        #expect(Set(images.map(\.name)) == ["Top.png", "Nested.jpg", "Deep.heic"])
        #expect(images.count == 3)
        #expect(!result.entries.contains { $0.name == "Secret.png" || $0.name == "Packaged.png" })
    }

    @Test func missingFolderThrows() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(throws: (any Error).self) {
            try FileScanner.scan(folder: missing, recursive: false)
        }
    }

    @Test func filteredResultsRetainNumericAndDateSorting() {
        let entries = [
            entry("Large.png", image: true, size: 10_000, modified: 10),
            entry("Small.png", image: true, size: 9, modified: 30),
            entry("Medium.png", image: true, size: 100, modified: 20),
            entry("Ignored.txt", size: 1, modified: 40)
        ].filter { FileQuery.matches($0, text: "kind:image", imagesOnly: false) }
        #expect(entries.sorted(using: KeyPathComparator(\.size)).map(\.name) == ["Small.png", "Medium.png", "Large.png"])
        #expect(entries.sorted(using: KeyPathComparator(\.modified, order: .reverse)).map(\.name) == ["Small.png", "Medium.png", "Large.png"])
    }

    @Test func treeRetainsMatchingAncestorsAndHonorsExpansion() {
        let root = URL(fileURLWithPath: "/fixture")
        let entries = [
            treeEntry("Trip", directory: true), treeEntry("Trip/Day", directory: true),
            treeEntry("Trip/Day/Photo.png", image: true), treeEntry("Trip/Notes.txt"),
            treeEntry("Empty", directory: true), treeEntry("Top.png", image: true)
        ]
        func rows(_ expanded: Set<URL>) -> [String] {
            FileTree.visibleEntries(entries: entries, root: root, text: "kind:image", imagesOnly: false,
                                    expanded: expanded, sortOrder: [], flattened: false).map(\.name)
        }
        #expect(rows([]) == ["Top.png", "Trip"])
        #expect(rows([root.appendingPathComponent("Trip")]) == ["Top.png", "Trip", "Day"])
        #expect(rows([root.appendingPathComponent("Trip"), root.appendingPathComponent("Trip/Day")]) == ["Top.png", "Trip", "Day", "Photo.png"])
    }

    @Test func treeSortsSiblingsAndUsesNameForTies() {
        let root = URL(fileURLWithPath: "/fixture")
        let entries = [treeEntry("Folder", directory: true, size: 5), treeEntry("Z.png", image: true, size: 5),
                       treeEntry("A.png", image: true, size: 5), treeEntry("Folder/Large.png", image: true, size: 100),
                       treeEntry("Folder/Small.png", image: true, size: 1)]
        let rows = FileTree.visibleEntries(entries: entries, root: root, text: "", imagesOnly: false,
                                           expanded: [root.appendingPathComponent("Folder")],
                                           sortOrder: [KeyPathComparator(\.size)], flattened: false)
        #expect(rows.map(\.name) == ["A.png", "Folder", "Small.png", "Large.png", "Z.png"])
    }

    @Test func flattenedTreeOmitsAncestorsAndSortsAllMatches() {
        let entries = [treeEntry("Folder", directory: true), treeEntry("Folder/Small.png", image: true, size: 1),
                       treeEntry("Large.png", image: true, size: 100), treeEntry("Notes.txt")]
        let rows = FileTree.visibleEntries(entries: entries, root: URL(fileURLWithPath: "/fixture"), text: "", imagesOnly: true,
                                           expanded: [], sortOrder: [KeyPathComparator(\.size, order: .reverse)], flattened: true)
        #expect(rows.map(\.name) == ["Large.png", "Small.png"])
    }

    @Test func treeRejectsEntriesOutsideRootAndCannotInventMissingAncestors() {
        let entries = [treeEntry("Visible.png", image: true), treeEntry("Missing/Orphan.png", image: true),
                       treeEntry("../fixture-other/Outside.png", image: true)]
        let rows = FileTree.visibleEntries(entries: entries, root: URL(fileURLWithPath: "/fixture"), text: "", imagesOnly: false,
                                           expanded: [], sortOrder: [], flattened: false)
        #expect(rows.map(\.name) == ["Visible.png"])
    }

    private func treeEntry(_ path: String, directory: Bool = false, image: Bool = false, size: Int64 = 0) -> FileEntry {
        let url = URL(fileURLWithPath: "/fixture/\(path)")
        return FileEntry(url: url, name: url.lastPathComponent, size: size, modified: nil, accessed: nil, created: nil,
                         kind: directory ? "Folder" : "File", isDirectory: directory, isImage: image)
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BetterFinderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func entry(_ name: String, image: Bool = false, size: Int64 = 0, modified: TimeInterval = 0) -> FileEntry {
        FileEntry(
            url: URL(fileURLWithPath: "/fixture/\(name)"), name: name, size: size,
            modified: Date(timeIntervalSince1970: modified), accessed: nil, created: nil,
            kind: image ? "Image" : "Document", isDirectory: false, isImage: image
        )
    }
}
