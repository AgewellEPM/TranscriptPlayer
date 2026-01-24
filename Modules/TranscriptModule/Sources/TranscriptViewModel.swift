import Foundation
import Combine
import SharedUtilities

/// View model for managing transcript state and operations
@MainActor
public class TranscriptViewModel: ObservableObject {

    @Published public private(set) var entries: [TranscriptEntry] = []
    @Published public var searchText: String = ""
    @Published public var filteredEntries: [TranscriptEntry] = []
    @Published public var currentEntryID: UUID?
    @Published public var currentTime: TimeInterval = 0

    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupSearchObserver()
        setupTimeObserver()
    }

    // MARK: - Public Methods

    /// Load transcript from file
    public func loadTranscript(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)

        guard let format = TranscriptParserFactory.detectFormat(from: content) else {
            throw TranscriptParseError.invalidFormat
        }

        let parser = TranscriptParserFactory.parser(for: format)
        entries = try parser.parse(content)
        filteredEntries = entries
    }

    /// Load transcript from string content
    public func loadTranscript(content: String, format: TranscriptFormat) throws {
        let parser = TranscriptParserFactory.parser(for: format)
        entries = try parser.parse(content)
        filteredEntries = entries
    }

    /// Export transcript to specified format
    public func exportTranscript(format: TranscriptFormat) -> String {
        let parser = TranscriptParserFactory.parser(for: format)
        return parser.export(entries)
    }

    /// Save transcript to file
    public func saveTranscript(to url: URL, format: TranscriptFormat) throws {
        let content = exportTranscript(format: format)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Update current playback time
    public func updateCurrentTime(_ time: TimeInterval) {
        currentTime = time
    }

    /// Update an entry's text
    public func updateEntry(_ entry: TranscriptEntry, text: String) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].text = text
        filterEntries()
    }

    /// Update an entry's timestamps
    public func updateEntry(_ entry: TranscriptEntry, startTime: TimeInterval, endTime: TimeInterval) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].startTime = startTime
        entries[index].endTime = endTime
        filterEntries()
    }

    /// Add a new entry
    public func addEntry(_ entry: TranscriptEntry) {
        entries.append(entry)
        entries.sort { $0.startTime < $1.startTime }
        filterEntries()
    }

    /// Delete an entry
    public func deleteEntry(_ entry: TranscriptEntry) {
        entries.removeAll { $0.id == entry.id }
        filterEntries()
    }

    // MARK: - Private Methods

    private func setupSearchObserver() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.filterEntries()
            }
            .store(in: &cancellables)
    }

    private func setupTimeObserver() {
        $currentTime
            .sink { [weak self] time in
                self?.updateCurrentEntry(for: time)
            }
            .store(in: &cancellables)
    }

    private func filterEntries() {
        if searchText.isEmpty {
            filteredEntries = entries
        } else {
            filteredEntries = entries.filter {
                $0.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func updateCurrentEntry(for time: TimeInterval) {
        currentEntryID = entries.first { $0.contains(time: time) }?.id
    }
}
