import Foundation

/// Controls how recognition segments are grouped into transcript entries
public enum TranscriptionGranularity: String, CaseIterable, Hashable {
    /// Sentence-like chunks (punctuation or ~5s)
    case phrases
    /// One-second buckets; each second of detected speech is one line
    case oneSecond
    /// Word-level entries (debug/very fine-grained)
    case words
    /// Caption style like YouTube/Vimeo (~2–3s readable lines)
    case captions
}
