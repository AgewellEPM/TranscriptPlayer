import SwiftUI
import UniformTypeIdentifiers

/// View displaying the transcribed segments with export options
struct TranscriptView: View {
    let segments: [TranscriptSegment]

    @State private var showExportOptions = false
    @State private var copiedToClipboard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with actions
            HStack {
                Text("Transcript")
                    .font(.headline)

                Spacer()

                // Copy button
                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                        Text(copiedToClipboard ? "Copied!" : "Copy")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(segments.isEmpty)

                // Export button
                Button(action: { showExportOptions = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(segments.isEmpty)
            }
            .padding()

            Divider()

            // Transcript content
            if segments.isEmpty {
                VStack {
                    Spacer()
                    Text("No transcript available")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(segments) { segment in
                            SegmentRow(segment: segment)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .fileExporter(
            isPresented: $showExportOptions,
            document: TranscriptDocument(segments: segments),
            contentType: .plainText,
            defaultFilename: "transcript.txt"
        ) { result in
            if case .failure(let error) = result {
                print("Export failed: \(error.localizedDescription)")
            }
        }
    }

    private func copyToClipboard() {
        let text = segments.asPlainText()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
}

/// Individual segment row view
struct SegmentRow: View {
    let segment: TranscriptSegment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(segment.formattedTimeRange)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(segment.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

/// Document wrapper for file export
struct TranscriptDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    let segments: [TranscriptSegment]

    init(segments: [TranscriptSegment]) {
        self.segments = segments
    }

    init(configuration: ReadConfiguration) throws {
        segments = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let text = segments.asPlainText()
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    TranscriptView(segments: [
        TranscriptSegment(startTime: 0, endTime: 5.5, text: "Hello and welcome to this audio recording."),
        TranscriptSegment(startTime: 5.5, endTime: 12.3, text: "Today we're going to talk about something interesting."),
        TranscriptSegment(startTime: 12.3, endTime: 18.0, text: "Let's get started with the first topic."),
    ])
    .frame(width: 600, height: 400)
}
