import Foundation

/// Represents a single segment of transcribed audio with timing information
struct TranscriptSegment: Identifiable, Equatable {
    let id = UUID()
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String

    /// Formatted time range string (e.g., "[00:01:23 - 00:01:28]")
    var formattedTimeRange: String {
        "[\(TimeFormatter.format(startTime)) - \(TimeFormatter.format(endTime))]"
    }

    /// Full formatted line with timestamp and text
    var formattedLine: String {
        "\(formattedTimeRange) \(text)"
    }

    static func == (lhs: TranscriptSegment, rhs: TranscriptSegment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Collection Extensions

extension Array where Element == TranscriptSegment {
    /// Exports all segments as a plain text transcript
    func asPlainText() -> String {
        map { $0.formattedLine }.joined(separator: "\n")
    }

    /// Exports all segments in SRT subtitle format
    func asSRT() -> String {
        enumerated().map { index, segment in
            let startSRT = TimeFormatter.formatSRT(segment.startTime)
            let endSRT = TimeFormatter.formatSRT(segment.endTime)
            return "\(index + 1)\n\(startSRT) --> \(endSRT)\n\(segment.text)\n"
        }.joined(separator: "\n")
    }
}
