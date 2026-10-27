import Foundation

/// Represents a music track in the BitChord library.
struct Track: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var artist: Artist
    var album: Album?
    var duration: TimeInterval
    var artworkURL: URL?
    var streamURL: URL?
    var isExplicit: Bool
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var lyricsURL: URL?
    var addedAt: Date

    init(
        id: String,
        title: String,
        artist: Artist,
        album: Album? = nil,
        duration: TimeInterval = 0,
        artworkURL: URL? = nil,
        streamURL: URL? = nil,
        isExplicit: Bool = false,
        genre: String? = nil,
        year: Int? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        lyricsURL: URL? = nil,
        addedAt: Date = .init()
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
        self.streamURL = streamURL
        self.isExplicit = isExplicit
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.lyricsURL = lyricsURL
        self.addedAt = addedAt
    }

    var formattedDuration: String {
        let total = Int(duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
