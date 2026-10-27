import SwiftUI

#if os(iOS)
@available(iOS 17.0, *)
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
#else
@main
struct BitChordApp: App {
    var body: some Scene {
        WindowGroup {
            Text("BitChord is iOS-only")
        }
    }
}
#endif
