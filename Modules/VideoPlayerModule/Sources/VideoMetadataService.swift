import Foundation
import AVFoundation
import SharedUtilities

/// Service for reading and writing transcript metadata in video files
@MainActor
public class VideoMetadataService {

    private static let transcriptMetadataKey = "com.transcriptplayer.transcript"
    private static let transcriptVersionKey = "com.transcriptplayer.version"
    private static let currentVersion = "1.0"

    public init() {}

    // MARK: - Public Methods

    /// Check if video has embedded transcript metadata
    public func hasEmbeddedTranscript(videoURL: URL) async -> Bool {
        do {
            let asset = AVAsset(url: videoURL)
            let metadata = try await asset.load(.metadata)

            return metadata.contains { item in
                item.identifier?.rawValue == Self.transcriptMetadataKey
            }
        } catch {
            print("VideoMetadataService: Error checking metadata: \(error)")
            return false
        }
    }

    /// Load transcript from video metadata
    public func loadTranscript(from videoURL: URL) async throws -> [TranscriptEntry]? {
        let asset = AVAsset(url: videoURL)

        // Load all metadata
        let metadata = try await asset.load(.metadata)
        print("VideoMetadataService: Found \(metadata.count) metadata items")

        // Look for our custom transcript metadata
        for item in metadata {
            print("VideoMetadataService: Checking item: \(item.identifier?.rawValue ?? "unknown")")

            if item.identifier?.rawValue == Self.transcriptMetadataKey {
                print("VideoMetadataService: Found transcript metadata!")

                // Load the value
                guard let data = try await item.load(.value) as? Data else {
                    print("VideoMetadataService: Metadata value is not Data")
                    continue
                }

                // Decode JSON
                let decoder = JSONDecoder()
                let entries = try decoder.decode([TranscriptEntry].self, from: data)
                print("VideoMetadataService: Loaded \(entries.count) entries from metadata")
                return entries
            }
        }

        // Also check common metadata (some formats store subtitles there)
        let commonMetadata = try await asset.load(.commonMetadata)
        print("VideoMetadataService: Checking \(commonMetadata.count) common metadata items")

        for item in commonMetadata {
            if item.commonKey == .commonKeyDescription || item.commonKey == .commonKeySubject {
                if let stringValue = try? await item.load(.stringValue),
                   stringValue.hasPrefix("[{") || stringValue.hasPrefix("{") {
                    // Looks like JSON transcript
                    if let data = stringValue.data(using: .utf8) {
                        let decoder = JSONDecoder()
                        if let entries = try? decoder.decode([TranscriptEntry].self, from: data) {
                            print("VideoMetadataService: Found transcript in common metadata")
                            return entries
                        }
                    }
                }
            }
        }

        print("VideoMetadataService: No embedded transcript found")
        return nil
    }

    /// Save transcript to video file metadata (creates a copy)
    public func saveTranscript(_ entries: [TranscriptEntry], to videoURL: URL) async throws -> URL {
        print("VideoMetadataService: Saving transcript to video metadata...")

        // Encode transcript to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(entries)

        // Create metadata item
        let metadataItem = AVMutableMetadataItem()
        metadataItem.identifier = AVMetadataIdentifier(rawValue: Self.transcriptMetadataKey)
        metadataItem.value = data as NSData
        metadataItem.dataType = kCMMetadataBaseDataType_RawData as String

        // Create version metadata
        let versionItem = AVMutableMetadataItem()
        versionItem.identifier = AVMetadataIdentifier(rawValue: Self.transcriptVersionKey)
        versionItem.value = Self.currentVersion as NSString
        versionItem.dataType = kCMMetadataBaseDataType_UTF8 as String

        // Create asset from source video
        let asset = AVAsset(url: videoURL)

        // Create export session to write metadata
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw MetadataError.exportSessionCreationFailed
        }

        // Create output URL (same name with _transcripted suffix)
        let outputURL = createOutputURL(from: videoURL)

        // Remove existing file if needed
        try? FileManager.default.removeItem(at: outputURL)

        // Configure export
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.metadata = [metadataItem, versionItem]

        // Export
        await exportSession.export()

        guard exportSession.status == .completed else {
            if let error = exportSession.error {
                throw error
            }
            throw MetadataError.exportFailed
        }

        print("VideoMetadataService: Transcript saved to: \(outputURL.lastPathComponent)")
        return outputURL
    }

    // MARK: - Private Methods

    private func createOutputURL(from originalURL: URL) -> URL {
        let filename = originalURL.deletingPathExtension().lastPathComponent
        let ext = originalURL.pathExtension
        let directory = originalURL.deletingLastPathComponent()

        // Try adding suffix
        var outputURL = directory.appendingPathComponent("\(filename)_transcripted.\(ext)")

        // If that exists, use temp directory
        if FileManager.default.fileExists(atPath: outputURL.path) {
            outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(filename)_transcripted_\(UUID().uuidString).\(ext)")
        }

        return outputURL
    }
}

/// Errors that can occur during metadata operations
public enum MetadataError: LocalizedError {
    case exportSessionCreationFailed
    case exportFailed
    case metadataNotFound

    public var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Failed to create export session for metadata writing"
        case .exportFailed:
            return "Failed to export video with metadata"
        case .metadataNotFound:
            return "No transcript metadata found in video"
        }
    }
}
