#!/bin/bash

# TranscriptPlayer - Build and Code Sign with Entitlements
# This script ensures your app has proper permissions

echo "🔨 Building TranscriptPlayer..."
swift build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"
echo ""
echo "🔐 Code signing with entitlements..."

# Code sign the binary with entitlements
codesign --force --sign - \
  --entitlements TranscriptPlayer.entitlements \
  .build/debug/TranscriptPlayer

if [ $? -ne 0 ]; then
    echo "❌ Code signing failed!"
    exit 1
fi

echo "✅ Code signed successfully!"
echo ""
echo "🔍 Verifying entitlements..."
codesign -d --entitlements - .build/debug/TranscriptPlayer 2>&1 | grep -A 20 "<?xml"

echo ""
echo "🚀 Launching TranscriptPlayer..."
echo "   (Speech Recognition permission will be requested on first launch)"
echo ""

# Launch the app
.build/debug/TranscriptPlayer
