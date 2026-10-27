import Foundation

/// Represents a user-curated or system playlist.
struct Playlist: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var subtitle: String?
    var artworkURL: URL?
    var owner: Artist?
    var tracks: [Track]
    var isPublic: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        artworkURL: URL? = nil,
        owner: Artist? = nil,
        tracks: [Track] = [],
        isPublic: Bool = true,
        createdAt: Date = .init(),
        updatedAt: Date = .init()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.owner = owner
        self.tracks = tracks
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var trackCount: Int { tracks.count }
    var totalDuration: TimeInterval { tracks.reduce(0) { $0 + $1.duration } }
}
