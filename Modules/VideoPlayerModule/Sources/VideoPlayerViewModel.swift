import AVFoundation
import AVKit
import Combine

/// View model for managing video playback
@MainActor
public class VideoPlayerViewModel: ObservableObject {

    @Published public var player: AVPlayer?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var volume: Float = 1.0
    @Published public var playbackSpeed: Float = 1.0

    // Timed metadata service for body camera footage
    public let metadataService = TimedMetadataService()

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var currentVideoURL: URL?

    public var onTimeUpdate: ((TimeInterval) -> Void)?

    public init() {
        setupObservers()
    }

    deinit {
        Task { @MainActor in
            removeTimeObserver()
        }
    }

    // MARK: - Public Methods

    /// Load video from URL
    public func loadVideo(from url: URL) {
        removeTimeObserver()
        currentVideoURL = url

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume
        player?.rate = 0

        setupTimeObserver()
        observePlayerItem(playerItem)

        // Setup timed metadata extraction for body camera footage
        metadataService.setupMetadataExtraction(for: playerItem)

        // Extract static metadata and check for sidecar files
        Task {
            do {
                // Extract all available metadata
                let entries = try await metadataService.extractAllMetadata(from: url)
                print("VideoPlayerViewModel: Extracted \(entries.count) metadata entries")

                // Check for sidecar files
                if let sidecarURL = await metadataService.checkForSidecarFile(videoURL: url) {
                    print("VideoPlayerViewModel: Loading sidecar file: \(sidecarURL.lastPathComponent)")
                    if let sidecarEntries = try? await metadataService.parseSidecarJSON(url: sidecarURL) {
                        print("VideoPlayerViewModel: Loaded \(sidecarEntries.count) entries from sidecar")
                    }
                }
            } catch {
                print("VideoPlayerViewModel: Error extracting metadata: \(error.localizedDescription)")
            }
        }
    }

    /// Play/pause toggle
    public func togglePlayback() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }

        isPlaying = !isPlaying
    }

    /// Seek to specific time
    public func seek(to time: TimeInterval) {
        guard let player = player else {
            print("VideoPlayerViewModel: Cannot seek - no player")
            return
        }

        print("VideoPlayerViewModel: Seeking to \(time) seconds (MM:SS = \(formatTime(time)))")

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)

        // Ensure playback is paused after seek so user can see the exact frame
        player.pause()
        isPlaying = false
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    /// Skip forward by seconds
    public func skipForward(_ seconds: TimeInterval = 10) {
        seek(to: currentTime + seconds)
    }

    /// Skip backward by seconds
    public func skipBackward(_ seconds: TimeInterval = 10) {
        seek(to: max(0, currentTime - seconds))
    }

    /// Set playback speed
    public func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = speed
        }
    }

    /// Set volume (0.0 to 1.0)
    public func setVolume(_ volume: Float) {
        self.volume = max(0, min(1, volume))
        player?.volume = self.volume
    }

    // MARK: - Private Methods

    private func setupObservers() {
        $isPlaying
            .sink { [weak self] playing in
                guard let self = self, let player = self.player else { return }
                player.rate = playing ? self.playbackSpeed : 0
            }
            .store(in: &cancellables)
    }

    private func setupTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let seconds = time.seconds
                self.currentTime = seconds.isFinite ? seconds : 0
                self.onTimeUpdate?(self.currentTime)
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func observePlayerItem(_ item: AVPlayerItem) {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .sink { [weak self] _ in
                self?.isPlaying = false
                self?.seek(to: 0)
            }
            .store(in: &cancellables)

        item.publisher(for: \.status)
            .sink { [weak self] status in
                guard status == .readyToPlay else { return }
                let durationSeconds = item.duration.seconds
                self?.duration = durationSeconds.isFinite ? durationSeconds : 0
            }
            .store(in: &cancellables)
    }
}
