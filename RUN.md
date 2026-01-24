# Running TranscriptPlayer

The app is built and ready! However, Swift Package executables need to be run from Xcode to get proper window management.

## ✅ Recommended: Run from Xcode

Xcode is already open with your project. To run the app:

1. **In Xcode:**
   - Select the **TranscriptPlayer** scheme (top bar, near the Play button)
   - Click the **Play** button (▶) or press `⌘R`
   - The app window will appear!

2. **First time setup in Xcode:**
   - If you don't see the scheme selector, click the scheme dropdown
   - Choose "TranscriptPlayer" from the list
   - Make sure it says "My Mac" as the destination

## 🎯 What You'll See

Once running from Xcode, the app window will show:
- **Left side**: Video player (currently empty with "Open Video" button)
- **Right side**: Transcript panel with search bar
- **Toolbar**: Open Video, Open Transcript, and Export buttons

## 🧪 Testing the App

1. **Load a video:**
   - Click "Open Video" button
   - Select any MP4, MOV, or AVI file

2. **Load a transcript:**
   - Click "Open Transcript" button
   - Navigate to: `TranscriptPlayer/SampleTranscripts/`
   - Choose `sample.srt`, `sample.vtt`, or `sample.json`

3. **Try the features:**
   - Click on transcript text → video jumps to timestamp
   - Play video → transcript auto-highlights
   - Search in the search bar
   - Right-click entry → Edit
   - Export menu → Save in different formats

## 🔧 Alternative: Create Proper App Bundle

If you want a standalone .app file:

```bash
cd TranscriptPlayer

# Create Xcode project
swift package generate-xcodeproj
open TranscriptPlayer.xcodeproj

# In Xcode:
# 1. Select TranscriptPlayer scheme
# 2. Product → Archive
# 3. Distribute App → Copy App
```

## 📝 Current Status

✅ Project built successfully
✅ Xcode is open with your project
✅ All modules compiled
⏳ **Next step:** Press `⌘R` in Xcode to run

## 💡 Why Run from Xcode?

Swift Package executables (command-line style) don't automatically register with macOS as GUI applications. Running from Xcode:
- Creates proper app bundle
- Registers windows with system
- Enables proper macOS integration
- Provides debugging tools
