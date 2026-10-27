import SwiftUI

/// Floating bottom bar: thumbnail, title, artist, play/pause, progress bar.
/// Tapping expands to FullPlayerView.
@available(iOS 17.0, macOS 14.0, *)
struct MiniPlayerView: View {
    @EnvironmentObject private var audioManager: AudioPlaybackManager

    @State private var isHovered = false
    @State private var dragOffset: CGFloat = 0
    @State private var showProgress = false

    var body: some View {
        Group {
            if let track = audioManager.currentTrack {
                HStack(spacing: 12) {
                    // Artwork
                    AsyncArtwork(url: track.artworkURL, size: 56, cornerRadius: 10)

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(track.artist.name)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    // Play / pause
                    Button {
                        audioManager.playPause()
                    } label: {
                        Image(systemName: audioManager.playbackState == .playing ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28, weight: .regular))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(audioManager.playbackState == .playing ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)

                    // Skip next
                    Button {
                        Task { await audioManager.skipToNext() }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isHovered)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 40
                            if value.translation.height > threshold {
                                // Swipe down dismisses/minimizes — handled by parent hiding it.
                                dragOffset = 0
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .offset(y: dragOffset)
            }
        }
    }
}

#Preview("MiniPlayer") {
    MiniPlayerView()
        .environmentObject(AudioPlaybackManager.shared)
        .padding()
        .background(Color.black)
}
