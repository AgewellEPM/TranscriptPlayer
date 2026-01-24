# Quick Start Guide

Get up and running with Transcript Player in 2 minutes.

## 🚀 Fastest Method (Xcode)

```bash
cd TranscriptPlayer
xed .
```

Then press `⌘R` to build and run.

## 📦 Alternative: Generate Xcode Project

```bash
cd TranscriptPlayer
./generate-xcode-project.sh
```

## 🎬 First Run

1. The app opens with a placeholder screen
2. Click "Open Video..." or toolbar button
3. Select any video file (MP4, MOV, AVI, etc.)
4. Click "Open Transcript" in toolbar
5. Select a transcript file from `SampleTranscripts/` folder
6. Click on transcript text to jump to that timestamp
7. Watch the transcript auto-highlight as the video plays

## 🧪 Testing with Sample Data

Use the sample transcript files in `SampleTranscripts/`:
- `sample.srt` - SubRip format
- `sample.vtt` - WebVTT format
- `sample.json` - JSON format

You'll need your own video file for testing. Any video will work!

## ✏️ Editing Transcripts

1. Right-click any transcript entry
2. Select "Edit"
3. Modify the text
4. Press `⌘Return` to save or "Cancel" to discard

## 💾 Exporting

1. Click "Export" in toolbar
2. Choose format (SRT, VTT, or JSON)
3. Select save location

## ⌨️ Keyboard Shortcuts

- `Space` - Play/Pause
- `⌘O` - Open Video
- `⌘T` - Open Transcript
- `⌘Return` - Save edit

## 🏗️ Project Structure

```
TranscriptPlayer/
├── Modules/                    # Modular components
│   ├── SharedUtilities/        # Data models
│   ├── VideoPlayerModule/      # Player logic
│   └── TranscriptModule/       # Transcript logic
├── TranscriptPlayer/           # Main app
├── SampleTranscripts/          # Example files
└── Package.swift               # SPM manifest
```

## 🔧 Troubleshooting

**"Cannot find module" errors in Xcode:**
- Wait for SPM to resolve dependencies (automatic)
- Or: Product → Clean Build Folder (`⇧⌘K`)

**App builds but doesn't run:**
- Check that you selected "TranscriptPlayer" scheme (not a module)

**Video won't play:**
- Ensure the video format is supported by macOS
- Try with a different video file

## 📚 Next Steps

- Read the full `README.md` for detailed documentation
- Explore the modular architecture in `Modules/`
- Customize and extend the app for your needs
