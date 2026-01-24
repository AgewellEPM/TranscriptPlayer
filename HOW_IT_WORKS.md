# How TranscriptPlayer Works

## 🎯 Simple Workflow

**Upload Video → Get Transcript Automatically**

No buttons to press. No manual steps. Just like your example.

## 📽️ Step by Step

### 1. Open Video
- Click "Open Video" button (or press ⌘O)
- Select any video file

### 2. Automatic Transcription
**Happens automatically when video loads:**
- Permission request appears (first time only)
- Click "OK" to allow Speech Recognition
- Progress overlay shows: "Extracting audio..." → "Transcribing audio..."
- Transcript appears in 10-30 seconds

### 3. Use Transcript
- **Click any line** → Video jumps to that timestamp
- **Play video** → Current line highlights automatically
- **Search** → Find any word spoken in the video
- **Export** → Save as SRT, VTT, or JSON

## ⚡ What Makes It Automatic

```swift
handleVideoImport() {
    loadVideo()
    generateTranscript()  // ← Called automatically!
}
```

When you select a video, the app IMMEDIATELY starts transcription. No button press needed.

## 🔐 First Time Permission

**macOS will ask once:**
> "TranscriptPlayer would like to access Speech Recognition"

**Click "OK"** - you'll never see this again.

If you accidentally clicked "Don't Allow":
1. System Settings → Privacy & Security
2. Speech Recognition
3. Enable TranscriptPlayer

## 🎬 Example Timeline

```
0:00 - Click "Open Video"
0:01 - Select video file
0:02 - Permission dialog (first time) → Click OK
0:03 - Video loads + Progress shows "Extracting audio..."
0:05 - Progress shows "Transcribing audio... 50%"
0:10 - Transcript appears!
0:11 - Click "Hey um yeah" at 04:30 → Video jumps to 4:30
```

## 🚫 No Manual Buttons

- ❌ No "Generate Transcript" button to press
- ❌ No "Start Transcription" menu
- ❌ No configuration needed

**✅ Just open video = get transcript**

## 💡 What You See

### Before Video Loads:
```
[Empty video player]
[Empty transcript panel]
```

### After Video Loads:
```
[Video playing]              [Transcript entries:]
                            03:51 "Where is he in the..."
                            04:30 "Hey, um, yeah..."  ← Click to jump
                            05:16 "the please drop..."
```

### While Transcribing:
```
[Video playing]              [Progress overlay]
                            "Transcribing audio..."
                            [━━━━━━━░░░] 70%
```

## 🔧 If It Doesn't Work

**Check Xcode Console:**
Look for debug messages like:
- `DEBUG: Video imported successfully`
- `DEBUG: Auto-starting transcription...`
- `TranscriptionService: Authorization granted`

**If you see "Authorization denied":**
- You need to enable Speech Recognition permission
- Alert will show "Open System Settings" button

**If video has no audio:**
- Error: "Video does not contain an audio track"
- Try a different video with speech

## ✨ That's It!

**Upload video → Transcript appears automatically**

Just like your example screenshot! 🎉
