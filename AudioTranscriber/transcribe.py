#!/usr/bin/env python3
"""
Audio Transcriber using Whisper (runs 100% locally)
Usage: python3 transcribe.py /path/to/audio/files/
"""

import sys
import os
import glob
import whisper
from datetime import timedelta

def format_timestamp(seconds):
    """Convert seconds to HH:MM:SS format"""
    td = timedelta(seconds=seconds)
    hours, remainder = divmod(td.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}"

def transcribe_files(folder_path, model_name="base"):
    """Transcribe all audio files in a folder"""

    # Find audio files (chunks with _001, _002 pattern, or all audio files)
    patterns = ["*_[0-9][0-9][0-9].m4a", "*_[0-9][0-9][0-9].mp3", "*.m4a", "*.mp3", "*.mp4", "*.wav"]
    files = []
    for pattern in patterns:
        files.extend(glob.glob(os.path.join(folder_path, pattern)))

    # Remove duplicates and sort
    files = sorted(set(files))

    if not files:
        print(f"No audio files found in {folder_path}")
        return

    print(f"Found {len(files)} audio file(s)")
    print(f"Loading Whisper model '{model_name}'...")
    model = whisper.load_model(model_name)

    all_segments = []
    time_offset = 0.0

    for i, filepath in enumerate(files):
        filename = os.path.basename(filepath)
        print(f"\n[{i+1}/{len(files)}] Transcribing: {filename}")

        result = model.transcribe(filepath)

        # Adjust timestamps and collect segments
        for seg in result["segments"]:
            all_segments.append({
                "start": seg["start"] + time_offset,
                "end": seg["end"] + time_offset,
                "text": seg["text"].strip()
            })

        # Update offset for next file
        if result["segments"]:
            time_offset += result["segments"][-1]["end"]

        print(f"   Got {len(result['segments'])} segments")

    # Output results
    print("\n" + "="*60)
    print("FULL TRANSCRIPT")
    print("="*60 + "\n")

    for seg in all_segments:
        start = format_timestamp(seg["start"])
        end = format_timestamp(seg["end"])
        print(f"[{start} - {end}] {seg['text']}")

    # Save to file
    output_file = os.path.join(folder_path, "transcript.txt")
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

    print(f"\n\nSaved to: {output_file}")
    return all_segments

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 transcribe.py /path/to/folder/")
        print("       python3 transcribe.py /path/to/file.m4a")
        sys.exit(1)

    path = sys.argv[1]
    model = sys.argv[2] if len(sys.argv) > 2 else "base"

    if os.path.isfile(path):
        folder = os.path.dirname(path)
        # Single file mode - just transcribe that file
        print(f"Loading Whisper model '{model}'...")
        m = whisper.load_model(model)
        result = m.transcribe(path)
        print("\nTRANSCRIPT:\n")
        for seg in result["segments"]:
            start = format_timestamp(seg["start"])
            end = format_timestamp(seg["end"])
            print(f"[{start} - {end}] {seg['text']}")
    else:
        transcribe_files(path, model)
