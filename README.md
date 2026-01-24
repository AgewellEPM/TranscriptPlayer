# Transcript Player

A modular macOS video player application similar to QuickTime with **automatic transcript generation**. Built with SwiftUI, AVFoundation, and Apple's Speech Recognition framework.

## ✨ Key Features

- **🎤 Auto-Transcription**: Automatically generate transcripts from video audio - just like QuickTime!
- **🎬 Video Playback**: Full-featured video player with standard controls (play/pause, seek, volume, playback speed)
- **📝 Transcript Integration**: Side-by-side transcript panel synchronized with video playback
- **🌍 Multiple Formats**: Support for SRT, VTT, and JSON transcript formats
- **Interactive Transcript**:
  - Click any transcript entry to jump to that timestamp
  - Auto-highlight current transcript line as video plays
  - Search through transcript content
- **Transcript Editing**: Edit transcript text and timestamps in real-time
- **Export Functionality**: Export transcripts to SRT, VTT, or JSON format
- **Modular Architecture**: Clean separation of concerns with Swift Package Manager modules

## Architecture

The app is built with a modular architecture for maintainability and extensibility:

```
TranscriptPlayer/
├── Modules/
│   ├── SharedUtilities/        # Shared data models and utilities
│   │   ├── TranscriptEntry.swift
│   │   └── TimeFormatter.swift
│   ├── VideoPlayerModule/      # Video playback logic
│   │   ├── VideoPlayerViewModel.swift
│   │   └── VideoPlayerView.swift
│   └── TranscriptModule/       # Transcript management
│       ├── TranscriptParser.swift
│       ├── TranscriptViewModel.swift
│       └── TranscriptView.swift
├── TranscriptPlayer/           # Main app target
│   └── Sources/
│       ├── TranscriptPlayerApp.swift
│       └── MainContentView.swift
└── SampleTranscripts/          # Example transcript files
```

## Building the App

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Build Methods

#### Method 1: Xcode (Recommended)

1. Open the project in Xcode:
   ```bash
   cd TranscriptPlayer
   xed .
   ```

2. Wait for Swift Package Manager to resolve dependencies

3. Select the TranscriptPlayer scheme

4. Build and run (⌘R)

#### Method 2: Command Line

```bash
cd TranscriptPlayer
swift build
swift run TranscriptPlayer
```

#### Method 3: Create Xcode Project

```bash
cd TranscriptPlayer
swift package generate-xcodeproj
open TranscriptPlayer.xcodeproj
```

## 🚀 Quick Start

### Auto-Transcription (Recommended)

1. **Open a Video**: Click "Open Video" or press ⌘O
2. **Grant Permission**: Allow Speech Recognition when prompted (first time only)
3. **Wait**: Transcript generates automatically in seconds!
4. **Navigate**: Click on any transcript entry to jump to that timestamp

### Manual Transcript Loading

1. **Open a Video**: Click "Open Video" or press ⌘O
2. **Load Transcript**: Click "Open Transcript" or press ⌘T
3. **Navigate**: Click on entries to seek to timestamps

### Other Features

- **Search**: Use the search bar to find specific text
- **Edit**: Right-click on a transcript entry and select "Edit"
- **Export**: Use the Export menu to save in SRT, VTT, or JSON format
- **Re-generate**: Click "Generate Transcript" button to re-transcribe

## Supported Video Formats

- MP4 (.mp4, .m4v)
- MOV (.mov)
- AVI (.avi)
- Any format supported by AVFoundation

## Supported Transcript Formats

### SRT (SubRip)
```
1
00:00:00,000 --> 00:00:03,500
Welcome to the demo.

2
00:00:03,500 --> 00:00:07,000
This is a sample transcript.
```

### VTT (WebVTT)
```
WEBVTT

00:00:00.000 --> 00:00:03.500
Welcome to the demo.

00:00:03.500 --> 00:00:07.000
This is a sample transcript.
```

### JSON
```json
[
  {
    "startTime": 0.0,
    "endTime": 3.5,
    "text": "Welcome to the demo."
  }
]
```

## Keyboard Shortcuts

- **Space**: Play/Pause
- **⌘O**: Open Video
- **⌘T**: Open Transcript
- **⌘Return**: Save transcript edit

## Extending the App

### Adding New Transcript Formats

1. Create a new parser class conforming to `TranscriptParser` protocol
2. Add the format to `TranscriptFormat` enum in `SharedUtilities`
3. Register the parser in `TranscriptParserFactory`

### Adding New Features

Each module is independent and can be extended separately:
- **VideoPlayerModule**: Add new playback features
- **TranscriptModule**: Add new transcript management features
- **SharedUtilities**: Add shared functionality used by multiple modules

## License

MIT License - Feel free to use and modify as needed.

## Credits

Built with SwiftUI, AVFoundation, and AVKit on macOS.
