import SwiftUI

/// Full-screen player with artwork, seeker, queue drawer, shuffle/repeat, and lyrics.
@available(iOS 13.0, macOS 10.15, *)
struct FullPlayerView: View {
    @EnvironmentObject private var audioManager: AudioPlaybackManager
    @Binding var showFullPlayer: Bool

    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var isSeeking = false
    @State private var seekProgress: Double = 0

    var body: some View {
        ZStack {
            // Blurred background artwork.
            Group {
                if let track = audioManager.currentTrack, let url = track.artworkURL {
                    AsyncArtwork(url: url, size: nil, cornerRadius: 0)
                        .scaledToFill()
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            .blur(radius: 40)
            .overlay(Color.black.opacity(0.35))
            .ignoresSafeArea()

            // Foreground artwork (large, centered top).
            VStack {
                if let track = audioManager.currentTrack {
                    ArtworkHeader(track: track)

                    Spacer(minLength: 16)

                    // Seeker.
                    seekerView(track: track)
                        .padding(.horizontal, 32)

                    // Controls.
                    controlsView(track: track)
                        .padding(.top, 24)
                        .padding(.horizontal, 32)

                    // Bottom action row: queue, shuffle, repeat, lyrics.
                    bottomActionsView
                        .padding(.top, 30)
                        .padding(.horizontal, 32)

                    Spacer(minLength: 40)
                }
            }
            .padding(.top, 44)
            .ignoresSafeArea(.container, edges: .top)

            // Lyrics overlay.
            if showLyrics {
                SyncedLyricsView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                    .background(Color.black.opacity(0.85).ignoresSafeArea())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            showLyrics = false
                        }
                    }
            }

            // Dismiss / close (drag down).
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            showFullPlayer = false
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
                .padding(.trailing, 16)
                Spacer()
            }
            .ignoresSafeArea(.container, edges: .top)
            .zIndex(3)
        }
        .sheet(isPresented: $showQueue) {
            QueueDrawerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func seekerView(track: Track) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(audioManager.currentTime.formattedTime)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(track.duration.formattedTime)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background.
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 4)

                    // Progress fill.
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: max(0, CGFloat(progressFraction) * geometry.size.width), height: 4)

                    // Seek knob.
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, CGFloat(progressFraction) * (geometry.size.width - 14)))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isSeeking = true
                                    let fraction = min(max(value.location.x / geometry.size.width, 0), 1)
                                    seekProgress = Double(fraction)
                                }
                                .onEnded { value in
                                    let fraction = min(max(value.location.x / geometry.size.width, 0), 1)
                                    let seconds = fraction * track.duration
                                    audioManager.seek(to: seconds)
                                    isSeeking = false
                                    seekProgress = Double(fraction)
                                }
                        )
                }
            }
            .frame(height: 14)
            .opacity(isSeeking ? 1 : 0.85)
        }
    }

    private var progressFraction: Double {
        guard audioManager.duration > 0 else { return 0 }
        if isSeeking { return seekProgress }
        return audioManager.currentTime / audioManager.duration
    }

    @ViewBuilder
    private func controlsView(track: Track) -> some View {
        HStack(spacing: 26) {
            // Previous
            Button {
                Task { await audioManager.skipToPrevious() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            // Play / pause
            Button {
                audioManager.playPause()
            } label: {
                Image(systemName: audioManager.playbackState == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            // Next
            Button {
                Task { await audioManager.skipToNext() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
    }

    private var bottomActionsView: some View {
        HStack(spacing: 24) {
            // Shuffle
            toggleButton(
                systemName: "shuffle",
                isOn: audioManager.isShuffleEnabled,
                action: audioManager.toggleShuffle
            )

            // Queue
            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Lyrics
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    showLyrics.toggle()
                }
            } label: {
                Image(systemName: "text.quote")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(showLyrics ? .red : .primary)
            }
            .buttonStyle(.plain)

            // Repeat
            toggleButton(
                systemName: "repeat",
                isOn: audioManager.isRepeatEnabled,
                action: audioManager.toggleRepeat
            )
        }
    }

    @ViewBuilder
    private func toggleButton(systemName: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isOn ? .red : .primary)
        }
        .buttonStyle(.plain)
        .symbolEffect(.bounce, value: isOn)
    }
}

@available(iOS 13.0, macOS 10.15, *)
private struct ArtworkHeader: View {
    let track: Track

    var body: some View {
        VStack(spacing: 12) {
            AsyncArtwork(url: track.artworkURL, size: 260, cornerRadius: 24)
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)

            Text(track.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(track.artist.name)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
    }
}

extension TimeInterval {
    var formattedTime: String {
        let total = Int(self)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview("FullPlayer") {
    FullPlayerView(showFullPlayer: .constant(true))
        .environmentObject(AudioPlaybackManager.shared)
}
