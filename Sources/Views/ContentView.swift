import SwiftUI

/// Main shell: persistent tab navigation with a floating mini-player at the bottom.
@available(iOS 17.0, macOS 14.0, *)
struct ContentView: View {
    @EnvironmentObject private var audioManager: AudioPlaybackManager
    @State private var selectedTab: Tab = .home
    @State private var showFullPlayer = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(Tab.home)
                    .tabItem { Label("Home", systemImage: "house.fill") }

                SearchView()
                    .tag(Tab.search)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }

                LibraryView()
                    .tag(Tab.library)
                    .tabItem { Label("Library", systemImage: "music.note.list") }
            }
            .tint(.red)
            .overlay(alignment: .top) {
                if audioManager.currentTrack != nil {
                    Color.clear
                }
            }

            // Persistent floating mini-player at the bottom.
            VStack {
                Spacer()
                if audioManager.currentTrack != nil {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                        .onTapGesture {
                            showFullPlayer = true
                        }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: audioManager.currentTrack != nil)

            // Full-screen player sheet.
            if showFullPlayer {
                FullPlayerView(showFullPlayer: $showFullPlayer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private enum Tab: String, CaseIterable {
    case home, search, library
}

#Preview("Content") {
    ContentView()
        .environmentObject(AudioPlaybackManager.shared)
}
