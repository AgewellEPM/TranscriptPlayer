# Auto-Transcription Feature

TranscriptPlayer now includes **automatic transcript generation** using Apple's Speech Recognition framework - just like QuickTime!

## 🎯 How It Works

When you load a video, the app automatically:
1. Extracts the audio track from the video
2. Runs speech recognition on the audio
3. Generates timestamped transcript entries
4. Displays them in the transcript panel

**No manual transcript files needed!**

## 🚀 Using Auto-Transcription

### First Time Setup

1. **Grant Permission:**
   - When you first load a video, macOS will ask for Speech Recognition permission
   - Click "OK" to allow TranscriptPlayer to transcribe audio
   - This only needs to be done once

2. **Load a Video:**
   - Click "Open Video" button or press `⌘O`
   - Select any video file with audio
   - Transcription starts automatically!

### What You'll See

1. **Progress Overlay:**
   - "Extracting audio..." - Getting audio from video
   - "Transcribing audio..." - Converting speech to text
   - Progress bar shows completion percentage
   - Cancel button to stop transcription

2. **Transcript Appears:**
   - Timestamped entries appear in the right panel
   - Entries are automatically synced with video playback
   - Click any entry to jump to that timestamp
   - Auto-highlights current entry as video plays

### Manual Transcription

If auto-transcription is disabled or you want to regenerate:

1. Load a video first
2. Click "Generate Transcript" button in toolbar
3. Wait for transcription to complete

## 🎛️ Features

- **Multiple Languages:** Uses your Mac's system language for recognition
- **High Accuracy:** Powered by Apple's Speech Recognition AI
- **Smart Chunking:** Groups words into readable sentences
- **Editable:** Edit any transcript entry after generation
- **Exportable:** Save as SRT, VTT, or JSON format

## 📝 Supported Videos

- Any video format with an audio track
- MP4, MOV, AVI, etc.
- Audio must be clear speech (not music or noise)
- Better audio quality = better transcription accuracy

## ⚙️ System Requirements

- **macOS 13.0+** (Ventura or later recommended)
- **Speech Recognition permission** granted in System Settings
- **Audio track** in the video file

## 🔧 Privacy & Permissions

### What Permission is Needed?

TranscriptPlayer needs **Speech Recognition** permission to transcribe audio.

**macOS will ask you to grant this permission when you first load a video.**

### If Permission is Denied

You'll see an error:
> "Speech recognition permission not granted. Please enable in System Settings > Privacy & Security > Speech Recognition."

To fix:
1. Open **System Settings**
2. Go to **Privacy & Security** → **Speech Recognition**
3. Enable **TranscriptPlayer**
4. Restart the app

### Where is Data Processed?

- **On-Device:** Transcription happens on your Mac
- **No Cloud:** Audio is NOT sent to servers
- **Temporary Files:** Audio is extracted temporarily, then deleted
- **Your Privacy:** Nothing is uploaded or shared

## 🎬 Example Workflow

```
1. Open TranscriptPlayer
2. Click "Open Video"
3. Select "my-video.mp4"
4. [Permission dialog appears - Click "OK"]
5. [Progress overlay shows: "Extracting audio... 10%"]
6. [Progress overlay shows: "Transcribing audio... 50%"]
7. Transcript appears in right panel!
8. Click on any line to jump to that moment
9. Edit text if needed (right-click → Edit)
10. Export to SRT for use in other apps
```

## 💡 Tips for Best Results

1. **Clear Audio:** Videos with clear speech transcribe better
2. **Minimize Background Noise:** Quiet environments work best
3. **One Speaker:** Single speaker videos are more accurate
4. **Standard Accent:** System recognizes common accents better
5. **Check Language:** Ensure video language matches system language

## 🐛 Troubleshooting

### "Video does not contain an audio track"
- The video file has no audio
- Try a different video with audio

### "Speech recognizer is not available"
- Your Mac doesn't support Speech Recognition for the selected language
- Try changing system language or use a different video

### "Transcription is slow"
- Large videos take longer to process
- Progress bar shows current status
- You can cancel and try again

### "Transcription produces gibberish"
- Video might be music or non-speech audio
- Background noise is too loud
- Try a video with clearer speech

## 📚 What's Next?

After generating a transcript:
- **Edit:** Right-click any entry and select "Edit"
- **Search:** Use the search bar to find specific words
- **Export:** Save as SRT, VTT, or JSON
- **Navigate:** Click entries to seek video
- **Highlight:** Watch current line highlight during playback

Enjoy automatic transcription - just like QuickTime, but better! 🎉
