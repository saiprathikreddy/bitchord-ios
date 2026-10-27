import Foundation

/// Parses LRC-format lyrics text into time-synced `LyricLine`s.
///
/// LRC format example:
///   [00:12.34]Hello world
///   [00:15.67]This is a test
enum LRCParser {
    /// Parses raw LRC text into a `Lyrics` model.
    static func parse(_ text: String, trackID: String) -> Lyrics {
        let lines = text.components(separatedBy: .newlines)
        var lyricLines: [LyricLine] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, line.hasPrefix("["), line.contains("]") else { continue }

            let bracketEnd = line.firstIndex(of: "]")!
            let timestampStr = String(line[line.index(after: line.startIndex)..<bracketEnd])
            let text = String(line[line.index(after: bracketEnd)...]).trimmingCharacters(in: .whitespaces)

            guard let startTime = parseTimestamp(timestampStr) else { continue }

            lyricLines.append(LyricLine(startTime: startTime, endTime: .greatestFiniteMagnitude, text: text))
        }

        // Compute end times from subsequent start times.
        for index in lyricLines.indices {
            if index + 1 < lyricLines.count {
                lyricLines[index].endTime = lyricLines[index + 1].startTime
            }
        }

        return Lyrics(trackID: trackID, lines: lyricLines, isSynced: true, source: .provider)
    }

    private static func parseTimestamp(_ str: String) -> TimeInterval? {
        // Supports [mm:ss.xx] and [mm:ss.xxx]
        let parts = str.components(separatedBy: ":")
        guard parts.count == 2 else { return nil }
        guard let minutes = Double(parts[0]) else { return nil }
        let secondsPart = parts[1]
        guard let seconds = Double(secondsPart) else { return nil }
        return minutes * 60 + seconds
    }
}
