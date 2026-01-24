import Foundation

/// Utility for formatting time intervals as human-readable timestamps
enum TimeFormatter {
    /// Formats a time interval as HH:MM:SS (e.g., "00:01:23")
    static func format(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Formats a time interval as SRT timestamp (e.g., "00:01:23,456")
    static func formatSRT(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }

    /// Parses a timestamp string (HH:MM:SS) back to TimeInterval
    static func parse(_ string: String) -> TimeInterval? {
        let components = string.split(separator: ":").compactMap { Int($0) }
        guard components.count == 3 else { return nil }

        let hours = components[0]
        let minutes = components[1]
        let seconds = components[2]

        return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }
}
