import Foundation
import Speech
import AVFoundation
import CoreMedia
import SharedUtilities

/// Service for automatic speech recognition and transcript generation
@MainActor
public class TranscriptionService: ObservableObject {

    @Published public var isTranscribing: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var statusMessage: String = ""
    @Published public var granularity: TranscriptionGranularity = .captions
    @Published public var backend: TranscriptionBackend = .appleSpeech
    @Published public var languageCode: String = "en"
    @Published public var whisperModel: String = "base"

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var progressTimer: Timer?

    public init() {
        // Use user's preferred language, fallback to English
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Public Methods

    /// Request speech recognition authorization with timeout
    public func requestAuthorization() async -> Bool {
        // Check current status first
        let currentStatus = SFSpeechRecognizer.authorizationStatus()

        switch currentStatus {
        case .authorized:
            print("TranscriptionService: Already authorized")
            return true
        case .denied, .restricted:
            print("TranscriptionService: Authorization denied or restricted")
            return false
        case .notDetermined:
            print("TranscriptionService: Requesting new authorization...")
            break
        @unknown default:
            return false
        }

        // Request with timeout
        return await withCheckedContinuation { continuation in
            var didResume = false

            SFSpeechRecognizer.requestAuthorization { status in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: status == .authorized)
            }

            // Timeout after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                guard !didResume else { return }
                didResume = true
                print("TranscriptionService: Authorization request timed out")
                continuation.resume(returning: false)
            }
        }
    }

    /// Transcribe audio file and generate transcript entries
    public func transcribe(audioURL: URL) async throws -> [TranscriptEntry] {
        print("TranscriptionService: Starting transcription for \(audioURL.lastPathComponent)")
        isTranscribing = true
        progress = 0
        statusMessage = "Starting..."

        do {
            let entries: [TranscriptEntry]
            switch backend {
            case .appleSpeech:
                // Uses SFSpeechRecognizer with chunked processing for long audio
                // TODO: When macOS 26 SDK is available, add SpeechAnalyzer support
                // which provides faster, more accurate on-device transcription
                entries = try await transcribeWithApple(audioURL: audioURL)
            case .whisperCLI:
                entries = try await transcribeWithWhisperCLI(audioURL: audioURL)
            case .macWhisper:
                entries = try await transcribeWithMacWhisper(audioURL: audioURL)
            }
            return entries
        } catch {
            isTranscribing = false
            statusMessage = "Failed"
            progress = 0
            throw error
        }
    }

    /// Cancel ongoing transcription
    public func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
        isTranscribing = false
        statusMessage = "Cancelled"
    }

    // MARK: - Private Methods

    private func extractAudio(from videoURL: URL) async throws -> URL {
        // Simpler and more reliable path using AVAssetExportSession to M4A
        let asset = AVAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw TranscriptionError.noAudioTrack }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.exportFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        await exportSession.export()
        guard exportSession.status == .completed else { throw TranscriptionError.exportFailed }
        return outputURL
    }

    private func buildCaptionEntries(from segments: [SFTranscriptionSegment]) -> [TranscriptEntry] {
        // Target ~2–3s captions like YouTube/Vimeo
        let targetDuration: TimeInterval = 2.5
        let maxDuration: TimeInterval = 4.0
        let maxWords = 15

        var out: [TranscriptEntry] = []
        var buffer: [String] = []
        var startTime: TimeInterval?
        var wordCount = 0

        for seg in segments {
            // Initialize start time
            if startTime == nil {
                startTime = seg.timestamp
            }

            buffer.append(seg.substring)
            wordCount += 1

            let currentEnd = seg.timestamp + seg.duration
            let duration = currentEnd - (startTime ?? seg.timestamp)

            // Determine if we should break here
            let hasStrongPunct = seg.substring.hasSuffix(".") ||
                                seg.substring.hasSuffix("!") ||
                                seg.substring.hasSuffix("?")
            let hasWeakPunct = seg.substring.hasSuffix(",")

            let hitTargetDuration = duration >= targetDuration
            let hitMaxDuration = duration >= maxDuration
            let hitMaxWords = wordCount >= maxWords

            // Force break if:
            // 1. Hit max duration (ALWAYS)
            // 2. Hit max words (ALWAYS)
            // 3. Hit target duration + strong punctuation
            // 4. Hit target duration + weak punctuation + have 5+ words
            let forceBreak = hitMaxDuration || hitMaxWords
            let naturalBreak = hitTargetDuration && (hasStrongPunct || (hasWeakPunct && wordCount >= 5))

            if forceBreak || naturalBreak {
                let text = buffer.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                if let s = startTime, !text.isEmpty {
                    out.append(TranscriptEntry(startTime: s, endTime: currentEnd, text: text))
                    let mins = Int(s) / 60
                    let secs = Int(s) % 60
                    print("DEBUG: Created entry at \(s)s (\(mins):\(String(format: "%02d", secs))): \"\(text.prefix(60))...\"")
                }
                buffer.removeAll()
                startTime = nil
                wordCount = 0
            }
        }

        // Flush remaining
        if !buffer.isEmpty, let s = startTime {
            let end = segments.last.map { $0.timestamp + $0.duration } ?? s
            let text = buffer.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                out.append(TranscriptEntry(startTime: s, endTime: end, text: text))
                print("DEBUG: Created final entry at \(s)s: \"\(text.prefix(50))...\"")
            }
        }

        print("DEBUG: buildCaptionEntries created \(out.count) entries from \(segments.count) segments")

        // Safety check: if we only got 1 entry from many segments, something is wrong
        // Fall back to breaking every 10 words
        if out.count == 1 && segments.count > 20 {
            print("WARNING: Only 1 entry from \(segments.count) segments! Using fallback word chunking")
            return buildWordChunkEntries(from: segments, wordsPerChunk: 10)
        }

        return out
    }

    // RAW SEGMENTS: Create one entry per segment (like reference code - captures EVERYTHING)
    private func buildRawSegmentEntries(from segments: [SFTranscriptionSegment]) -> [TranscriptEntry] {
        print("DEBUG: Building raw segment entries (one per segment) - guaranteed to capture all speech")

        var out: [TranscriptEntry] = []

        for seg in segments {
            let text = seg.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let start = seg.timestamp
            let end = seg.timestamp + seg.duration

            out.append(TranscriptEntry(startTime: start, endTime: end, text: text))
        }

        print("DEBUG: Created \(out.count) raw segment entries from \(segments.count) segments")
        return out
    }

    // Fallback: create entries by word count (guaranteed to break up long transcripts)
    private func buildWordChunkEntries(from segments: [SFTranscriptionSegment], wordsPerChunk: Int) -> [TranscriptEntry] {
        var out: [TranscriptEntry] = []
        var buffer: [String] = []
        var startTime: TimeInterval?

        for (index, seg) in segments.enumerated() {
            if startTime == nil {
                startTime = seg.timestamp
            }

            buffer.append(seg.substring)

            // Break every N words or at end
            if buffer.count >= wordsPerChunk || index == segments.count - 1 {
                let text = buffer.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                let endTime = seg.timestamp + seg.duration

                if let s = startTime, !text.isEmpty {
                    out.append(TranscriptEntry(startTime: s, endTime: endTime, text: text))
                }

                buffer.removeAll()
                startTime = nil
            }
        }

        return out
    }

    private func performRecognition(audioURL: URL) async throws -> [TranscriptEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            guard let recognizer = speechRecognizer else {
                continuation.resume(throwing: TranscriptionError.recognizerUnavailable)
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            request.taskHint = .unspecified  // Better for natural speech/conversations

            // Add context strings to improve recognition of common law enforcement terms
            request.contextualStrings = [
                "officer", "sir", "ma'am", "apartment", "upstairs", "downstairs",
                "weapon", "hands", "okay", "alright", "gonna", "wanna", "gotta"
            ]

            // CRITICAL: Request detailed timing information for accurate timestamps
            request.addsPunctuation = true  // Helps with natural breaks

            var allSegments: [SFTranscriptionSegment] = []
            var lastProcessedIndex = 0

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let result = result else { return }

                    // Nudge progress until final
                    self.progress = min(0.95, max(0.3, self.progress + 0.05))

                    let segments = result.bestTranscription.segments
                    if lastProcessedIndex < segments.count {
                        allSegments.append(contentsOf: segments[lastProcessedIndex..<segments.count])
                        lastProcessedIndex = segments.count
                    }

                    if result.isFinal {
                        // CRITICAL: Save ALL segments to ensure no speech is lost
                        print("DEBUG: Final transcription received with \(allSegments.count) total segments")

                        var entries: [TranscriptEntry]
                        switch self.granularity {
                        case .oneSecond:
                            entries = self.buildOneSecondEntries(from: allSegments)
                        case .words:
                            // Words mode: Create ONE entry per segment (captures everything)
                            entries = self.buildRawSegmentEntries(from: allSegments)
                        case .phrases:
                            entries = self.buildPhraseEntries(from: allSegments)
                        case .captions:
                            entries = self.buildCaptionEntries(from: allSegments)
                        }

                        // Fallback: If grouping failed, use raw segments (guaranteed to capture all speech)
                        if entries.isEmpty || (entries.count == 1 && allSegments.count > 20) {
                            print("WARNING: Grouping failed or produced only 1 entry. Using raw segments.")
                            entries = self.buildRawSegmentEntries(from: allSegments)
                        }

                        print("DEBUG: Final output: \(entries.count) transcript entries")
                        self.progress = 1.0
                        continuation.resume(returning: entries)
                    }
                }
            }
        }
    }

    // MARK: - Apple Speech Path (SFSpeechRecognizer fallback for macOS < 15)

    private func transcribeWithApple(audioURL: URL) async throws -> [TranscriptEntry] {
        // Check authorization
        statusMessage = "Requesting permission..."
        progress = 0.05
        print("TranscriptionService: Requesting authorization...")

        guard await requestAuthorization() else {
            print("TranscriptionService: Authorization denied!")
            isTranscribing = false
            throw TranscriptionError.notAuthorized
        }
        print("TranscriptionService: Authorization granted")

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("TranscriptionService: Recognizer not available")
            throw TranscriptionError.recognizerUnavailable
        }
        print("TranscriptionService: Recognizer is available")

        // Get audio duration to determine if we need chunked processing
        let asset = AVAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        print("TranscriptionService: Audio duration: \(totalSeconds) seconds")

        // SFSpeechRecognizer has a ~1 minute limit, so chunk long audio
        let chunkDuration: TimeInterval = 55.0  // 55 seconds per chunk (with some buffer)

        if totalSeconds <= 60 {
            // Short audio - process normally
            statusMessage = "Transcribing audio..."
            progress = 0.3
            print("TranscriptionService: Short audio, processing directly")

            let entries = try await performRecognition(audioURL: audioURL)
            print("TranscriptionService: Recognition complete! Generated \(entries.count) entries")

            isTranscribing = false
            statusMessage = "Transcription complete!"
            progress = 1.0
            return entries
        } else {
            // Long audio - process in chunks
            print("TranscriptionService: Long audio detected (\(totalSeconds)s), using chunked processing")
            statusMessage = "Processing long audio in chunks..."

            var allEntries: [TranscriptEntry] = []
            let numberOfChunks = Int(ceil(totalSeconds / chunkDuration))

            for chunkIndex in 0..<numberOfChunks {
                let startTime = TimeInterval(chunkIndex) * chunkDuration
                let endTime = min(startTime + chunkDuration, totalSeconds)

                statusMessage = "Transcribing chunk \(chunkIndex + 1)/\(numberOfChunks)..."
                progress = 0.1 + (0.8 * Double(chunkIndex) / Double(numberOfChunks))
                print("TranscriptionService: Processing chunk \(chunkIndex + 1)/\(numberOfChunks) (\(startTime)s - \(endTime)s)")

                // Extract chunk audio
                let chunkURL = try await extractAudioChunk(from: audioURL, startTime: startTime, endTime: endTime)

                // Transcribe chunk
                let chunkEntries = try await performRecognition(audioURL: chunkURL)
                print("TranscriptionService: Chunk \(chunkIndex + 1) produced \(chunkEntries.count) entries")

                // Adjust timestamps to account for chunk offset
                let adjustedEntries = chunkEntries.map { entry in
                    TranscriptEntry(
                        startTime: entry.startTime + startTime,
                        endTime: entry.endTime + startTime,
                        text: entry.text
                    )
                }
                allEntries.append(contentsOf: adjustedEntries)

                // Clean up chunk file
                try? FileManager.default.removeItem(at: chunkURL)
            }

            print("TranscriptionService: All chunks complete! Total entries: \(allEntries.count)")
            isTranscribing = false
            statusMessage = "Transcription complete!"
            progress = 1.0

            return allEntries
        }
    }

    /// Extract a time range from audio file
    private func extractAudioChunk(from audioURL: URL, startTime: TimeInterval, endTime: TimeInterval) async throws -> URL {
        let asset = AVAsset(url: audioURL)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chunk_\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Set time range for this chunk
        let start = CMTime(seconds: startTime, preferredTimescale: 1000)
        let duration = CMTime(seconds: endTime - startTime, preferredTimescale: 1000)
        exportSession.timeRange = CMTimeRange(start: start, duration: duration)

        await exportSession.export()

        guard exportSession.status == .completed else {
            if let error = exportSession.error {
                print("TranscriptionService: Chunk export error: \(error.localizedDescription)")
            }
            throw TranscriptionError.exportFailed
        }

        return outputURL
    }

    // MARK: - SpeechAnalyzer Path (macOS 26+)
    // SpeechAnalyzer was introduced in iOS 26 / macOS 26 at WWDC 2025
    // Uses SpeechTranscriber module for on-device, high-accuracy transcription
    //
    // When macOS 26 SDK is available, implement using:
    //   let transcriber = SpeechTranscriber(locale: locale, preset: .offlineTranscription)
    //   let analyzer = SpeechAnalyzer(modules: [transcriber])
    //   if let lastSample = try await analyzer.analyzeSequence(from: audioURL) {
    //       try await analyzer.finalizeAndFinish(through: lastSample)
    //   }
    //   for try await result in transcriber.results { ... }
    //
    // For now, this falls back to chunked SFSpeechRecognizer processing

    // MARK: - Whisper CLI Path

    private func transcribeWithWhisperCLI(audioURL: URL) async throws -> [TranscriptEntry] {
        statusMessage = "Transcribing with Whisper…"
        progress = 0.1

        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // Try to find command: env override > 'whisper' fallback
        let env = ProcessInfo.processInfo.environment
        let whisperCmd = env["TRANSCRIPT_WHISPER_CMD"] ?? "whisper"

        // whisper <input> --model base --language en --task transcribe --output_format vtt --output_dir <dir>
        let args = [audioURL.path, "--model", whisperModel, "--language", languageCode, "--task", "transcribe", "--output_format", "vtt", "--output_dir", tmpDir.path]

        startIndeterminateProgress()
        do {
            try await runProcessAsync(cmd: whisperCmd, args: args)
        } catch {
            stopIndeterminateProgress()
            throw TranscriptionError.cliNotFound(tool: whisperCmd)
        }
        stopIndeterminateProgress()

        // Find produced VTT
        let vttURL = try findOutput(in: tmpDir, preferredExt: "vtt")
        let content = try String(contentsOf: vttURL, encoding: .utf8)
        let entries = try VTTParser().parse(content)

        isTranscribing = false
        statusMessage = "Transcription complete!"
        progress = 1.0
        return rebuildByGranularity(entries: entries)
    }

    private func transcribeWithMacWhisper(audioURL: URL) async throws -> [TranscriptEntry] {
        statusMessage = "Transcribing with MacWhisper…"
        progress = 0.1

        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // Attempt macwhisper CLI; allow env override
        let env = ProcessInfo.processInfo.environment
        let tool = env["TRANSCRIPT_MACWHISPER_CMD"] ?? "macwhisper"

        // macwhisper <input> --model base --language en --output_dir <dir> --format vtt
        let args = [audioURL.path, "--model", whisperModel, "--language", languageCode, "--output_dir", tmpDir.path, "--format", "vtt"]

        startIndeterminateProgress()
        do {
            try await runProcessAsync(cmd: tool, args: args)
        } catch {
            stopIndeterminateProgress()
            throw TranscriptionError.cliNotFound(tool: tool)
        }
        stopIndeterminateProgress()

        let vttURL = try findOutput(in: tmpDir, preferredExt: "vtt")
        let content = try String(contentsOf: vttURL, encoding: .utf8)
        let entries = try VTTParser().parse(content)

        isTranscribing = false
        statusMessage = "Transcription complete!"
        progress = 1.0
        return rebuildByGranularity(entries: entries)
    }

    private func rebuildByGranularity(entries: [TranscriptEntry]) -> [TranscriptEntry] {
        // Convert from pre-chunked VTT entries into selected granularity
        switch granularity {
        case .captions:
            // Already close to caption style; return as-is
            return entries
        case .phrases:
            // Merge adjacent entries if gaps are small
            return mergeEntries(entries, maxGap: 0.5, maxDuration: 6.0)
        case .oneSecond:
            // Slice into one-second windows using text content
            return sliceIntoSeconds(entries)
        case .words:
            return entries // best-effort; word-level requires original segments
        }
    }

    private func mergeEntries(_ entries: [TranscriptEntry], maxGap: TimeInterval, maxDuration: TimeInterval) -> [TranscriptEntry] {
        guard !entries.isEmpty else { return [] }
        var out: [TranscriptEntry] = []
        var current = entries[0]
        for e in entries.dropFirst() {
            if (e.startTime - current.endTime) <= maxGap && (e.endTime - current.startTime) <= maxDuration {
                current.text += " " + e.text
                current.endTime = e.endTime
            } else {
                out.append(current)
                current = e
            }
        }
        out.append(current)
        return out
    }

    private func sliceIntoSeconds(_ entries: [TranscriptEntry]) -> [TranscriptEntry] {
        var buckets: [Int: [String]] = [:]
        for e in entries {
            let startSec = Int(floor(e.startTime))
            let endSec = Int(floor(max(e.endTime - 0.0001, e.startTime)))
            for sec in startSec...endSec {
                buckets[sec, default: []].append(e.text)
            }
        }
        var out: [TranscriptEntry] = []
        for sec in buckets.keys.sorted() {
            let text = buckets[sec]?.joined(separator: " ") ?? ""
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let start = TimeInterval(sec)
            out.append(TranscriptEntry(startTime: start, endTime: start + 1, text: text))
        }
        return out
    }

    private func runProcessAsync(cmd: String, args: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.launchPath = "/usr/bin/env"
            process.arguments = [cmd] + args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    print("CLI failed: \(output)")
                    cont.resume(throwing: TranscriptionError.exportFailed)
                }
            }
            do {
                try process.run()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    private func startIndeterminateProgress() {
        stopIndeterminateProgress()
        progress = max(progress, 0.1)
        statusMessage = "Transcribing…"
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // gently oscillate between 0.3 and 0.9
            if self.progress < 0.9 { self.progress += 0.03 } else { self.progress = 0.3 }
        }
        RunLoop.main.add(progressTimer!, forMode: .common)
    }

    private func stopIndeterminateProgress(final: Bool = false) {
        progressTimer?.invalidate()
        progressTimer = nil
        if final { progress = 1.0 }
    }

    private func findOutput(in dir: URL, preferredExt: String) throws -> URL {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        if let match = contents.first(where: { $0.pathExtension.lowercased() == preferredExt.lowercased() }) {
            return match
        }
        // walk subdirs
        for url in contents where url.hasDirectoryPath {
            if let match = try? findOutput(in: url, preferredExt: preferredExt) { return match }
        }
        throw TranscriptionError.exportFailed
    }

    // MARK: - Segmentation helpers

    private func buildWordEntries(from segments: [SFTranscriptionSegment]) -> [TranscriptEntry] {
        segments.map { seg in
            TranscriptEntry(
                startTime: seg.timestamp,
                endTime: seg.timestamp + seg.duration,
                text: seg.substring
            )
        }
    }

    private func buildPhraseEntries(from segments: [SFTranscriptionSegment]) -> [TranscriptEntry] {
        var out: [TranscriptEntry] = []
        var buffer: [String] = []
        var start: TimeInterval?

        for seg in segments {
            if start == nil { start = seg.timestamp }
            buffer.append(seg.substring)
            let end = seg.timestamp + seg.duration
            let reachedDuration = (end - (start ?? seg.timestamp)) >= 5.0
            let reachedSentence = seg.substring.hasSuffix(".") || seg.substring.hasSuffix("!") || seg.substring.hasSuffix("?")
            if reachedDuration || reachedSentence {
                let text = buffer.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                if let s = start, !text.isEmpty {
                    out.append(TranscriptEntry(startTime: s, endTime: end, text: text))
                }
                buffer.removeAll(); start = nil
            }
        }

        if !buffer.isEmpty {
            let end = segments.last.map { $0.timestamp + $0.duration } ?? (start ?? 0)
            let text = buffer.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if let s = start, !text.isEmpty {
                out.append(TranscriptEntry(startTime: s, endTime: end, text: text))
            }
        }

        return out
    }

    private func buildOneSecondEntries(from segments: [SFTranscriptionSegment]) -> [TranscriptEntry] {
        guard !segments.isEmpty else { return [] }
        var buckets: [Int: [String]] = [:]

        for seg in segments {
            let startSec = Int(floor(seg.timestamp))
            // subtract a tiny epsilon to avoid attributing to next second when duration ends exactly on boundary
            let endSec = Int(floor(max(seg.timestamp + seg.duration - 0.0001, seg.timestamp)))
            for sec in startSec...endSec {
                buckets[sec, default: []].append(seg.substring)
            }
        }

        var out: [TranscriptEntry] = []
        for sec in buckets.keys.sorted() {
            let words = buckets[sec] ?? []
            let text = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let start = TimeInterval(sec)
            out.append(TranscriptEntry(startTime: start, endTime: start + 1.0, text: text))
        }

        return out
    }
}

/// Errors that can occur during transcription
public enum TranscriptionError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case noAudioTrack
    case exportFailed
    case cliNotFound(tool: String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition permission not granted. Please enable in System Settings > Privacy & Security > Speech Recognition."
        case .recognizerUnavailable:
            return "Speech recognizer is not available for this language."
        case .noAudioTrack:
            return "Video does not contain an audio track."
        case .exportFailed:
            return "Failed to extract audio from video."
        case .cliNotFound(let tool):
            return "CLI tool not found or failed to run: \(tool). Install 'whisper' (pip) or 'macwhisper' and set TRANSCRIPT_WHISPER_CMD/TRANSCRIPT_MACWHISPER_CMD if needed."
        }
    }
}
