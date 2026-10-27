import SwiftUI

/// Auto-scrolling, karaoke-style lyrics view synced with playback time.
@available(iOS 13.0, macOS 10.15, *)
struct SyncedLyricsView: View {
    @EnvironmentObject private var audioManager: AudioPlaybackManager

    @State private var lyrics: Lyrics?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var activeLineIndex: Int?
    @State private var isLoaded = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header.
                HStack {
                    Text("Lyrics")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        // Close handled by parent tap.
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Divider()
                    .background(Color.white.opacity(0.15))

                // Lyrics body.
                if let lyrics, !lyrics.lines.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 24) {
                                ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                                    LyricLineView(
                                        line: line,
                                        isActive: activeLineIndex == index
                                    )
                                    .id(index)
                                    .onAppear {
                                        if activeLineIndex == nil {
                                            activeLineIndex = index
                                        }
                                    }
                                }
                                Spacer(minLength: 100)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                        .onChange(of: activeLineIndex) { oldValue, newValue in
                            guard let newValue else { return }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                        .onAppear {
                            scrollProxy = proxy
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Lyrics",
                        systemImage: "text.quote",
                        description: Text("Synced lyrics are not available for this track.")
                    )
                    .foregroundStyle(.secondary)
                }
            }

            // Now-playing hint at bottom.
            VStack {
                Spacer()
                if let track = audioManager.currentTrack {
                    Text(track.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(track.artist.name)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .padding(.bottom, 30)
        }
        .task(id: audioManager.currentTrack?.id) {
            await loadLyrics()
        }
        .onReceive(timerPublisher) { _ in
            updateActiveLine()
        }
    }

    // MARK: - Lyrics loading

    private func loadLyrics() async {
        isLoaded = false
        guard let trackID = audioManager.currentTrack?.id else { return }
        do {
            let raw = try await YouTubeMusicClient.shared.fetchLyrics(trackID: trackID)
            // Parse via LRCParser; if provider returns empty, show placeholder.
            if !raw.isEmpty {
                let parsed = LRCParser.parse(raw, trackID: trackID)
                await MainActor.run {
                    self.lyrics = parsed
                    self.isLoaded = true
                }
            } else {
                await MainActor.run {
                    self.lyrics = placeholderLyrics(for: trackID)
                    self.isLoaded = true
                }
            }
        } catch {
            await MainActor.run {
                self.lyrics = placeholderLyrics(for: trackID)
                self.isLoaded = true
            }
        }
    }

    private func placeholderLyrics(for trackID: String) -> Lyrics {
        // Synthetic lines so the UI demonstrates scrolling; replaced by real provider lyrics.
        let lines = [
            LyricLine(startTime: 0, endTime: 3, text: "♪ Instrumental intro ♪"),
            LyricLine(startTime: 3, endTime: 7, text: "Lyrics will appear here when synced"),
            LyricLine(startTime: 7, endTime: 11, text: "data is available from the provider."),
        ]
        return Lyrics(trackID: trackID, lines: lines, isSynced: false, source: .manual)
    }

    // MARK: - Active line sync

    private let timerPublisher = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private func updateActiveLine() {
        guard let lyrics, !lyrics.lines.isEmpty else { return }
        let time = audioManager.currentTime
        let index = lyrics.lines.firstIndex { line in
            line.startTime <= time && time < line.endTime
        }
        if let index, index != activeLineIndex {
            withAnimation(.easeInOut(duration: 0.15)) {
                activeLineIndex = index
            }
        }
    }
}

/// Single lyric line row with active/highlighted state.
@available(iOS 13.0, macOS 10.15, *)
private struct LyricLineView: View {
    let line: LyricLine
    let isActive: Bool

    var body: some View {
        Text(line.text)
            .font(.system(size: isActive ? 20 : 16, weight: isActive ? .semibold : .regular, design: .rounded))
            .foregroundStyle(isActive ? .white : Color.white.opacity(0.45))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isActive)
    }
}

#Preview("SyncedLyrics") {
    SyncedLyricsView()
        .environmentObject(AudioPlaybackManager.shared)
}
