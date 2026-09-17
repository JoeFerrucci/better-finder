# Better Finder

Native macOS file browser for filtering images without losing sortable metadata.

## Run

Requires macOS 15+ and Xcode 26 / Swift 6.2.

```sh
./scripts/build-app.sh
open "build/Better Finder.app"
```

Open `Package.swift` in Xcode for development. The local app is ad-hoc signed, not notarized or sandboxed. macOS may request Downloads, Desktop, or Documents access.

## Install

After building, quit Better Finder if running, then copy it to your user Applications folder:

```sh
mkdir -p "$HOME/Applications"
ditto "build/Better Finder.app" "$HOME/Applications/Better Finder.app"
open "$HOME/Applications/Better Finder.app"
```

To update, quit the installed app, rebuild, and repeat the copy. No Xcode is needed to run the built app on a compatible Mac; this build targets the machine's architecture.

## Browse

- Starts in Downloads with Images selected. Switch to All Files as needed.
- Search filenames, `kind:image`, or both. Matching nested files retain their ancestor folders.
- Click column headers to sort Name, Size, Date Added, Date Modified, Date Accessed, Date Created, or Kind. Click again to reverse.
- Expand folders inline with disclosure arrows. Flatten subfolders for one globally sorted result list.
- Switch between List and Icons. The thumbnail slider adjusts both modes (list thumbnails capped at 100 points).
- List: ↑/↓ selects, → expands or selects first child, ← collapses or selects parent, ⌘↓ opens, ⌘↑ goes to enclosing folder, Space previews.
- Icons: arrow keys move between rows and columns, Return opens, Space previews.
- Double-click opens files in their default app or navigates into folders. Right-click for Quick Look, opening, and Reveal in Finder.
- ⌘R refreshes; ⇧⌘O chooses a folder.

## Scope and metadata

Scans include nested folders; hidden items, package contents, and symlink descendants are excluded. Folder sizes are not recursively totaled. Access dates are filesystem metadata, not Finder's Spotlight “Date Last Opened”; macOS may not update them on every read. Missing dates show a dash and sort first ascending. Thumbnails use Quick Look and fall back to file icons.

Refresh is manual. This first version focuses on browsing: no rename, move, copy, or deletion operations. Large directory trees may take time to scan; scanning is cancellable and runs off the UI thread.

## Tests

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift test --disable-sandbox
```

Tests cover actual filesystem metadata, filtering, recursive traversal exclusions, numeric/date sorting, and retained folder hierarchy.
