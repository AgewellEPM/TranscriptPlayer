import SwiftUI
import UniformTypeIdentifiers

/// Supported audio extensions
private let supportedExtensions = ["mp3", "mp4", "m4a", "m4v", "wav", "aac"]

/// Main view with folder selection and transcript display
struct ContentView: View {
    @StateObject private var transcriptionService = TranscriptionService()
    @State private var state: TranscriptionState = .idle
    @State private var selectedFolder: URL?

    var body: some View {
        HSplitView {
            // Left side: Folder selection and controls
            VStack(spacing: 20) {
                Spacer()

                // File icon
                Image(systemName: state.isProcessing ? "waveform" : "doc.badge.gearshape")
                    .font(.system(size: 64))
                    .foregroundColor(state.isProcessing ? .green : .accentColor)
                    .symbolEffect(.pulse, isActive: state.isProcessing)

                // Selected folder display
                if let folder = selectedFolder {
                    Text(folder.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Status and progress
                TranscriptionProgressView(state: state)

                // Choose File button
                Button(action: selectFile) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Choose Audio File...")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(state.isProcessing)

                // Cancel button when processing
                if state.isProcessing {
                    Button("Cancel") {
                        transcriptionService.cancelTranscription()
                        state = .idle
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .frame(minWidth: 300, idealWidth: 350)
            .padding()

            // Right side: Transcript view
            TranscriptView(segments: currentSegments)
                .frame(minWidth: 400, idealWidth: 500)
        }
        .frame(minWidth: 750, minHeight: 500)
    }

    private var currentSegments: [TranscriptSegment] {
        if case .completed(let segments) = state {
            return segments
        }
        return []
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .movie]
        panel.message = "Select audio file(s) to transcribe - select multiple chunks in order"

        if panel.runModal() == .OK {
            let urls = panel.urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
            if let first = urls.first {
                selectedFolder = first
            }
            Task {
                await processFiles(urls: urls)
            }
        }
    }

    private func processFiles(urls: [URL]) async {
        let fileName = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files"
        state = .loading(fileName: fileName)

        do {
            state = .transcribing(progress: 0, fileName: fileName)

            let segments = try await transcriptionService.transcribeChunks(urls: urls) { progress in
                state = .transcribing(progress: progress, fileName: fileName)
            }

            state = .completed(segments: segments)
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }
}

#Preview {
    ContentView()
}
