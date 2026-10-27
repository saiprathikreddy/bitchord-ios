import Foundation

/// Represents a music artist.
struct Artist: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var artworkURL: URL?
    var genre: String?
    var listeners: Int?
    var followers: Int?

    init(
        id: String,
        name: String,
        artworkURL: URL? = nil,
        genre: String? = nil,
        listeners: Int? = nil,
        followers: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.artworkURL = artworkURL
        self.genre = genre
        self.listeners = listeners
        self.followers = followers
    }
}
