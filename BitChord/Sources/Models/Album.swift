import Foundation

/// Represents a music album.
struct Album: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var artist: Artist
    var artworkURL: URL?
    var releaseDate: Date?
    var trackCount: Int?
    var genre: String?
    var type: AlbumType

    enum AlbumType: String, Codable, CaseIterable {
        case album
        case single
        case ep
        case compilation

        var localizedLabel: String {
            switch self {
            case .album: return "Album"
            case .single: return "Single"
            case .ep: return "EP"
            case .compilation: return "Compilation"
            }
        }
    }

    init(
        id: String,
        title: String,
        artist: Artist,
        artworkURL: URL? = nil,
        releaseDate: Date? = nil,
        trackCount: Int? = nil,
        genre: String? = nil,
        type: AlbumType = .album
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.releaseDate = releaseDate
        self.trackCount = trackCount
        self.genre = genre
        self.type = type
    }
}
