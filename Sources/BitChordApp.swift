import SwiftUI

@available(iOS 13.0, macOS 10.15, *)
@main
struct BitChordApp: App {
    @StateObject private var audioManager = AudioPlaybackManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioManager)
        }
        .backgroundTask(.appRefresh("com.bitchord.refresh")) {
            // Background refresh handling
        }
    }
}
