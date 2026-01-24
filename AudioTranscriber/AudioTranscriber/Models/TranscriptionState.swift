import Foundation

/// Represents the current state of the transcription process
enum TranscriptionState: Equatable {
    case idle
    case loading(fileName: String)
    case extractingAudio(fileName: String)
    case transcribing(progress: Double, fileName: String)
    case completed(segments: [TranscriptSegment])
    case error(message: String)

    var isProcessing: Bool {
        switch self {
        case .loading, .extractingAudio, .transcribing:
            return true
        default:
            return false
        }
    }

    var statusMessage: String {
        switch self {
        case .idle:
            return "Drop an MP3 or MP4 file to transcribe"
        case .loading(let fileName):
            return "Loading \(fileName)..."
        case .extractingAudio(let fileName):
            return "Extracting audio from \(fileName)..."
        case .transcribing(let progress, let fileName):
            let percentage = Int(progress * 100)
            return "Transcribing \(fileName)... \(percentage)%"
        case .completed(let segments):
            return "Transcription complete - \(segments.count) segments"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var progressValue: Double? {
        switch self {
        case .transcribing(let progress, _):
            return progress
        default:
            return nil
        }
    }

    static func == (lhs: TranscriptionState, rhs: TranscriptionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading(let l), .loading(let r)):
            return l == r
        case (.extractingAudio(let l), .extractingAudio(let r)):
            return l == r
        case (.transcribing(let lp, let ln), .transcribing(let rp, let rn)):
            return lp == rp && ln == rn
        case (.completed(let l), .completed(let r)):
            return l == r
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}
