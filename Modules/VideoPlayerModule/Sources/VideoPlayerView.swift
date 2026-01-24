import SwiftUI
import AVKit
import AppKit

/// Custom AVPlayerView wrapper for macOS
struct CustomVideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

/// SwiftUI view for video playback
public struct VideoPlayerView: View {

    @ObservedObject public var viewModel: VideoPlayerViewModel
    public var onOpenVideo: ((URL) -> Void)?

    public init(viewModel: VideoPlayerViewModel, onOpenVideo: ((URL) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onOpenVideo = onOpenVideo
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Video player
            if let player = viewModel.player {
                CustomVideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholderView
            }

            // Controls
            VStack(spacing: 8) {
                // Progress bar
                HStack {
                    Text(TimeFormatter.toDisplayFormat(viewModel.currentTime))
                        .font(.caption)
                        .monospacedDigit()

                    Slider(
                        value: Binding(
                            get: { viewModel.currentTime },
                            set: { viewModel.seek(to: $0) }
                        ),
                        in: 0...max(viewModel.duration, 1)
                    )

                    Text(TimeFormatter.toDisplayFormat(viewModel.duration))
                        .font(.caption)
                        .monospacedDigit()
                }

                // Playback controls
                HStack(spacing: 16) {
                    // Backward
                    Button(action: { viewModel.skipBackward() }) {
                        Image(systemName: "gobackward.10")
                    }

                    // Play/Pause
                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .keyboardShortcut(.space, modifiers: [])

                    // Forward
                    Button(action: { viewModel.skipForward() }) {
                        Image(systemName: "goforward.10")
                    }

                    Spacer()

                    // Speed control
                    Menu {
                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                            Button("\(speed, specifier: "%.2f")x") {
                                viewModel.setPlaybackSpeed(Float(speed))
                            }
                        }
                    } label: {
                        Text("\(viewModel.playbackSpeed, specifier: "%.2f")x")
                            .frame(minWidth: 50)
                    }

                    // Volume
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundColor(.secondary)

                        Slider(
                            value: Binding(
                                get: { Double(viewModel.volume) },
                                set: { viewModel.setVolume(Float($0)) }
                            ),
                            in: 0...1
                        )
                        .frame(width: 80)
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No video loaded")
                .font(.headline)
                .foregroundColor(.secondary)

            Button("Open Video...") {
                openVideoFile()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func openVideoFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .avi]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadVideo(from: url)
            onOpenVideo?(url)
        }
    }
}

// Import SharedUtilities for TimeFormatter
import SharedUtilities
