import SwiftUI

@main
struct BetterFinderApp: App {
    var body: some Scene {
        WindowGroup("Better Finder") {
            BrowserView()
                .frame(minWidth: 1000, minHeight: 500)
        }
        .defaultSize(width: 1440, height: 850)
    }
}
