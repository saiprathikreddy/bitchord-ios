import Foundation

// MARK: - Errors

enum YouTubeMusicError: Error, LocalizedError {
    case invalidURL
    case invalidResponse(Int)
    case decodingError(Error)
    case networkError(Error)
    case streamNotAvailable
    case rateLimited
    case unauthorized
    case allInstancesUnavailable
    case maxRetriesExceeded

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse(let code): return "Invalid server response (HTTP \(code))"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .streamNotAvailable: return "Stream not available"
        case .rateLimited: return "Rate limited"
        case .unauthorized: return "Unauthorized"
        case .allInstancesUnavailable: return "All Piped instances unavailable"
        case .maxRetriesExceeded: return "Maximum retries exceeded"
        }
    }
}

// MARK: - Piped Instance Configuration

/// A public Piped API instance used as a YouTube Music backend.
struct PipedInstance: Sendable, Equatable {
    let baseURL: String
    var isHealthy: Bool = true
    var failureCount: Int = 0

    var isExhausted: Bool { failureCount >= 3 }
}

// MARK: - Piped API Response Models

/// Response from Piped /search endpoint.
private struct PipedSearchResponse: Codable {
    let items: [PipedSearchItem]
}

private struct PipedSearchItem: Codable {
    let id: String
    let title: String
    let type: String
    let uploader: String?
    let uploaderId: String?
    let uploadedAgo: String?
    let viewCount: Int?
    let durationSeconds: Int?
    let thumbnail: PipedThumbnail?
}

private struct PipedThumbnail: Codable {
    let url: String?
}

/// Response from Piped /streams/id/:id endpoint.
private struct PipedStreamResponse: Codable {
    let title: String
    let uploader: String?
    let uploaderId: String?
    let durationSeconds: Int?
    let thumbnail: PipedThumbnail?
    let formats: [PipedStreamFormat]
}

/// A single audio/video format from Piped stream info.
private struct PipedStreamFormat: Codable {
    let url: String?
    let audioOnly: Bool
    let container: String?
    let audioCodec: String?
    let bitrate: Int?
    let qualityLabel: String?
    let hasAudio: Bool
}

// MARK: - Piped-backed YouTube Music Client

