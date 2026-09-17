import AppKit
import SwiftUI
import QuickLook
import QuickLookThumbnailing
import BetterFinderCore

struct BrowserView: View {
    @State private var model = BrowserModel()
    @State private var gridWidth = 1000.0
    private let home = FileManager.default.homeDirectoryForCurrentUser

    private var loadID: String { "\(model.folder.path)|\(model.revision)" }

    var body: some View {
        NavigationSplitView {
            List {
                Section("Favorites") {
                    location("Downloads", icon: "arrow.down.circle", url: home.appending(path: "Downloads"))
                    location("Desktop", icon: "desktopcomputer", url: home.appending(path: "Desktop"))
                    location("Documents", icon: "doc", url: home.appending(path: "Documents"))
                    location("Pictures", icon: "photo", url: home.appending(path: "Pictures"))
                    location(home.lastPathComponent, icon: "house", url: home)
                }
                Section {
                    Button("Choose Folder…", systemImage: "folder.badge.plus") { model.chooseFolder() }
                        .keyboardShortcut("o", modifiers: [.command, .shift])
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 260)
        } detail: {
            VStack(spacing: 0) {
                filterBar
                Divider()
                if model.iconMode { iconGrid } else { fileTable }
                Divider()
                statusBar
            }
            .navigationTitle(model.folder.lastPathComponent)
            .navigationSubtitle("Better Finder")
            .searchable(text: $model.query, prompt: "Name or kind:image")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Back", systemImage: "chevron.left") { model.back() }
                        .disabled(!model.canGoBack)
                    Button("Enclosing Folder", systemImage: "arrow.up") { model.navigate(model.folder.deletingLastPathComponent()) }
                        .keyboardShortcut(.upArrow, modifiers: .command)
                        .disabled(model.folder.path == "/")
                }
                ToolbarItemGroup {
                    Button("Quick Look", systemImage: "eye") { model.preview = model.selectedEntry?.url }
                        .disabled(model.selectedEntry == nil)
                    Button("Refresh", systemImage: "arrow.clockwise") { model.revision += 1 }
                        .keyboardShortcut("r", modifiers: .command)
                }
            }
        }
        .task(id: loadID) { await model.load() }
        .quickLookPreview($model.preview)
        .onChange(of: model.query) { pruneSelection() }
        .onChange(of: model.imagesOnly) { pruneSelection() }
    }

    private var filterBar: some View {
        HStack(spacing: 16) {
            Picker("File type", selection: $model.imagesOnly) {
                Text("All Files").tag(false)
                Label("Images", systemImage: "photo").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden()
            .frame(width: 190)
            Toggle("Flatten subfolders", isOn: $model.flattened)
                .toggleStyle(.checkbox)
            Picker("View", selection: $model.iconMode) {
                Image(systemName: "list.bullet").tag(false)
                Image(systemName: "square.grid.2x2").tag(true)
            }.pickerStyle(.segmented).labelsHidden().frame(width: 80)
            Image(systemName: "photo").foregroundStyle(.secondary)
            Slider(value: $model.thumbnailSize, in: 32...220)
                .frame(width: 110).accessibilityLabel("Thumbnail size")
            Spacer()
            if model.iconMode { sortMenu.frame(width: 110) }
            else { Text("Click columns to sort").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var fileTable: some View {
        Table(model.visible, selection: $model.selection, sortOrder: $model.sortOrder) {
            TableColumn("Name", value: \.name, comparator: .localizedStandard) { entry in
                HStack(spacing: 8) {
                    if !model.flattened {
                        Color.clear.frame(width: CGFloat(depth(entry)) * 16)
                        if entry.isDirectory {
                            Button { model.toggleExpanded(entry) } label: {
                                Image(systemName: model.expanded.contains(entry.url) ? "chevron.down" : "chevron.right")
                            }.buttonStyle(.plain).accessibilityLabel("Expand or collapse \(entry.name)")
                        }
                    }
                    FileThumbnail(entry: entry, size: min(model.thumbnailSize, 100))
                    Text(entry.name).lineLimit(1)
                }
                .help(entry.url.path)
            }.width(min: 220, ideal: 300)
            TableColumn("Size", value: \.size) { entry in
                Text(entry.isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                    .monospacedDigit()
            }.width(min: 75, ideal: 90)
            TableColumn("Date Added", value: \.addedSort) { entry in date(entry.added) }
                .width(min: 145, ideal: 160)
            TableColumn("Date Modified", value: \.modifiedSort) { entry in date(entry.modified) }
                .width(min: 145, ideal: 160)
            TableColumn("Date Accessed", value: \.accessedSort) { entry in date(entry.accessed) }
                .width(min: 145, ideal: 160)
            TableColumn("Date Created", value: \.createdSort) { entry in date(entry.created) }
                .width(min: 145, ideal: 160)
            TableColumn("Kind", value: \.kind) { entry in Text(entry.kind) }
                .width(min: 100, ideal: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: URL.self) { ids in
            if let entry = model.entries.first(where: { ids.contains($0.id) }) {
                Button("Open") { model.open(entry) }
                Button("Quick Look") { model.preview = entry.url }
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting(Array(ids)) }
                Button("Copy Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(ids.map(\.path).sorted().joined(separator: "\n"), forType: .string)
                }
            }
        } primaryAction: { ids in
            if let entry = model.entries.first(where: { ids.contains($0.id) }) { model.open(entry) }
        }
        .onKeyPress(.rightArrow) {
            guard !model.flattened else { return .ignored }
            model.expandSelection()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard !model.flattened else { return .ignored }
            model.collapseSelection()
            return .handled
        }
        .onKeyPress(.downArrow, phases: .down) { press in
            guard press.modifiers.contains(.command), let entry = model.selectedEntry else { return .ignored }
            model.open(entry)
            return .handled
        }
        .onKeyPress(.space) {
            guard let entry = model.selectedEntry else { return .ignored }
            model.preview = entry.url
            return .handled
        }
        .overlay {
            if model.loading { ProgressView("Reading folder…").padding(24).background(.regularMaterial, in: .rect(cornerRadius: 12)) }
            else if let error = model.error {
                ContentUnavailableView {
                    Label("Folder unavailable", systemImage: "folder.badge.questionmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Choose Folder…") { model.chooseFolder() }
                    Button("Retry") { model.revision += 1 }
                }
            } else if model.visible.isEmpty {
                ContentUnavailableView("No matching files", systemImage: "doc.text.magnifyingglass", description: Text("Try All Files, clear the search, or expand a folder."))
            }
        }
    }

    private var sortMenu: some View {
        Menu("Sort") {
            Button("Name") { model.sortOrder = [KeyPathComparator(\FileEntry.name, comparator: .localizedStandard)] }
            Button("Size") { model.sortOrder = [KeyPathComparator(\FileEntry.size, order: .reverse)] }
            Button("Date Added") { model.sortOrder = [KeyPathComparator(\FileEntry.addedSort, order: .reverse)] }
            Button("Date Modified") { model.sortOrder = [KeyPathComparator(\FileEntry.modifiedSort, order: .reverse)] }
            Button("Date Accessed") { model.sortOrder = [KeyPathComparator(\FileEntry.accessedSort, order: .reverse)] }
            Button("Date Created") { model.sortOrder = [KeyPathComparator(\FileEntry.createdSort, order: .reverse)] }
            Button("Kind") { model.sortOrder = [KeyPathComparator(\FileEntry.kind)] }
            Divider()
            Button("Reverse Order") {
                model.sortOrder = model.sortOrder.map { comparator in
                    var copy = comparator
                    copy.order = copy.order == .forward ? .reverse : .forward
                    return copy
                }
            }
        }
    }

    private var iconGrid: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: model.thumbnailSize + 40), spacing: 16)], spacing: 18) {
                ForEach(model.visible) { entry in
                    VStack(spacing: 6) {
                        FileThumbnail(entry: entry, size: model.thumbnailSize)
                        Text(entry.name).lineLimit(2).multilineTextAlignment(.center)
                        Text(entry.isDirectory ? "Folder" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10).frame(maxWidth: .infinity)
                    .id(entry.id)
                    .background(model.selection.contains(entry.id) ? Color.accentColor.opacity(0.2) : Color.clear, in: .rect(cornerRadius: 8))
                    .contentShape(.rect)
                    .onTapGesture(count: 2) { model.open(entry) }
                    .onTapGesture { model.selection = [entry.id] }
                    .contextMenu {
                        Button("Open") { model.open(entry) }
                        Button("Quick Look") { model.preview = entry.url }
                        if entry.isDirectory { Button("Expand / Collapse") { model.toggleExpanded(entry) } }
                        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { model.open(entry) }
                }
            }.padding(20)
        }
        .onGeometryChange(for: Double.self) { $0.size.width } action: { gridWidth = $0 }
        .onChange(of: model.selection) {
            if let selected = model.selectedEntry { proxy.scrollTo(selected.id) }
        }
        .focusable()
        .onKeyPress(.space) {
            guard let entry = model.selectedEntry else { return .ignored }
            model.preview = entry.url
            return .handled
        }
        .onKeyPress(.return) {
            guard let entry = model.selectedEntry else { return .ignored }
            model.open(entry)
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
            let files = model.visible
            guard !files.isEmpty else { return .ignored }
            let index = files.firstIndex { model.selection.contains($0.id) } ?? -1
            let columns = max(1, Int((gridWidth - 40 + 16) / (model.thumbnailSize + 40 + 16)))
            let delta = press.key == .upArrow ? -columns : press.key == .downArrow ? columns : press.key == .leftArrow ? -1 : 1
            model.selection = [files[max(0, min(files.count - 1, index + delta))].id]
            return .handled
        }
        .overlay {
            if model.loading { ProgressView("Reading folder…") }
            else if let error = model.error { ContentUnavailableView("Folder unavailable", systemImage: "folder.badge.questionmark", description: Text(error)) }
            else if model.visible.isEmpty { ContentUnavailableView("No matching files", systemImage: "photo", description: Text("Try All Files or clear the search.")) }
        }
    }

    }

    private func depth(_ entry: FileEntry) -> Int {
        max(0, entry.url.pathComponents.count - model.folder.pathComponents.count - 1)
    }

    private var statusBar: some View {
        HStack {
            Image(systemName: "folder")
            Text(model.folder.path).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
            Spacer()
            Text("\(model.matchingCount) matches · \(model.visible.count) visible")
            if !model.selection.isEmpty { Text("· \(model.selection.count) selected") }
            if model.skipped > 0 { Text("· \(model.skipped) unreadable").foregroundStyle(.orange) }
        }
        .font(.caption).foregroundStyle(.secondary).padding(10)
    }

    private func location(_ title: String, icon: String, url: URL) -> some View {
        Button { model.navigate(url) } label: {
            Label(title, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .listRowBackground(model.folder == url ? Color.accentColor.opacity(0.16) : Color.clear)
    }
    private func date(_ value: Date?) -> some View {
        Text(value?.formatted(date: .numeric, time: .shortened) ?? "—")
            .foregroundStyle(.secondary).monospacedDigit()
    }
    private func pruneSelection() { model.selection.formIntersection(Set(model.visible.map(\.id))) }
}
