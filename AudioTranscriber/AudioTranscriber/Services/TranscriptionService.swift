import AVFoundation
import Foundation
import Speech
import os.log

private let logger = Logger(subsystem: "com.AudioTranscriber", category: "Transcription")

/// Errors that can occur during transcription
enum TranscriptionError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case recognitionFailed(String)
    case audioFileError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in System Settings > Privacy & Security > Speech Recognition"
        case .recognizerUnavailable:
            return "Speech recognizer is not available for the current locale"
        case .recognitionFailed(let reason):
            return "Recognition failed: \(reason)"
        case .audioFileError(let reason):
            return "Audio file error: \(reason)"
        }
    }
}

/// Service for transcribing audio files using Apple's Speech framework
@MainActor
class TranscriptionService: ObservableObject {

    private var recognitionTask: SFSpeechRecognitionTask?

    /// Current authorization status for speech recognition
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    /// Requests authorization for speech recognition
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    /// Cancels any ongoing transcription
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    /// Transcribes multiple audio chunks and combines results
    func transcribeChunks(
        urls: [URL],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [TranscriptSegment] {
        var allSegments: [TranscriptSegment] = []
        var timeOffset: TimeInterval = 0

        for (index, url) in urls.enumerated() {
            logger.info("Processing chunk \(index + 1) of \(urls.count): \(url.lastPathComponent)")

            let chunkSegments = try await transcribeFile(url: url) { chunkProgress in
                let overallProgress = (Double(index) + chunkProgress) / Double(urls.count)
                progressHandler(overallProgress)
            }

            // Adjust timestamps with offset and add to results
            for segment in chunkSegments {
                let adjustedSegment = TranscriptSegment(
                    startTime: segment.startTime + timeOffset,
                    endTime: segment.endTime + timeOffset,
                    text: segment.text
                )
                allSegments.append(adjustedSegment)
            }

            // Update offset for next chunk based on last segment or estimate
            if let lastSegment = chunkSegments.last {
                timeOffset += lastSegment.endTime
            } else {
                // Estimate ~50 seconds per chunk if no segments
                timeOffset += 50.0
            }
        }

        progressHandler(1.0)
        return allSegments
    }

    /// Transcribes a single audio file - simple and direct
    func transcribeFile(
        url: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [TranscriptSegment] {
        // Check authorization
        if authorizationStatus != .authorized {
            let authorized = await requestAuthorization()
            if !authorized {
                throw TranscriptionError.notAuthorized
            }
        }

        // Create recognizer
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        // Get duration
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let totalDuration = duration.seconds

        logger.info("File: \(url.lastPathComponent)")
        logger.info("Duration: \(totalDuration)s")
        logger.info("On-device: \(recognizer.supportsOnDeviceRecognition)")

        // Create request - simple URL-based
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            var bestTranscription: SFTranscription?

            self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    logger.error("Error: \(error.localizedDescription)")

                    // Use accumulated results if we have any
                    if !hasResumed, let transcription = bestTranscription {
                        hasResumed = true
                        let segments = self.makeSegments(from: transcription, duration: totalDuration)
                        continuation.resume(returning: segments)
                        return
                    }

                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(throwing: TranscriptionError.recognitionFailed(error.localizedDescription))
                    }
                    return
                }

                guard let result = result else { return }

                let transcription = result.bestTranscription

                // Keep best result
                if transcription.segments.count > (bestTranscription?.segments.count ?? 0) {
                    bestTranscription = transcription
                    logger.info("Got \(transcription.segments.count) segments")
                }

                // Progress update
                if let last = transcription.segments.last {
                    let progress = min(1.0, (last.timestamp + last.duration) / totalDuration)
                    Task { @MainActor in progressHandler(progress) }
                }

                // Final result
                if result.isFinal && !hasResumed {
                    hasResumed = true
                    let segments = self.makeSegments(from: bestTranscription ?? transcription, duration: totalDuration)
                    logger.info("Final: \(segments.count) segments")
                    Task { @MainActor in progressHandler(1.0) }
                    continuation.resume(returning: segments)
                }
            }
        }
    }

    /// Convert SFTranscription to our segments
    private func makeSegments(from transcription: SFTranscription, duration: TimeInterval) -> [TranscriptSegment] {
        let sfSegments = transcription.segments

        if sfSegments.isEmpty {
            let text = transcription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return [TranscriptSegment(startTime: 0, endTime: duration, text: text)]
            }
            return []
        }

        var result: [TranscriptSegment] = []
        var text = ""
        var startTime: TimeInterval = 0
        var endTime: TimeInterval = 0

        for seg in sfSegments {
            let gap = text.isEmpty ? 0 : (seg.timestamp - endTime)
            let len = text.isEmpty ? 0 : (endTime - startTime)

            if (gap > 0.5 || len >= 10) && !text.isEmpty {
                result.append(TranscriptSegment(
                    startTime: startTime,
                    endTime: endTime,
                    text: text.trimmingCharacters(in: .whitespaces)
                ))
                text = ""
            }

            if text.isEmpty { startTime = seg.timestamp }
            text += seg.substring + " "
            endTime = seg.timestamp + seg.duration
        }

        if !text.isEmpty {
            result.append(TranscriptSegment(
                startTime: startTime,
                endTime: endTime,
                text: text.trimmingCharacters(in: .whitespaces)
            ))
        }

        return result
    }
}
