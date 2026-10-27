import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Async artwork loader with placeholder.
@available(iOS 17.0, macOS 14.0, *)
struct AsyncArtwork: View {
    let url: URL?
    let size: CGFloat?
    let cornerRadius: CGFloat

    @State private var image: Image?
    @State private var isLoading = true

    init(url: URL?, size: CGFloat? = nil, cornerRadius: CGFloat = 8) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size ?? 40, weight: .medium))
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        image = nil
#if canImport(UIKit)
        guard let url, let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data) else {
            isLoading = false
            return
        }
        await MainActor.run {
            self.image = Image(uiImage: uiImage)
            self.isLoading = false
        }
#else
        isLoading = false
#endif
    }
}

/// Reusable track row used in lists/grid.
@available(iOS 17.0, macOS 14.0, *)
struct TrackRowView: View {
    let track: Track
    var onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                AsyncArtwork(url: track.artworkURL, size: 52, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(track.artist.name)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(track.duration.formattedTime)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Queue drawer presented as a sheet from FullPlayerView.
@available(iOS 17.0, macOS 14.0, *)
struct QueueDrawerView: View {
    @EnvironmentObject private var audioManager: AudioPlaybackManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Up Next") {
                    ForEach(Array(audioManager.queue.enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(index == audioManager.queueIndex ? .red : .secondary)
                                .frame(width: 20)

                            AsyncArtwork(url: track.artworkURL, size: 44, cornerRadius: 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(index == audioManager.queueIndex ? .red : .primary)
                                    .lineLimit(1)
                                Text(track.artist.name)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if index == audioManager.queueIndex {
                                Image(systemName: "play.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task {
                                audioManager.queueIndex = index
                                audioManager.currentTrack = audioManager.queue[index]
                                try? await audioManager.loadStream(for: track)
                                audioManager.player.play()
                                audioManager.playbackState = .playing
                                dismiss()
                            }
                        }
                        .listRowBackground(index == audioManager.queueIndex ? Color.red.opacity(0.12) : Color.clear)
                    }
                    .onDelete(perform: deleteTracks)
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func deleteTracks(at offsets: IndexSet) {
        let sorted = offsets.sorted(by: >)
        for index in sorted {
            audioManager.removeFromQueue(at: index)
        }
    }
}
