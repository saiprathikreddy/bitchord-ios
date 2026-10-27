import SwiftUI

/// Library tab: user playlists and recently played.
struct LibraryView: View {
    @EnvironmentObject private var audioManager: AudioPlaybackManager

    var body: some View {
        NavigationStack {
            List {
                Section("Playlists") {
                    ForEach(libraryPlaylists) { playlist in
                        PlaylistRow(playlist: playlist)
                    }
                }

                Section("Recently Played") {
                    ForEach(recentlyPlayed) { track in
                        TrackRowView(track: track) {
                            Task {
                                try? await audioManager.play(track: track)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // Mock library data — replace with persistent storage (SwiftData/UserDefaults).
    private var libraryPlaylists: [Playlist] {
        [
            Playlist(id: "1", title: "Favorites", subtitle: "Your liked tracks", tracks: []),
            Playlist(id: "2", title: "Chill Mix", subtitle: "Relaxed vibes", tracks: []),
        ]
    }

    private var recentlyPlayed: [Track] {
        audioManager.queue.reversed()
    }
}

/// Playlist row.
private struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 14) {
            AsyncArtwork(url: playlist.artworkURL, size: 56, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(playlist.trackCount) tracks")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

#Preview("Library") {
    LibraryView()
        .environmentObject(AudioPlaybackManager.shared)
}
