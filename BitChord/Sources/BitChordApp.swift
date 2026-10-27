import SwiftUI

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
