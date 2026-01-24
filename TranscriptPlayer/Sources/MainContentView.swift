import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import AppKit
import VideoPlayerModule
import TranscriptModule
import SharedUtilities

/// Main content view combining video player and transcript
struct MainContentView: View {

    @StateObject private var videoViewModel = VideoPlayerViewModel()
    @StateObject private var transcriptViewModel = TranscriptViewModel()
    @StateObject private var transcriptionService = TranscriptionService()
    private let metadataService = VideoMetadataService()

    @State private var showingFileImporter = false
    @State private var showingTranscriptImporter = false
    @State private var showingExportDialog = false
    @State private var exportFormat: TranscriptFormat = .srt
    @State private var currentVideoURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var statusMessage = ""
    @State private var showStatus = false

    var body: some View {
        HSplitView {
            // Video player (left side)
            VideoPlayerView(viewModel: videoViewModel, onOpenVideo: { url in
                // Use the same workflow as file importer
                handleVideoImport(.success(url))
            })
                .frame(minWidth: 400)

            // Transcript panel (center)
            TranscriptView(viewModel: transcriptViewModel) { entry in
                // Seek to timestamp when entry is tapped
                videoViewModel.seek(to: entry.startTime)
            }
            .frame(minWidth: 250, idealWidth: 350)

            // Metadata panel (right side) - for body camera footage
            MetadataDisplayView(metadataService: videoViewModel.metadataService)
                .frame(minWidth: 250, idealWidth: 350)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showingFileImporter = true }) {
                    Label("Open Video", systemImage: "video.badge.plus")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { showingTranscriptImporter = true }) {
                    Label("Load Transcript File", systemImage: "doc.text")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { extractAudioFromVideo() }) {
                    Label("Extract Audio", systemImage: "waveform.circle")
                }
                .disabled(currentVideoURL == nil)
            }

            ToolbarItem(placement: .automatic) {
                Menu {
                    // Engine selection
                    Picker("Engine", selection: Binding(
                        get: { transcriptionService.backend },
                        set: { transcriptionService.backend = $0 }
                    )) {
                        Text("Apple Speech").tag(TranscriptionBackend.appleSpeech)
                        Text("Whisper (CLI)").tag(TranscriptionBackend.whisperCLI)
                        Text("MacWhisper").tag(TranscriptionBackend.macWhisper)
                    }

                    ForEach(TranscriptFormat.allCases, id: \.self) { format in
                        Button(format.displayName) {
                            exportFormat = format
                            showingExportDialog = true
                        }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(transcriptViewModel.entries.isEmpty)
            }

            // Granularity picker for transcript segmentation
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Granularity", selection: Binding(
                        get: { transcriptionService.granularity },
                        set: { transcriptionService.granularity = $0 }
                    )) {
                        Text("Captions (2–3s)").tag(TranscriptionGranularity.captions)
                        Text("Phrases").tag(TranscriptionGranularity.phrases)
                        Text("1s Buckets").tag(TranscriptionGranularity.oneSecond)
                        Text("Words").tag(TranscriptionGranularity.words)
                    }
                    Divider()
                    Picker("Language", selection: Binding(
                        get: { transcriptionService.languageCode },
                        set: { transcriptionService.languageCode = $0 }
                    )) {
                        Text("English").tag("en")
                        Text("Spanish").tag("es")
                        Text("French").tag("fr")
                        Text("German").tag("de")
                    }
                    Text("Model: \(transcriptionService.whisperModel)")
                } label: {
                    Label("Granularity", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie, .avi],
            onCompletion: handleVideoImport
        )
        .fileImporter(
            isPresented: $showingTranscriptImporter,
            allowedContentTypes: [.plainText, .json],
            onCompletion: handleTranscriptImport
        )
        .fileExporter(
            isPresented: $showingExportDialog,
            document: TranscriptDocument(content: transcriptViewModel.exportTranscript(format: exportFormat)),
            contentType: .plainText,
            defaultFilename: "transcript.\(exportFormat.fileExtension)"
        ) { result in
            if case .failure(let error) = result {
                print("Export failed: \(error.localizedDescription)")
            }
        }
        .overlay(alignment: .bottom) {
            if showStatus {
                statusToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if transcriptionService.isTranscribing {
                transcriptionProgressView
            }
        }
        .alert("Transcription Error", isPresented: $showingError) {
            Button("OK") { }
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
                    NSWorkspace.shared.open(url)
                }
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            setupVideoTimeSync()
        }
    }

    private var transcriptionProgressView: some View {
        VStack(spacing: 16) {
            ProgressView(value: transcriptionService.progress) {
                Text(transcriptionService.statusMessage)
                    .font(.headline)
            }
            .frame(width: 300)

            Button("Cancel") {
                transcriptionService.cancel()
            }
        }
        .padding(32)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }

    private var statusToast: some View {
        Text(statusMessage)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.bottom, 20)
    }

    // MARK: - Private Methods

    private func handleVideoImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            print("DEBUG: Failed to import video")
            showStatusMessage("Failed to import video")
            return
        }

        print("DEBUG: Video imported successfully: \(url.lastPathComponent)")
        currentVideoURL = url

        // NEW WORKFLOW: Extract audio FIRST, then transcribe, then load video
        Task {
            do {
                // Check for existing transcript in metadata before doing any work
                if let existingEntries = try await metadataService.loadTranscript(from: url) {
                    print("DEBUG: Found existing transcript with \(existingEntries.count) entries!")
                    showStatusMessage("✅ Loaded transcript from metadata")

                    // Load transcript
                    let jsonContent = convertEntriesToJSON(existingEntries)
                    try transcriptViewModel.loadTranscript(content: jsonContent, format: .json)

                    // Load video
                    videoViewModel.loadVideo(from: url)
                    return
                }

                // No existing transcript - extract audio first
                showStatusMessage("Extracting audio...")
                print("DEBUG: Extracting audio from video...")

                let audioURL = try await extractAndSaveAudio(from: url)
                print("DEBUG: Audio extracted to: \(audioURL.lastPathComponent)")

                // Transcribe using audio file
                showStatusMessage("Transcribing with SpeechAnalyzer...")
                print("DEBUG: Starting transcription with audio file...")

                let entries = try await transcriptionService.transcribe(audioURL: audioURL)
                print("DEBUG: Transcription complete! Got \(entries.count) entries")

                if entries.isEmpty {
                    showStatusMessage("⚠️ No speech detected in audio")
                } else {
                    // Load entries into transcript view model
                    let jsonContent = convertEntriesToJSON(entries)
                    try transcriptViewModel.loadTranscript(content: jsonContent, format: .json)
                    showStatusMessage("✅ Transcript generated with \(entries.count) entries")

                    // Save transcript to video metadata for next time
                    saveTranscriptToMetadata(entries: entries)
                }

                // THEN load and display video
                videoViewModel.loadVideo(from: url)
                print("DEBUG: Video loaded and ready")

            } catch {
                print("DEBUG: Error in video import workflow: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showingError = true
                showStatusMessage("❌ Failed to process video")

                // Still load video even if transcription fails
                videoViewModel.loadVideo(from: url)
            }
        }
    }

    private func showStatusMessage(_ message: String) {
        statusMessage = message
        withAnimation {
            showStatus = true
        }

        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showStatus = false
            }
        }
    }

    private func convertEntriesToJSON(_ entries: [TranscriptEntry]) -> String {
        // Use JSONEncoder to ensure proper escaping of text/newlines
        let encoder = JSONEncoder()
        // Keep compact output; pretty not required
        guard let data = try? encoder.encode(entries),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func handleTranscriptImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }

        do {
            try transcriptViewModel.loadTranscript(from: url)
        } catch {
            print("Failed to load transcript: \(error.localizedDescription)")
        }
    }

    private func setupVideoTimeSync() {
        // Sync video time to transcript
        videoViewModel.onTimeUpdate = { [weak transcriptViewModel] time in
            Task { @MainActor in
                transcriptViewModel?.updateCurrentTime(time)
            }
        }
    }

    /// Save transcript to video metadata for instant loading next time
    private func saveTranscriptToMetadata(entries: [TranscriptEntry]) {
        guard let videoURL = currentVideoURL else { return }

        Task {
            do {
                print("DEBUG: Saving transcript to video metadata...")
                let outputURL = try await metadataService.saveTranscript(entries, to: videoURL)
                print("DEBUG: Transcript saved to metadata at: \(outputURL.lastPathComponent)")
                // Note: This creates a new file with metadata. You can replace the original if needed.
            } catch {
                print("DEBUG: Failed to save transcript to metadata: \(error.localizedDescription)")
                // Non-critical error, transcript is still usable
            }
        }
    }

    /// Extract audio from currently loaded video as separate file
    private func extractAudioFromVideo() {
        guard let videoURL = currentVideoURL else {
            showStatusMessage("⚠️ No video loaded")
            return
        }

        // Automatically save in same folder as video
        let videoDirectory = videoURL.deletingLastPathComponent()
        let audioFilename = videoURL.deletingPathExtension().lastPathComponent + "_audio.m4a"
        let outputURL = videoDirectory.appendingPathComponent(audioFilename)

        showStatusMessage("Extracting audio...")

        Task {
            do {
                let extractedURL = try await performAudioExtraction(from: videoURL, to: outputURL)
                print("Audio extracted successfully to: \(extractedURL.path)")
                showStatusMessage("✅ Audio saved: \(extractedURL.lastPathComponent)")
            } catch {
                print("Audio extraction failed: \(error.localizedDescription)")
                showStatusMessage("❌ Audio extraction failed")
                errorMessage = "Failed to extract audio: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    /// Extract and save audio to same directory as video
    private func extractAndSaveAudio(from videoURL: URL) async throws -> URL {
        let audioDir = videoURL.deletingLastPathComponent()
        let audioFilename = videoURL.deletingPathExtension().lastPathComponent + "_audio.m4a"
        let audioURL = audioDir.appendingPathComponent(audioFilename)

        // Reuse existing performAudioExtraction()
        return try await performAudioExtraction(from: videoURL, to: audioURL)
    }

    /// Perform audio extraction using AVAssetExportSession
    private func performAudioExtraction(from videoURL: URL, to outputURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw NSError(domain: "AudioExtraction", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create export session"
            ])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Export only audio tracks
        await exportSession.export()

        guard exportSession.status == .completed else {
            if let error = exportSession.error {
                throw error
            }
            throw NSError(domain: "AudioExtraction", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Export failed with status: \(exportSession.status.rawValue)"
            ])
        }

        return outputURL
    }
}

/// Document wrapper for transcript export
struct TranscriptDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var content: String

    init(content: String = "") {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
