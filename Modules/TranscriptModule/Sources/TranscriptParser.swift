import Foundation
import SharedUtilities

/// Protocol for transcript parsers
public protocol TranscriptParser {
    func parse(_ content: String) throws -> [TranscriptEntry]
    func export(_ entries: [TranscriptEntry]) -> String
}

/// Errors that can occur during parsing
public enum TranscriptParseError: Error {
    case invalidFormat
    case invalidTimestamp
    case emptyContent
}

/// SRT (SubRip) format parser
public class SRTParser: TranscriptParser {

    public init() {}

    public func parse(_ content: String) throws -> [TranscriptEntry] {
        guard !content.isEmpty else { throw TranscriptParseError.emptyContent }

        var entries: [TranscriptEntry] = []
        let blocks = content.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            // Parse timestamp line (format: 00:00:01,000 --> 00:00:04,000)
            let timestampLine = lines[1]
            let timestamps = timestampLine.components(separatedBy: " --> ")
            guard timestamps.count == 2,
                  let startTime = TimeFormatter.fromSRTFormat(timestamps[0].trimmingCharacters(in: .whitespaces)),
                  let endTime = TimeFormatter.fromSRTFormat(timestamps[1].trimmingCharacters(in: .whitespaces)) else {
                continue
            }

            // Combine remaining lines as text
            let text = lines[2...].joined(separator: "\n")

            entries.append(TranscriptEntry(startTime: startTime, endTime: endTime, text: text))
        }

        return entries
    }

    public func export(_ entries: [TranscriptEntry]) -> String {
        var output = ""
        for (index, entry) in entries.enumerated() {
            output += "\(index + 1)\n"
            output += "\(TimeFormatter.toSRTFormat(entry.startTime)) --> \(TimeFormatter.toSRTFormat(entry.endTime))\n"
            output += "\(entry.text)\n\n"
        }
        return output
    }
}

/// VTT (WebVTT) format parser
public class VTTParser: TranscriptParser {

    public init() {}

    public func parse(_ content: String) throws -> [TranscriptEntry] {
        guard !content.isEmpty else { throw TranscriptParseError.emptyContent }

        var entries: [TranscriptEntry] = []
        let lines = content.components(separatedBy: "\n")

        var i = 0
        // Skip header
        if lines.first?.hasPrefix("WEBVTT") == true {
            i = 1
        }

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // Look for timestamp line
            if line.contains(" --> ") {
                let timestamps = line.components(separatedBy: " --> ")
                guard timestamps.count == 2,
                      let startTime = TimeFormatter.fromVTTFormat(timestamps[0].trimmingCharacters(in: .whitespaces)),
                      let endTime = TimeFormatter.fromVTTFormat(timestamps[1].trimmingCharacters(in: .whitespaces)) else {
                    i += 1
                    continue
                }

                // Collect text lines until empty line
                var textLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    textLines.append(lines[i])
                    i += 1
                }

                let text = textLines.joined(separator: "\n")
                entries.append(TranscriptEntry(startTime: startTime, endTime: endTime, text: text))
            }

            i += 1
        }

        return entries
    }

    public func export(_ entries: [TranscriptEntry]) -> String {
        var output = "WEBVTT\n\n"
        for entry in entries {
            output += "\(TimeFormatter.toVTTFormat(entry.startTime)) --> \(TimeFormatter.toVTTFormat(entry.endTime))\n"
            output += "\(entry.text)\n\n"
        }
        return output
    }
}

/// JSON format parser
public class JSONParser: TranscriptParser {

    public init() {}

    private struct JSONTranscriptEntry: Codable {
        let startTime: TimeInterval
        let endTime: TimeInterval
        let text: String
    }

    public func parse(_ content: String) throws -> [TranscriptEntry] {
        guard !content.isEmpty else { throw TranscriptParseError.emptyContent }

        let data = content.data(using: .utf8) ?? Data()
        let jsonEntries = try JSONDecoder().decode([JSONTranscriptEntry].self, from: data)

        return jsonEntries.map { TranscriptEntry(startTime: $0.startTime, endTime: $0.endTime, text: $0.text) }
    }

    public func export(_ entries: [TranscriptEntry]) -> String {
        let jsonEntries = entries.map { JSONTranscriptEntry(startTime: $0.startTime, endTime: $0.endTime, text: $0.text) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(jsonEntries),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return jsonString
    }
}

/// Factory for creating parsers based on format
public class TranscriptParserFactory {

    public static func parser(for format: TranscriptFormat) -> TranscriptParser {
        switch format {
        case .srt:
            return SRTParser()
        case .vtt:
            return VTTParser()
        case .json:
            return JSONParser()
        }
    }

    public static func detectFormat(from content: String) -> TranscriptFormat? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("WEBVTT") {
            return .vtt
        } else if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            return .json
        } else if trimmed.range(of: "\\d+\\n\\d{2}:\\d{2}:\\d{2},\\d{3}", options: .regularExpression) != nil {
            return .srt
        }

        return nil
    }
}
