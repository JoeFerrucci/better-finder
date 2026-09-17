# Better Finder

- [x] Native macOS 15+ SwiftUI app; Downloads default.
- [x] Persistent sortable metadata columns and kind:image filtering.
- [x] Inline hierarchy, ancestor retention, arrow-key navigation.
- [x] List / Icons modes and adjustable thumbnails; no Gallery.
- [x] Opening, Quick Look, folder selection, refresh.
- [x] Test filtering, metadata, sorting and hierarchy.
- [x] Build, launch and inspect UI.

Unresolved questions: none.

## Review
Verified: release build and app signature valid; 11 Swift Testing tests pass outside the tool sandbox (LaunchServices type registry unavailable inside). Live UI verified Downloads loading, kind:image plus filename filtering, size sorting, inline right-arrow expansion, Icons view, and thumbnail resizing. Final toolbar layout inspected. App left running. Folder scans run off the main actor. Missing dates display as dashes; sort before available dates ascending. Recursive scans skip hidden files, packages and symlink traversal.
