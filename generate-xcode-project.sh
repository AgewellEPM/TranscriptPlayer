#!/bin/bash

# Generate Xcode project for Transcript Player
# This script creates an Xcode project from the Swift Package

set -e

echo "🔨 Generating Xcode project..."

# Navigate to project directory
cd "$(dirname "$0")"

# Generate Xcode project
swift package generate-xcodeproj

echo "✅ Xcode project generated successfully!"
echo ""
echo "To open the project:"
echo "  open TranscriptPlayer.xcodeproj"
echo ""
echo "Or use Xcode directly:"
echo "  xed ."
