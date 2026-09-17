import AppKit
import BetterFinderCore
import Observation

@MainActor @Observable
final class BrowserModel {
    var folder = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads")
    var query = ""
    var imagesOnly = true
    var flattened = false
    var expanded: Set<URL> = []
    var iconMode = false
    var thumbnailSize = 64.0
    var entries: [FileEntry] = []
    var selection: Set<URL> = []
    var sortOrder = [KeyPathComparator(\FileEntry.modifiedSort, order: .reverse)]
    var loading = false
    var error: String?
    var skipped = 0
    var preview: URL?
    var revision = 0
    private var history: [URL] = []
    var canGoBack: Bool { !history.isEmpty }
    var visible: [FileEntry] {
        FileTree.visibleEntries(entries: entries, root: folder, text: query, imagesOnly: imagesOnly,
                                expanded: expanded, sortOrder: sortOrder, flattened: flattened)
    }
    var matchingCount: Int { entries.filter { FileQuery.matches($0, text: query, imagesOnly: imagesOnly) }.count }
    func toggleExpanded(_ entry: FileEntry) {
        if expanded.contains(entry.url) { expanded.remove(entry.url) }
        else { expanded.insert(entry.url) }
        selection.formIntersection(Set(visible.map(\.id)))
    }
    func expandSelection() {
        guard let entry = selectedEntry, entry.isDirectory else { return }
        if expanded.contains(entry.url), let child = visible.first(where: { $0.url.deletingLastPathComponent() == entry.url }) {
            selection = [child.id]
        } else { expanded.insert(entry.url) }
    }
    func collapseSelection() {
        guard let entry = selectedEntry else { return }
        if expanded.contains(entry.url) { expanded.remove(entry.url) }
        else {
            let parent = entry.url.deletingLastPathComponent()
            if visible.contains(where: { $0.id == parent }) { selection = [parent] }
        }
    }

    var selectedEntry: FileEntry? { visible.first { selection.contains($0.id) } }

    func navigate(_ url: URL) {
        guard url != folder else { return }
        history.append(folder)
        folder = url
        selection = []
        preview = nil
    }
    func back() {
        guard let previous = history.popLast() else { return }
        folder = previous
        selection = []
        preview = nil
    }
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { navigate(url) }
    }
    func open(_ entry: FileEntry) {
        if entry.isDirectory { navigate(entry.url) }
        else if !NSWorkspace.shared.open(entry.url) { error = "Could not open \(entry.name)." }
    }
    func load() async {
        let requestedFolder = folder
        loading = true
        error = nil
        entries = []
        skipped = 0
        selection = []
        do {
            let result = try await FileScanner.scanAsync(folder: requestedFolder, recursive: true)
            try Task.checkCancellation()
            entries = result.entries
            skipped = result.skippedCount
            loading = false
        } catch is CancellationError {
            // A newer .task owns the loading state.
        } catch {
            guard !Task.isCancelled else { return }
            self.error = "Cannot read \(requestedFolder.path): \(error.localizedDescription)"
            loading = false
        }
    }
}
