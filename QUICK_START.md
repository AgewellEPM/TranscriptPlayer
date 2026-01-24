# TranscriptPlayer - Quick Start Guide

## ⚠️ IMPORTANT: Fix Permissions Issue

Your app can't access Speech Recognition without proper setup. Follow these steps:

## 1. Open in Xcode (REQUIRED)

```bash
cd /Users/luke/TranscriptPlayer
open Package.swift
```

**Wait for Xcode to open** (may take 10-20 seconds)

## 2. In Xcode: Configure Team

1. Select **TranscriptPlayer** in the project navigator (left sidebar)
2. Select **TranscriptPlayer** target (under TARGETS)
3. Go to **Signing & Capabilities** tab
4. Under **Team**, select:
   - Your Apple Developer account, OR
   - "Add Account..." to add your Apple ID for free Personal Team

## 3. Add Speech Recognition Capability

Still in **Signing & Capabilities**:

1. Click **+ Capability** (top left of capabilities section)
2. Search for and add: **"Audio Input"**
3. This automatically enables microphone access for speech recognition

## 4. Build & Run

Press **⌘R** or click the **Play** button (▶️) in Xcode toolbar

### On First Launch:

macOS will show permission dialogs:

1. **"TranscriptPlayer" would like to access Speech Recognition**
   - Click **OK**

2. **"TranscriptPlayer" would like to access the microphone**
   - Click **OK**

## 5. Test It

1. Click **Open Video** button
2. Select a video file (MP4, MOV, etc.)
3. Video plays and transcription starts automatically
4. Watch the **transcript panel** fill with timed text
5. **Click any transcript entry** to jump to that moment in the video

---

## Alternative: Manual Code Signing (Advanced)

If you don't want to use Xcode:

```bash
# Build
swift build

# Sign with entitlements
codesign --force --sign - \
  --entitlements TranscriptPlayer.entitlements \
  .build/debug/TranscriptPlayer

# Verify
codesign -d --entitlements - .build/debug/TranscriptPlayer
```

⚠️ **Note**: Command-line apps may not show permission dialogs properly. Xcode is recommended.

---

## Troubleshooting

### "Speech recognition not authorized"

1. Open **System Settings** → **Privacy & Security**
2. Click **Speech Recognition** (left sidebar)
3. Enable **TranscriptPlayer**
4. Restart the app

### "Speech recognition unavailable"

1. Make sure you're running macOS 13+ (Ventura or newer)
2. Check that your Mac supports on-device speech recognition
3. Go to **System Settings** → **Siri & Spotlight**
4. Ensure **Language** is set to English (US) or supported language

### No permission dialogs appear

1. Delete the app
2. Reset permissions:
   ```bash
   tccutil reset All
   ```
3. Rebuild and run from Xcode

---

## Files Created

- ✅ `TranscriptPlayer/Resources/Info.plist` - Privacy descriptions
- ✅ `TranscriptPlayer.entitlements` - App capabilities
- ✅ `sign-and-run.sh` - Helper script (optional)

**Your app is now properly configured for Speech Recognition!**
