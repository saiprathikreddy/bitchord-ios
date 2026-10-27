import SwiftUI

/// Home tab: recommendations, trending tracks, quick picks.
struct HomeView: View {
    @EnvironmentObject private var audioManager: AudioPlaybackManager
    @StateObject private var client = YouTubeMusicClient()

    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                // Header.
                HStack {
                    Text("For You")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Quick picks / recommendations section.
                sectionHeader("Quick Picks")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(tracks.prefix(6)) { track in
                            QuickPickCard(track: track) {
                                Task {
                                    try? await audioManager.play(track: track)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Trending section.
                sectionHeader("Trending")
                LazyVStack(spacing: 8) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRowView(track: track) {
                            Task {
                                try? await audioManager.play(track: track)
                            }
                        }
                        .padding(.horizontal, 20)
                        Divider().padding(.leading, 78)
                    }
                }

                if isLoading {
                    ProgressView()
                        .padding(.top, 20)
                }

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 100)
            }
        }
        .task(id: client) {
            await loadInitial()
        }
        .refreshable {
            await loadInitial()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func loadInitial() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await client.search(query: "popular music", filter: .songs)
            self.tracks = result.tracks
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Single quick-pick card.
private struct QuickPickCard: View {
    let track: Track
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncArtwork(url: track.artworkURL, size: 150, cornerRadius: 16)
            Text(track.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(track.artist.name)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 150)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
    }
}

#Preview("Home") {
    HomeView()
        .environmentObject(AudioPlaybackManager.shared)
}
