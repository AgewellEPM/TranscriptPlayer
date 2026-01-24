# 🎬 Video Transcription for TranscriptPlayer

This folder now includes **powerful transcription tools** that work with TranscriptPlayer!

## Quick Start - 3 Ways to Transcribe

### 1️⃣ Drop & Transcribe (Easiest)
```bash
# Just drag and drop your video onto:
/Users/luke/TranscriptPlayer/drop_transcribe.sh
```

### 2️⃣ Command Line
```bash
cd /Users/luke/TranscriptPlayer
python3 transcribe_video.py /path/to/your/video.mp4
```

### 3️⃣ Batch Processing
```bash
# For multiple files (like chunks)
cd /Users/luke/Downloads
python3 /Users/luke/TranscriptPlayer/AudioTranscriber/transcribe.py .
```

## 📝 What You Get

Every transcription creates two files:

1. **`*_transcript.txt`** - Formatted transcript with timestamps
   ```
   TRANSCRIPT
   ============================================================

   [00:00:00 - 00:00:02] Hello world
   [00:00:02 - 00:00:05] This is a test video

   ============================================================
   FULL TEXT
   ============================================================

   Hello world This is a test video
   ```

2. **`*.srt`** - Subtitle file for video players
   ```
   1
   00:00:00,000 --> 00:00:02,000
   Hello world

   2
   00:00:02,000 --> 00:00:05,000
   This is a test video
   ```

## 🎯 Supported Formats

**Video:** MP4, MOV, AVI, MKV, WebM, M4V
**Audio:** M4A, MP3, WAV, AAC, FLAC

## ⚙️ Model Selection

Choose accuracy vs speed:

```bash
# Fastest (less accurate)
python3 transcribe_video.py video.mp4 tiny

# Default (balanced)
python3 transcribe_video.py video.mp4 base

# Better accuracy
python3 transcribe_video.py video.mp4 small

# Best accuracy (slower)
python3 transcribe_video.py video.mp4 medium
```

## 🔧 Requirements

1. **Python 3** with Whisper:
   ```bash
   pip install openai-whisper
   ```

2. **ffmpeg** for video processing:
   ```bash
   brew install ffmpeg
   ```

## 📁 File Structure

```
TranscriptPlayer/
├── transcribe_video.py      # Main transcription script
├── drop_transcribe.sh       # Drag & drop helper
├── AudioTranscriber/        # Original batch transcriber
│   └── transcribe.py       # For processing multiple chunks
└── Your transcripts here!
```

## 💡 Pro Tips

1. **For body cam footage with chunks:**
   ```bash
   # Put all chunks (_001.m4a, _002.m4a, etc) in one folder
   python3 AudioTranscriber/transcribe.py /path/to/folder/
   ```

2. **For single video files:**
   ```bash
   python3 transcribe_video.py /path/to/video.mp4
   ```

3. **Better accuracy for legal/court use:**
   ```bash
   python3 transcribe_video.py important_video.mp4 medium
   ```

4. **Quick test:**
   ```bash
   # Try with the sample video
   python3 transcribe_video.py /Users/luke/Downloads/chez_fray__officer_pointdujour_v2.mp4
   ```

## 🎥 Integration with TranscriptPlayer App

After transcription:
1. Open TranscriptPlayer app
2. Load your video
3. The transcript will sync automatically
4. Click any transcript line to jump to that moment
5. Edit and export as needed

## 🚀 Example Workflow

```bash
# 1. Drop your video on the script
./drop_transcribe.sh

# 2. Drag video.mp4 onto it
# Wait for transcription...

# 3. You now have:
#    - video_transcript.txt (formatted)
#    - video.srt (subtitles)

# 4. Open in TranscriptPlayer to view synced with video!
```

## ❓ Troubleshooting

**"ffmpeg not found"**
```bash
brew install ffmpeg
```

**"No module named whisper"**
```bash
pip install openai-whisper
```

**Slow transcription?**
- Use `tiny` or `base` model for faster processing
- Transcription runs locally, speed depends on your Mac

**Wrong text/gibberish?**
- Audio quality matters - clearer audio = better results
- Try `small` or `medium` model for better accuracy

---

Ready to transcribe! Just drop a video and go! 🎬✨