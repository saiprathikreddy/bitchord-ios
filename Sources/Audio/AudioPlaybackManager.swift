import Foundation
import AVFoundation
#if canImport(MediaPlayer)
import MediaPlayer
#endif
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Playback state of the audio engine.
enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
    case buffering
    case error(String)
}

/// Errors thrown by the audio playback manager.
enum AudioError: Error, LocalizedError {
    case playerItemFailed(Error?)
    case sessionSetupFailed(Error?)
    case noTrack
    case streamUnavailable

    var errorDescription: String? {
        switch self {
        case .playerItemFailed(let error): return "Player item failed: \(error?.localizedDescription ?? "unknown")"
        case .sessionSetupFailed(let error): return "Audio session setup failed: \(error?.localizedDescription ?? "unknown")"
        case .noTrack: return "No track loaded"
        case .streamUnavailable: return "Stream unavailable"
        }
    }
}

/// Manages audio playback, queue, lock screen controls, and audio session.
@available(iOS 17.0, macOS 14.0, *)
@Observable
final class AudioPlaybackManager {

    static let shared = AudioPlaybackManager()

#if canImport(MediaPlayer)
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
#endif

    private let player: AVQueuePlayer
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?

    /// Current playback state.
    var playbackState: PlaybackState = .stopped

    /// Currently playing track, if any.
    var currentTrack: Track?

    /// Playback queue.
    var queue: [Track] = []

    /// Index of the currently playing track in the queue.
    var queueIndex: Int = 0

    /// Current playback progress in seconds.
    var currentTime: TimeInterval = 0

    /// Track duration in seconds.
    var duration: TimeInterval = 0

    /// Whether the player is currently buffering.
    var isBuffering: Bool = false

    /// Volume (0.0 to 1.0).
    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    /// Whether repeat is enabled.
    var isRepeatEnabled: Bool = false

    /// Whether shuffle is enabled.
    var isShuffleEnabled: Bool = false

    private let client = YouTubeMusicClient()

