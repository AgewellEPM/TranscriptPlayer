import AVFoundation
import Foundation

/// Errors that can occur during audio extraction
enum AudioExtractorError: LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case noAudioTrack
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The specified file could not be found"
        case .unsupportedFormat:
            return "Unsupported file format. Please use MP3, M4A, or MP4 files"
        case .noAudioTrack:
            return "No audio track found in the file"
        case .exportFailed(let reason):
            return "Audio export failed: \(reason)"
        }
    }
}

/// Service for extracting and preparing audio for transcription
actor AudioExtractor {

    /// Supported file extensions
    static let supportedExtensions = ["mp3", "mp4", "m4a", "m4v", "wav", "aac"]

    /// Audio-only extensions (no conversion needed)
    static let audioOnlyExtensions = ["mp3", "m4a", "wav", "aac"]

    /// Checks if a file URL has a supported extension
    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Prepares an audio file for transcription
    /// - For audio files (MP3, M4A, WAV): Returns original URL directly
    /// - For video files (MP4, M4V): Extracts audio track
    func prepareAudioForTranscription(from url: URL) async throws -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioExtractorError.fileNotFound
        }

        let ext = url.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else {
            throw AudioExtractorError.unsupportedFormat
        }

        // For audio-only files, use directly (no conversion needed)
        if Self.audioOnlyExtensions.contains(ext) {
            return url
        }

        // For video files, extract audio
        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AudioExtractorError.noAudioTrack
        }

        return try await exportAudio(from: asset)
    }

    /// Gets the duration of an audio/video file
    func getDuration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }

    /// Exports audio from a video asset
    private func exportAudio(from asset: AVAsset) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioExtractorError.exportFailed("Could not create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw AudioExtractorError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown")
        default:
            throw AudioExtractorError.exportFailed("Export failed")
        }
    }

    /// Cleans up temporary audio files
    func cleanupTemporaryFile(at url: URL) {
        guard url.path.hasPrefix(FileManager.default.temporaryDirectory.path) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }
}
