#!/bin/bash
# Quick transcription script for TranscriptPlayer
# Just drop a video or audio file on this script

echo "🎬 TranscriptPlayer Transcriber"
echo "================================"

# Check if a file was provided
if [ $# -eq 0 ]; then
    echo "Drop a video or audio file on this script to transcribe it!"
    echo ""
    echo "Or run manually:"
    echo "  ./drop_transcribe.sh /path/to/video.mp4"
    exit 1
fi

FILE="$1"

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "❌ File not found: $FILE"
    exit 1
fi

echo "📁 Processing: $(basename "$FILE")"
echo ""

# Run the transcription
python3 /Users/luke/TranscriptPlayer/transcribe_video.py "$FILE"

echo ""
echo "✨ Done! Check the same folder as your video for:"
echo "   - *_transcript.txt (formatted transcript)"
echo "   - *.srt (subtitles for video players)"

# Keep terminal open to see results (optional)
read -p "Press Enter to close..."