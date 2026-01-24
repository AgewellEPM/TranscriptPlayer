import Foundation
import AVFoundation
import Combine

/// Metadata entry with timestamp for body camera or specialized video files
public struct TimedMetadataEntry: Identifiable {
    public let id: UUID
    public let timestamp: CMTime
    public let timeInSeconds: Double
    public let key: String
    public let value: String
    public let identifier: String?

    public init(id: UUID = UUID(), timestamp: CMTime, key: String, value: String, identifier: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.timeInSeconds = timestamp.seconds
        self.key = key
        self.value = value
        self.identifier = identifier
    }
}

/// Service for extracting timed metadata from body camera footage and specialized video files
@MainActor
public class TimedMetadataService: NSObject, ObservableObject {

    @Published public private(set) var metadataEntries: [TimedMetadataEntry] = []
    @Published public private(set) var currentMetadata: [String: String] = [:]
    @Published public private(set) var hasTimedMetadata: Bool = false

    private var metadataOutput: AVPlayerItemMetadataOutput?
    private var playerItem: AVPlayerItem?
    private var metadataQueue = DispatchQueue(label: "com.transcriptplayer.metadata", qos: .userInitiated)

    public override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Setup metadata extraction for a player item
    public func setupMetadataExtraction(for playerItem: AVPlayerItem) {
        self.playerItem = playerItem

        // Create metadata output
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        output.setDelegate(self, queue: metadataQueue)

        playerItem.add(output)
        self.metadataOutput = output

        print("TimedMetadataService: Metadata output configured")
    }

    /// Extract all timed metadata from a video file (offline scan)
    public func extractAllMetadata(from videoURL: URL) async throws -> [TimedMetadataEntry] {
        let asset = AVAsset(url: videoURL)
        var entries: [TimedMetadataEntry] = []

        // First, check static metadata
        let metadata = try await asset.load(.metadata)
        print("TimedMetadataService: Found \(metadata.count) static metadata items")

        for item in metadata {
            if let key = item.commonKey?.rawValue ?? item.key as? String {
                do {
                    let value = try await item.load(.value)
                    let stringValue = self.convertValueToString(value)
                    let identifier = item.identifier?.rawValue

                    let entry = TimedMetadataEntry(
                        timestamp: CMTime.zero,
                        key: key,
                        value: stringValue,
                        identifier: identifier
                    )
                    entries.append(entry)
                    print("TimedMetadataService: Static - \(key) = \(stringValue)")
                } catch {
                    // Skip items that fail to load
                    continue
                }
            }
        }

        // Load all metadata tracks for timed metadata
        let tracks = try await asset.loadTracks(withMediaType: .metadata)
        print("TimedMetadataService: Found \(tracks.count) metadata tracks")

        // For now, we'll rely on the real-time delegate for timed metadata
        // The AVPlayerItemMetadataOutput will capture these during playback

        await MainActor.run {
            self.metadataEntries = entries
            self.hasTimedMetadata = !entries.isEmpty
        }

        return entries
    }

    /// Check for sidecar files (.json, .xml) in the same directory
    public func checkForSidecarFile(videoURL: URL) async -> URL? {
        let directory = videoURL.deletingLastPathComponent()
        let baseName = videoURL.deletingPathExtension().lastPathComponent

        let possibleExtensions = ["json", "xml", "txt", "metadata"]

        for ext in possibleExtensions {
            let sidecarURL = directory.appendingPathComponent("\(baseName).\(ext)")
            if FileManager.default.fileExists(atPath: sidecarURL.path) {
                print("TimedMetadataService: Found sidecar file: \(sidecarURL.lastPathComponent)")
                return sidecarURL
            }
        }

        return nil
    }

    /// Parse sidecar JSON file (common for Axon/Evidence.com)
    public func parseSidecarJSON(url: URL) async throws -> [TimedMetadataEntry] {
        let data = try Data(contentsOf: url)

        // Try to parse as generic JSON dictionary
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return await parseGenericJSON(json)
        }

        // Try to parse as JSON array
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var entries: [TimedMetadataEntry] = []
            for item in jsonArray {
                entries.append(contentsOf: await parseGenericJSON(item))
            }
            return entries
        }

        return []
    }

    // MARK: - Private Methods

    private func parseGenericJSON(_ json: [String: Any]) async -> [TimedMetadataEntry] {
        var entries: [TimedMetadataEntry] = []

        for (key, value) in json {
            let stringValue = convertValueToString(value)

            // Check if there's a timestamp field
            var timestamp = CMTime.zero
            if let timestampValue = json["timestamp"] as? Double {
                timestamp = CMTime(seconds: timestampValue, preferredTimescale: 600)
            } else if let timeValue = json["time"] as? Double {
                timestamp = CMTime(seconds: timeValue, preferredTimescale: 600)
            }

            let entry = TimedMetadataEntry(
                timestamp: timestamp,
                key: key,
                value: stringValue,
                identifier: nil
            )
            entries.append(entry)
        }

        return entries
    }

    private func convertValueToString(_ value: Any) -> String {
        if let string = value as? String {
            return string
        } else if let number = value as? NSNumber {
            return number.stringValue
        } else if let data = value as? Data {
            return data.base64EncodedString()
        } else if let dict = value as? [String: Any] {
            return dict.description
        } else if let array = value as? [Any] {
            return array.description
        }
        return "\(value)"
    }

    /// Update current metadata for a given time
    private func updateCurrentMetadata(at time: CMTime) {
        // Find metadata entries closest to current time
        let relevantEntries = metadataEntries.filter { entry in
            abs(entry.timestamp.seconds - time.seconds) < 1.0
        }

        var metadata: [String: String] = [:]
        for entry in relevantEntries {
            metadata[entry.key] = entry.value
        }

        currentMetadata = metadata
    }

    /// Clear all metadata
    public func clear() {
        metadataEntries.removeAll()
        currentMetadata.removeAll()
        hasTimedMetadata = false

        if let playerItem = playerItem, let output = metadataOutput {
            playerItem.remove(output)
        }

        metadataOutput = nil
        playerItem = nil
    }
}

// MARK: - AVPlayerItemMetadataOutputPushDelegate

extension TimedMetadataService: AVPlayerItemMetadataOutputPushDelegate {
    nonisolated public func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            for group in groups {
                let timestamp = group.timeRange.start

                for item in group.items {
                    // Extract key
                    let key: String
                    if let commonKey = item.commonKey?.rawValue {
                        key = commonKey
                    } else if let itemKey = item.key as? String {
                        key = itemKey
                    } else {
                        continue
                    }

                    // Extract value
                    let value: Any?
                    do {
                        value = try await item.load(.value)
                    } catch {
                        value = nil
                    }

                    guard let value = value else { continue }

                    let stringValue = self.convertValueToString(value)
                    let identifier = item.identifier?.rawValue

                    // Update current metadata
                    self.currentMetadata[key] = stringValue

                    // Store as entry
                    let entry = TimedMetadataEntry(
                        timestamp: timestamp,
                        key: key,
                        value: stringValue,
                        identifier: identifier
                    )

                    if !self.metadataEntries.contains(where: { $0.id == entry.id }) {
                        self.metadataEntries.append(entry)
                    }

                    self.hasTimedMetadata = true

                    print("TimedMetadataService: [\(timestamp.seconds)s] \(key) = \(stringValue)")
                    if let id = identifier {
                        print("  Identifier: \(id)")
                    }
                }
            }
        }
    }
}
