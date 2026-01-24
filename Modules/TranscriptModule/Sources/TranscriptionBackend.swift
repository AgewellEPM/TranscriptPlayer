import Foundation

/// Available transcription engines
public enum TranscriptionBackend: String, CaseIterable, Hashable {
    case appleSpeech = "Apple Speech"
    case whisperCLI = "Whisper (CLI)"
    case macWhisper = "MacWhisper"
}

