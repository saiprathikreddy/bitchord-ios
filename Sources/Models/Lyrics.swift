import Foundation

/// A single line of time-synced lyrics with its start timestamp.
struct LyricLine: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String

    init(startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

/// Time-synced lyrics parsed from LRC format.
struct Lyrics: Identifiable, Codable, Equatable {
    let id: UUID
    var trackID: String
    var lines: [LyricLine]
    var isSynced: Bool
    var source: LyricsSource

    enum LyricsSource: String, Codable, CaseIterable {
        case embedded
        case provider
        case manual

        var localizedLabel: String {
            switch self {
            case .embedded: return "Embedded"
            case .provider: return "Provider"
            case .manual: return "Manual"
            }
        }
    }

    init(trackID: String, lines: [LyricLine] = [], isSynced: Bool = false, source: LyricsSource = .provider) {
        self.id = UUID()
        self.trackID = trackID
        self.lines = lines
        self.isSynced = isSynced
        self.source = source
    }

    /// Returns the lyric line active at the given playback time.
    func line(at time: TimeInterval) -> LyricLine? {
        lines.first { $0.startTime <= time && time < $0.endTime }
    }

    /// Returns the index of the line active at the given playback time.
    func index(at time: TimeInterval) -> Int? {
        lines.firstIndex { $0.startTime <= time && time < $0.endTime }
    }
}