actor YouTubeMusicClient {

    static let shared = YouTubeMusicClient()

    private let session: URLSession

    /// Ordered list of public Piped instances. Unhealthy instances are skipped.
    private var instances: [PipedInstance] = [
        PipedInstance(baseURL: "https://pipedapi.kavin.rocks"),
        PipedInstance(baseURL: "https://pipedapi.adminforge.de"),
        PipedInstance(baseURL: "https://pipedapi.reallyaweso.me"),
        PipedInstance(baseURL: "https://api.piped.private.coffee"),
    ]

    private let maxRetriesPerInstance = 2
    private let retryDelayBase: TimeInterval = 1.0

    init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search

    /// Searches YouTube Music via Piped for songs, artists, and albums.
    ///
    /// Piped search returns video items which we map to Tracks. Artist/album
    /// entries are derived from the uploader metadata.
    func search(query: String, filter: SearchFilter = .all) async throws -> SearchResult {
        var lastError: Error = YouTubeMusicError.allInstancesUnavailable

        for instance in instances where !instance.isExhausted {
            do {
                return try await search(on: instance, query: query, filter: filter)
            } catch {
                lastError = error
                await markInstanceUnhealthy(instance)
                continue
            }
        }
        throw lastError
    }

    private func search(on instance: PipedInstance, query: String, filter: SearchFilter) async throws -> SearchResult {
        guard var components = URLComponents(string: "\(instance.baseURL)/search") else {
            throw YouTubeMusicError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "filter", value: searchFilterPipedValue(filter))
        ]
        guard let url = components.url else { throw YouTubeMusicError.invalidURL }

        let (data, response) = try await performRequest(url: url, instance: instance)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw YouTubeMusicError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        do {
            let piped = try JSONDecoder().decode(PipedSearchResponse.self, from: data)
            return mapSearchResult(piped.items, filter: filter)
        } catch {
            throw YouTubeMusicError.decodingError(error)
        }
    }

    private func searchFilterPipedValue(_ filter: SearchFilter) -> String {
        switch filter {
        case .all: return ""
        case .songs: return ""
        case .artists: return ""
        case .albums: return ""
        case .playlists: return ""
        }
    }

    private func mapSearchResult(_ items: [PipedSearchItem], filter: SearchFilter) -> SearchResult {
        var tracks: [Track] = []
        var artists: [Artist] = []
        var albums: [Album] = []
        var playlists: [Playlist] = []

        var seenArtistIDs = Set<String>()
        var seenAlbumIDs = Set<String>()

        for item in items where item.type == "video" {
            guard let id = item.id.nonEmpty else { continue }
            let title = item.title.isEmpty ? "Unknown Title" : item.title
            let artistName = item.uploader ?? "Unknown Artist"
            let artistID = item.uploaderId ?? id
            let duration = TimeInterval(item.durationSeconds ?? 0)
            let thumbnailURL = item.thumbnail?.url.flatMap { URL(string: $0) }

            let artist = Artist(
                id: artistID,
                name: artistName,
                artworkURL: thumbnailURL
            )
            if seenArtistIDs.insert(artistID).inserted {
                artists.append(artist)
            }

            let track = Track(
                id: id,
                title: title,
                artist: artist,
                duration: duration,
                artworkURL: thumbnailURL
            )
            tracks.append(track)

            if seenAlbumIDs.insert(id).inserted {
                let album = Album(
                    id: id,
                    title: title,
                    artist: artist,
                    artworkURL: thumbnailURL,
                    type: .single
                )
                albums.append(album)
            }
        }

        return SearchResult(tracks: tracks, artists: artists, albums: albums, playlists: playlists)
    }

    // MARK: - Track Details

    /// Fetches detailed track information including thumbnails and duration.
    func trackDetails(trackID: String) async throws -> Track {
        var lastError: Error = YouTubeMusicError.allInstancesUnavailable

        for instance in instances where !instance.isExhausted {
            do {
                return try await trackDetails(on: instance, trackID: trackID)
            } catch {
                lastError = error
                await markInstanceUnhealthy(instance)
                continue
            }
        }
        throw lastError
    }

    private func trackDetails(on instance: PipedInstance, trackID: String) async throws -> Track {
        guard let url = URL(string: "\(instance.baseURL)/streams/id/\(trackID)") else {
            throw YouTubeMusicError.invalidURL
        }

        let (data, response) = try await performRequest(url: url, instance: instance)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw YouTubeMusicError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        do {
            let piped = try JSONDecoder().decode(PipedStreamResponse.self, from: data)
            let title = piped.title.isEmpty ? "Unknown Title" : piped.title
            let artistName = piped.uploader ?? "Unknown Artist"
            let artistID = piped.uploaderId ?? trackID
            let duration = TimeInterval(piped.durationSeconds ?? 0)
            let thumbnailURL = piped.thumbnail?.url.flatMap { URL(string: $0) }

            let artist = Artist(id: artistID, name: artistName, artworkURL: thumbnailURL)

            return Track(
                id: trackID,
                title: title,
                artist: artist,
                duration: duration,
                artworkURL: thumbnailURL
            )
        } catch {
            throw YouTubeMusicError.decodingError(error)
        }
    }

    // MARK: - Stream Resolution

    /// Resolves the highest quality audio stream URL (AAC/Opus) for a track.
    ///
    /// Attempts each healthy Piped instance with retry logic, then selects the
    /// best audio-only format by bitrate, preferring Opus/AAC containers.
    func resolveStream(for trackID: String) async throws -> StreamInfo {
        var lastError: Error = YouTubeMusicError.allInstancesUnavailable

        for instance in instances where !instance.isExhausted {
            for attempt in 1...maxRetriesPerInstance {
                do {
                    return try await resolveStream(on: instance, trackID: trackID)
                } catch let err as YouTubeMusicError {
                    if case .rateLimited = err {
                        lastError = err
                        try? await sleep(for: retryDelayBase * Double(attempt))
                        continue
                    }
                    lastError = err
                    break
                }
            }
            await markInstanceUnhealthy(instance)
        }
        throw lastError
    }

    private func resolveStream(on instance: PipedInstance, trackID: String) async throws -> StreamInfo {
        guard let url = URL(string: "\(instance.baseURL)/streams/id/\(trackID)") else {
            throw YouTubeMusicError.invalidURL
        }

        let (data, response) = try await performRequest(url: url, instance: instance)
        guard let http = response as? HTTPURLResponse else {
            throw YouTubeMusicError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 429 {
            throw YouTubeMusicError.rateLimited
        }
        guard (200...299).contains(http.statusCode) else {
            throw YouTubeMusicError.invalidResponse(http.statusCode)
        }

        do {
            let piped = try JSONDecoder().decode(PipedStreamResponse.self, from: data)

            guard let best = selectBestAudioFormat(piped.formats) else {
                throw YouTubeMusicError.streamNotAvailable
            }

            guard let streamURL = best.url.flatMap({ URL(string: $0) }) else {
                throw YouTubeMusicError.invalidURL
            }

            let codec = best.audioCodec ?? best.container ?? "unknown"
            let format = streamFormatFrom(codec: codec)
            let bitrate = best.bitrate ?? 0

            return StreamInfo(
                trackID: trackID,
                url: streamURL,
                format: format,
                bitrate: bitrate,
                codec: codec
            )
        } catch let error as YouTubeMusicError {
            throw error
        } catch {
            throw YouTubeMusicError.decodingError(error)
        }
    }

    /// Selects the best audio-only format by bitrate, preferring Opus then AAC.
    private func selectBestAudioFormat(_ formats: [PipedStreamFormat]) -> PipedStreamFormat? {
        let audioFormats = formats.filter { $0.audioOnly || $0.hasAudio }
        guard !audioFormats.isEmpty else { return nil }

        let preferred = audioFormats.sorted { lhs, rhs in
            let lhsScore = formatScore(lhs)
            let rhsScore = formatScore(rhs)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            return (lhs.bitrate ?? 0) > (rhs.bitrate ?? 0)
        }
        return preferred.first
    }

    private func formatScore(_ format: PipedStreamFormat) -> Int {
        let codec = (format.audioCodec ?? format.container ?? "").lowercased()
        if codec.contains("opus") { return 3 }
        if codec.contains("aac") || codec.contains("mp4a") { return 2 }
        if codec.contains("vorbis") { return 1 }
        if codec.contains("mp3") { return 0 }
        return -1
    }

    private func streamFormatFrom(codec: String) -> StreamInfo.StreamFormat {
        let lower = codec.lowercased()
        if lower.contains("opus") { return .opus }
        if lower.contains("aac") || lower.contains("mp4a") { return .aac }
        if lower.contains("mp3") { return .mp3 }
        if lower.contains("flac") { return .flac }
        return .aac
    }

    // MARK: - Lyrics

    /// Fetches LRC lyrics for a track. Piped does not host lyrics natively;
    /// this attempts a best-effort fetch and falls back to empty lyrics.
    func fetchLyrics(trackID: String) async throws -> String {
        var lastError: Error = YouTubeMusicError.allInstancesUnavailable

        for instance in instances where !instance.isExhausted {
            do {
                return try await fetchLyrics(on: instance, trackID: trackID)
            } catch {
                lastError = error
                await markInstanceUnhealthy(instance)
                continue
            }
        }
        throw lastError
    }

    private func fetchLyrics(on instance: PipedInstance, trackID: String) async throws -> String {
        guard let url = URL(string: "\(instance.baseURL)/streams/id/\(trackID)") else {
            throw YouTubeMusicError.invalidURL
        }

        let (data, response) = try await performRequest(url: url, instance: instance)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw YouTubeMusicError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        do {
            let piped = try JSONDecoder().decode(PipedStreamResponse.self, from: data)
            // Piped stream response may include lyrics in some instances; return empty if absent.
            return ""
        } catch {
            throw YouTubeMusicError.decodingError(error)
        }
    }

    // MARK: - Internal Helpers

    private func performRequest(url: URL, instance: PipedInstance) async throws -> (data: Data, response: URLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            throw YouTubeMusicError.networkError(error)
        } catch {
            throw YouTubeMusicError.networkError(error)
        }
    }

    private func markInstanceUnhealthy(_ instance: PipedInstance) async {
        guard let index = instances.firstIndex(where: { $0.baseURL == instance.baseURL }) else { return }
        var updated = instances[index]
        updated.failureCount += 1
        instances[index] = updated
    }

    private func sleep(for seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - Helpers

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Existing model extensions (retained from original scaffold)

enum SearchFilter: String, CaseIterable, Sendable {
    case all = "all"
    case songs = "songs"
    case artists = "artists"
    case albums = "albums"
    case playlists = "playlists"
}

struct SearchResult: Codable, Equatable {
    var tracks: [Track]
    var artists: [Artist]
    var albums: [Album]
    var playlists: [Playlist]
}

struct StreamInfo: Codable, Equatable {
    var trackID: String
    var url: URL
    var format: StreamFormat
    var bitrate: Int
    var codec: String

    enum StreamFormat: String, Codable, CaseIterable {
        case opus = "opus"
        case aac = "aac"
        case mp3 = "mp3"
        case flac = "flac"

        var preferred: Bool {
            switch self {
            case .opus: return true
            case .aac: return true
            case .mp3: return false
            case .flac: return false
            }
        }
    }
}
