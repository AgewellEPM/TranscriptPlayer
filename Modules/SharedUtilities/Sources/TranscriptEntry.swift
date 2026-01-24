import Foundation

/// Represents a single transcript entry with timestamp and text
public struct TranscriptEntry: Identifiable, Codable {
    public let id: UUID
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    public var text: String

    public init(id: UUID = UUID(), startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }

    /// Check if a given time falls within this entry's time range
    public func contains(time: TimeInterval) -> Bool {
        return time >= startTime && time <= endTime
    }
}

/// Transcript format types
public enum TranscriptFormat: String, CaseIterable {
    case srt = "srt"
    case vtt = "vtt"
    case json = "json"

    public var displayName: String {
        switch self {
        case .srt: return "SubRip (SRT)"
        case .vtt: return "WebVTT"
        case .json: return "JSON"
        }
    }

    public var fileExtension: String {
        return rawValue
    }
}
