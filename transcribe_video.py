#!/usr/bin/env python3
"""
Video/Audio Transcriber for TranscriptPlayer
Drop a video or audio file and get a formatted transcript

Usage: python3 transcribe_video.py /path/to/video.mp4
"""

import sys
import os
import subprocess
import glob
import whisper
from datetime import timedelta
from pathlib import Path

def format_timestamp(seconds):
    """Convert seconds to HH:MM:SS format"""
    td = timedelta(seconds=seconds)
    hours, remainder = divmod(td.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}"

def extract_audio(video_path, output_dir):
    """Extract audio from video file using ffmpeg"""
    print(f"Extracting audio from video...")
    audio_path = os.path.join(output_dir, "temp_audio.m4a")

    # Use ffmpeg to extract audio
    cmd = [
        'ffmpeg', '-i', video_path,
        '-vn',  # No video
        '-acodec', 'copy' if video_path.endswith('.mp4') else 'aac',
        '-y',  # Overwrite output
        audio_path
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0 and os.path.exists(audio_path):
            return audio_path
        else:
            # Fallback to different codec
            cmd[-2] = 'aac'  # Force AAC codec
            subprocess.run(cmd, capture_output=True)
            if os.path.exists(audio_path):
                return audio_path
    except FileNotFoundError:
        print("Error: ffmpeg not found. Install with: brew install ffmpeg")
        return None

    return None

def transcribe_file(file_path, model_name="base"):
    """Transcribe a single video or audio file"""

    # Check if it's a video file
    video_extensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v']
    audio_extensions = ['.m4a', '.mp3', '.wav', '.aac', '.flac']

    file_ext = Path(file_path).suffix.lower()
    output_dir = os.path.dirname(file_path)

    # Handle video vs audio
    if file_ext in video_extensions:
        print(f"Processing video: {os.path.basename(file_path)}")
        audio_file = extract_audio(file_path, output_dir)
        if not audio_file:
            print("Failed to extract audio from video")
            return None
        cleanup_audio = True
    elif file_ext in audio_extensions:
        print(f"Processing audio: {os.path.basename(file_path)}")
        audio_file = file_path
        cleanup_audio = False
    else:
        print(f"Unsupported file type: {file_ext}")
        return None

    # Transcribe with Whisper
    print(f"Loading Whisper model '{model_name}'...")
    model = whisper.load_model(model_name)

    print("Transcribing audio...")
    result = model.transcribe(audio_file)

    # Clean up temporary audio file if needed
    if cleanup_audio and os.path.exists(audio_file):
        os.remove(audio_file)
        print("Cleaned up temporary audio file")

    # Format segments
    all_segments = []
    for seg in result["segments"]:
        all_segments.append({
            "start": seg["start"],
            "end": seg["end"],
            "text": seg["text"].strip()
        })

    # Generate output filename
    base_name = Path(file_path).stem
    output_file = os.path.join(output_dir, f"{base_name}_transcript.txt")

    # Save formatted transcript
    with open(output_file, "w") as f:
        f.write("TRANSCRIPT\n")
        f.write("="*60 + "\n\n")

        for seg in all_segments:
            start = format_timestamp(seg["start"])
            end = format_timestamp(seg["end"])
            f.write(f"[{start} - {end}] {seg['text']}\n")

        f.write("\n" + "="*60 + "\n")
        f.write("FULL TEXT\n")
        f.write("="*60 + "\n\n")
        f.write(" ".join(seg["text"] for seg in all_segments))

    print(f"\n✅ Transcript saved to: {output_file}")

    # Also save SRT format for video players
    srt_file = os.path.join(output_dir, f"{base_name}.srt")
    with open(srt_file, "w") as f:
        for i, seg in enumerate(all_segments, 1):
            start = format_timestamp(seg["start"]).replace(":", ",", 2) + ",000"
            end = format_timestamp(seg["end"]).replace(":", ",", 2) + ",000"
            f.write(f"{i}\n")
            f.write(f"{start} --> {end}\n")
            f.write(f"{seg['text']}\n\n")

    print(f"📝 SRT subtitles saved to: {srt_file}")

    return all_segments

def main():
    if len(sys.argv) < 2:
        print("TranscriptPlayer Video Transcriber")
        print("==================================")
        print("\nUsage:")
        print("  python3 transcribe_video.py /path/to/video.mp4")
        print("  python3 transcribe_video.py /path/to/audio.m4a")
        print("\nSupported formats:")
        print("  Video: mp4, mov, avi, mkv, webm, m4v")
        print("  Audio: m4a, mp3, wav, aac, flac")
        print("\nModels (optional, default=base):")
        print("  python3 transcribe_video.py video.mp4 tiny    (fastest)")
        print("  python3 transcribe_video.py video.mp4 base    (default)")
        print("  python3 transcribe_video.py video.mp4 small   (better)")
        print("  python3 transcribe_video.py video.mp4 medium  (best)")
        sys.exit(1)

    file_path = sys.argv[1]
    model = sys.argv[2] if len(sys.argv) > 2 else "base"

    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    # Check for ffmpeg
    try:
        subprocess.run(['ffmpeg', '-version'], capture_output=True)
    except FileNotFoundError:
        print("⚠️  ffmpeg not found. Install it for video support:")
        print("   brew install ffmpeg")
        if not file_path.lower().endswith(('.m4a', '.mp3', '.wav')):
            print("\n❌ Cannot process video files without ffmpeg")
            sys.exit(1)

    transcribe_file(file_path, model)

if __name__ == "__main__":
    main()