    private init() {
        let playerItem = AVPlayerItem(url: URL(string: "about:blank")!)
        self.player = AVQueuePlayer(items: [playerItem])
        self.player.isMuted = false
        self.player.volume = 1.0

        setupAudioSession()
#if canImport(MediaPlayer)
        setupRemoteCommands()
#endif
        setupTimeObserver()
        observePlayerItemReachedEnd()
    }

    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            playbackState = .error(AudioError.sessionSetupFailed(error).errorDescription ?? error.localizedDescription)
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 1000)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            self?.updateNowPlayingProgress()
        }
    }

    private func observePlayerItemReachedEnd() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    // MARK: - Playback Control

    /// Loads and plays a track immediately, replacing the queue.
    func play(track: Track) async throws {
        queue = [track]
        queueIndex = 0
        currentTrack = track
        try await loadStream(for: track)
        player.play()
        playbackState = .playing
        updateNowPlayingInfo()
    }

    /// Sets the queue and plays from the given index.
    func setQueue(_ tracks: [Track], startAt index: Int = 0) async throws {
        guard !tracks.isEmpty else { throw AudioError.noTrack }
        queue = tracks
        queueIndex = max(0, min(index, tracks.count - 1))
        currentTrack = tracks[queueIndex]
        try await loadStream(for: currentTrack!)
        player.play()
        playbackState = .playing
        updateNowPlayingInfo()
    }

    private func loadStream(for track: Track) async throws {
        playbackState = .buffering
        isBuffering = true

        let streamInfo: StreamInfo
        do {
            streamInfo = try await client.resolveStream(for: track.id)
        } catch {
            playbackState = .error("Failed to resolve stream: \(error.localizedDescription)")
            isBuffering = false
            throw error
        }

        var track = track
        track.streamURL = streamInfo.url

        let asset = AVURLAsset(url: streamInfo.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let item = AVPlayerItem(asset: asset)

        self.playerItem = item
        player.removeAllItems()
        player.insert(item, after: nil)

        isBuffering = false
        playbackState = .playing

        duration = item.asset.duration.seconds
        updateNowPlayingInfo()
    }

    func playPause() {
        switch playbackState {
        case .playing:
            player.pause()
            playbackState = .paused
        case .paused, .stopped:
            player.play()
            playbackState = .playing
        case .buffering:
            break
        case .error:
            break
        }
        updateNowPlayingInfo()
    }

    func pause() {
        player.pause()
        playbackState = .paused
        updateNowPlayingInfo()
    }

    func resume() {
        player.play()
        playbackState = .playing
        updateNowPlayingInfo()
    }

    func stop() {
        player.pause()
        player.removeAllItems()
        playerItem = nil
        currentTrack = nil
        playbackState = .stopped
        currentTime = 0
        duration = 0
        queueIndex = 0
#if canImport(MediaPlayer)
        nowPlayingInfoCenter.nowPlayingInfo = nil
#endif
    }

    /// Seeks to a time in seconds.
    func seek(to seconds: TimeInterval) {
        guard let item = player.currentItem else { return }
        let time = CMTime(seconds: seconds, preferredTimescale: 1000)
        item.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
        updateNowPlayingProgress()
    }

    func skipToNext() async {
        guard !queue.isEmpty else { return }
        let nextIndex = queueIndex + 1
        if nextIndex < queue.count {
            queueIndex = nextIndex
        } else if isRepeatEnabled {
            queueIndex = 0
        } else {
            playbackState = .stopped
            return
        }
        currentTrack = queue[queueIndex]
        do {
            try await loadStream(for: currentTrack!)
            player.play()
            playbackState = .playing
        } catch {
            playbackState = .error(error.localizedDescription)
        }
        updateNowPlayingInfo()
    }

    func skipToPrevious() async {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        let prevIndex = queueIndex - 1
        if prevIndex >= 0 {
            queueIndex = prevIndex
        } else if isRepeatEnabled {
            queueIndex = queue.count - 1
        } else {
            return
        }
        currentTrack = queue[queueIndex]
        do {
            try await loadStream(for: currentTrack!)
            player.play()
            playbackState = .playing
        } catch {
            playbackState = .error(error.localizedDescription)
        }
        updateNowPlayingInfo()
    }

    // MARK: - Queue Management

    func appendToQueue(_ tracks: [Track]) {
        queue.append(contentsOf: tracks)
    }

    func removeFromQueue(at index: Int) {
        guard index < queue.count else { return }
        queue.remove(at: index)
        if index < queueIndex {
            queueIndex -= 1
        } else if index == queueIndex && queueIndex >= queue.count {
            queueIndex = max(0, queue.count - 1)
        }
    }

    func moveQueueItem(from source: Int, to destination: Int) {
        guard source < queue.count, destination < queue.count else { return }
        let item = queue.remove(at: source)
        queue.insert(item, at: destination)
        if source == queueIndex {
            queueIndex = destination
        } else if source < queueIndex {
            queueIndex -= 1
        } else if destination <= queueIndex {
            queueIndex += 1
        }
    }

    func clearQueue() {
        queue.removeAll()
        queueIndex = 0
    }

    func toggleRepeat() {
        isRepeatEnabled.toggle()
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled {
            queue.shuffle()
            queueIndex = 0
        }
    }

    // MARK: - Now Playing & Remote Commands

#if canImport(MediaPlayer)
    private func setupRemoteCommands() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.playPause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { await self?.skipToNext() }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { await self?.skipToPrevious() }
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: event.positionTime)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist.name,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: playbackState == .playing ? 1.0 : 0.0
        ]
        if let album = track.album {
            info[MPMediaItemPropertyAlbumTitle] = album.title
        }
        if let artworkURL = track.artworkURL {
            Task { [weak self] in
                let artwork = await self?.loadArtwork(from: artworkURL)
                await MainActor.run {
                    guard let self, self.currentTrack?.id == track.id else { return }
                    var updated = self.nowPlayingInfoCenter.nowPlayingInfo ?? info
                    updated[MPMediaItemPropertyArtwork] = artwork
                    self.nowPlayingInfoCenter.nowPlayingInfo = updated
                }
            }
        }
        nowPlayingInfoCenter.nowPlayingInfo = info
    }

    private func updateNowPlayingProgress() {
        guard var info = nowPlayingInfoCenter.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = playbackState == .playing ? 1.0 : 0.0
        nowPlayingInfoCenter.nowPlayingInfo = info
    }

    /// Asynchronously loads track artwork and returns it as `MPMediaItemArtwork`.
    private func loadArtwork(from url: URL) async -> MPMediaItemArtwork? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return nil }
            return MPMediaItemArtwork(boundsSize: uiImage.size) { _ in uiImage }
        } catch {
            return nil
        }
    }
#else
    private func updateNowPlayingInfo() {}
    private func updateNowPlayingProgress() {}
#endif

    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        Task { await skipToNext() }
    }

    // MARK: - Interruption Handling

    func handleInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
               let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue),
               options.contains(.shouldResume) {
                resume()
            }
        @unknown default:
            break
        }
    }
}
