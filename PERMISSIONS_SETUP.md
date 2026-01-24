# TranscriptPlayer Permissions Setup

## CRITICAL: Fix Privacy & Permissions Issues

Your app needs proper permissions to work. Follow these steps:

## Step 1: Open in Xcode (REQUIRED)

```bash
open Package.swift
```

This opens the project in Xcode.

## Step 2: Configure Signing & Capabilities

1. In Xcode, select **TranscriptPlayer** target (top left)
2. Go to **Signing & Capabilities** tab
3. Add your **Apple Developer Account** or **Personal Team**

## Step 3: Add Required Capabilities

Click **+ Capability** button and add:

### ✅ Audio Input
- Needed for extracting audio from video files
- Automatically adds microphone entitlement

### ✅ User Selected Files (Read/Write)
- Allows app to access videos you select
- Click the checkbox for **User Selected File (Read/Write)**

### ✅ Download Folder Access (Optional but recommended)
- Allows opening videos from Downloads folder

## Step 4: Verify Info.plist Entries

The following are already in `TranscriptPlayer/Resources/Info.plist`:

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>TranscriptPlayer needs speech recognition to automatically generate transcripts from video audio.</string>

<key>NSMicrophoneUsageDescription</key>
<string>TranscriptPlayer needs to access audio from video files to create transcripts.</string>
```

## Step 5: Test Permissions

1. **Build & Run** from Xcode (⌘R)
2. On first launch, macOS will prompt:
   - ✅ "Allow Speech Recognition?" → Click **OK**
   - ✅ "Allow Microphone Access?" → Click **OK**
3. Load a video
4. System should automatically start transcribing

## Troubleshooting

### If Speech Recognition Fails:

1. Open **System Settings** → **Privacy & Security** → **Speech Recognition**
2. Enable **TranscriptPlayer**

### If Microphone Access Denied:

1. Open **System Settings** → **Privacy & Security** → **Microphone**
2. Enable **TranscriptPlayer**

### If File Access Fails:

1. The app uses **User Selected Files** (sandbox-safe)
2. You must use the **File → Open** dialog
3. Direct file paths won't work without Full Disk Access

## Alternative: Disable Sandbox (Development Only)

⚠️ **NOT RECOMMENDED FOR PRODUCTION**

In Xcode Signing & Capabilities:
1. Find **App Sandbox**
2. **Remove** App Sandbox capability
3. This disables all sandboxing (use only for testing)

## Command Line Build (No Permissions)

```bash
swift build
```

⚠️ Command-line builds **DON'T include entitlements**. You must:
- Run from Xcode for permissions to work
- Or code-sign manually with entitlements:

```bash
codesign --force --sign - \
  --entitlements TranscriptPlayer.entitlements \
  .build/debug/TranscriptPlayer
```

## Verify Current Permissions

Check what permissions your built app has:

```bash
codesign -d --entitlements - .build/debug/TranscriptPlayer
```

Should show:
```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

---

**After following these steps, your app will have all required permissions!**
