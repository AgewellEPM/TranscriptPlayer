import SwiftUI

/// View displaying transcription progress
struct TranscriptionProgressView: View {
    let state: TranscriptionState

    var body: some View {
        VStack(spacing: 12) {
            if state.isProcessing {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.bottom, 4)
            }

            Text(state.statusMessage)
                .font(.headline)
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)

            if let progress = state.progressValue {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
            }
        }
        .padding()
    }

    private var textColor: Color {
        switch state {
        case .error:
            return .red
        case .completed:
            return .green
        default:
            return .secondary
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        TranscriptionProgressView(state: .idle)
        TranscriptionProgressView(state: .loading(fileName: "audio.mp3"))
        TranscriptionProgressView(state: .transcribing(progress: 0.45, fileName: "audio.mp3"))
        TranscriptionProgressView(state: .error(message: "Something went wrong"))
    }
    .frame(width: 400, height: 400)
}
