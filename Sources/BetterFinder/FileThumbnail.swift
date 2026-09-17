import AppKit
import SwiftUI
import QuickLookThumbnailing
import BetterFinderCore

@MainActor
private enum ThumbnailCache {
    static let images: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 400
        cache.totalCostLimit = 80 * 1024 * 1024
        return cache
    }()
}

struct FileThumbnail: View {
    let entry: FileEntry
    let size: Double
    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? NSWorkspace.shared.icon(forFile: entry.url.path))
            .resizable().aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            .task(id: entry.url) {
                guard entry.isImage else { return }
                if let cached = ThumbnailCache.images.object(forKey: entry.url as NSURL) {
                    thumbnail = cached
                    return
                }
                let request = QLThumbnailGenerator.Request(fileAt: entry.url, size: CGSize(width: 440, height: 440), scale: 1, representationTypes: .thumbnail)
                do {
                    let result = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                    try Task.checkCancellation()
                    thumbnail = result.nsImage
                    ThumbnailCache.images.setObject(result.nsImage, forKey: entry.url as NSURL, cost: 440 * 440 * 4)
                } catch { /* File icons remain available when a preview cannot be generated. */ }
            }
    }
}
