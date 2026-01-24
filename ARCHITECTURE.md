# Architecture Overview

Transcript Player is built with a modular architecture using Swift Package Manager. Each module has a specific responsibility and clear boundaries.

## Module Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     TranscriptPlayer                         │
│                      (Main App)                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │           MainContentView.swift                    │     │
│  │  - Coordinates video player and transcript         │     │
│  │  - Handles file import/export                      │     │
│  │  - Syncs time between modules                      │     │
│  └────────────────────────────────────────────────────┘     │
└──────────────┬─────────────────────────┬────────────────────┘
               │                         │
       ┌───────▼────────┐       ┌───────▼────────┐
       │ VideoPlayer    │       │  Transcript    │
       │    Module      │       │    Module      │
       └───────┬────────┘       └───────┬────────┘
               │                        │
               │         ┌──────────────▼──────────┐
               └────────►│   SharedUtilities       │
                         │  - TranscriptEntry      │
                         │  - TimeFormatter        │
                         │  - TranscriptFormat     │
                         └─────────────────────────┘
```

## Modules

### 1. SharedUtilities

**Purpose**: Common data models and utilities used across modules.

**Key Files**:
- `TranscriptEntry.swift` - Core data model for transcript entries
- `TimeFormatter.swift` - Time conversion utilities (SRT, VTT, display formats)

**Dependencies**: None (pure Swift)

### 2. VideoPlayerModule

**Purpose**: Video playback functionality using AVKit.

**Key Files**:
- `VideoPlayerViewModel.swift` - Manages video playback state
- `VideoPlayerView.swift` - SwiftUI view for video player UI

**Features**:
- Play/pause/seek controls
- Playback speed adjustment (0.5x to 2x)
- Volume control
- Time observation and synchronization
- Support for multiple video formats

**Dependencies**:
- SharedUtilities
- AVFoundation
- AVKit

### 3. TranscriptModule

**Purpose**: Transcript display, editing, and format conversion.

**Key Files**:
- `TranscriptParser.swift` - Format parsers (SRT, VTT, JSON)
- `TranscriptViewModel.swift` - Manages transcript state
- `TranscriptView.swift` - SwiftUI view for transcript UI

**Features**:
- Multi-format parsing (SRT, VTT, JSON)
- Search functionality with debouncing
- Auto-highlight current entry
- In-line editing
- Export to multiple formats
- Format auto-detection

**Dependencies**:
- SharedUtilities

### 4. TranscriptPlayer (Main App)

**Purpose**: Application entry point and coordination.

**Key Files**:
- `TranscriptPlayerApp.swift` - App lifecycle and window setup
- `MainContentView.swift` - Main UI coordination

**Features**:
- File import (video and transcript)
- Export dialog management
- Time synchronization between modules
- Toolbar and menu commands

**Dependencies**:
- VideoPlayerModule
- TranscriptModule
- SharedUtilities

## Data Flow

### 1. Video Playback Time → Transcript Highlight

```
VideoPlayerViewModel
    │ (time observer updates currentTime)
    ├─► onTimeUpdate closure
    └─► TranscriptViewModel.updateCurrentTime()
            └─► Updates currentEntryID
                    └─► TranscriptView auto-scrolls and highlights
```

### 2. Transcript Entry Click → Video Seek

```
User clicks entry in TranscriptView
    └─► onEntryTapped closure
            └─► VideoPlayerViewModel.seek(to: entry.startTime)
                    └─► AVPlayer seeks to timestamp
```

### 3. Transcript Import

```
User selects file
    └─► MainContentView.handleTranscriptImport()
            └─► TranscriptViewModel.loadTranscript()
                    ├─► TranscriptParserFactory.detectFormat()
                    ├─► Get appropriate parser (SRT/VTT/JSON)
                    └─► Parse and populate entries
```

### 4. Transcript Export

```
User selects format from menu
    └─► MainContentView exports
            └─► TranscriptViewModel.exportTranscript(format:)
                    ├─► Get appropriate parser
                    └─► Generate formatted string
                            └─► Save to file
```

## Design Patterns

### MVVM (Model-View-ViewModel)

Each module follows MVVM:
- **Model**: `TranscriptEntry`, `TranscriptFormat`, `AVPlayer`
- **View**: SwiftUI views (`VideoPlayerView`, `TranscriptView`)
- **ViewModel**: `VideoPlayerViewModel`, `TranscriptViewModel`

### Factory Pattern

`TranscriptParserFactory` creates appropriate parsers based on format.

### Strategy Pattern

`TranscriptParser` protocol with different implementations (SRT, VTT, JSON).

### Observer Pattern

- Combine publishers for reactive state management
- AVPlayer time observers for playback synchronization
- SwiftUI `@Published` properties for UI updates

## Thread Safety

- All ViewModels are marked `@MainActor`
- Time observers use `Task { @MainActor }` for thread-safe updates
- Combine publishers automatically dispatch on main queue

## Extensibility Points

### Adding New Transcript Formats

1. Implement `TranscriptParser` protocol
2. Add case to `TranscriptFormat` enum
3. Update `TranscriptParserFactory`

### Adding New Video Features

Extend `VideoPlayerViewModel` and `VideoPlayerView` - fully isolated from transcript logic.

### Adding New Transcript Features

Extend `TranscriptViewModel` and `TranscriptView` - fully isolated from video logic.

## Testing Strategy

Each module can be tested independently:

- **SharedUtilities**: Unit test time formatting and data models
- **VideoPlayerModule**: Mock AVPlayer for playback tests
- **TranscriptModule**: Test parsers with sample files
- **Main App**: Integration tests for time sync

## Build System

Uses Swift Package Manager with local package dependencies:

```swift
TranscriptPlayer Package
    ├── depends on VideoPlayerModule
    │       └── depends on SharedUtilities
    ├── depends on TranscriptModule
    │       └── depends on SharedUtilities
    └── depends on SharedUtilities
```

This ensures:
- Clear dependency graph
- Fast incremental builds
- Module isolation
- Easy testing
