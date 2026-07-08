#!/bin/bash
set -e

# HarvestBin Build and Deploy Script
# Usage: ./build-and-deploy.sh [destination_directory]
# Example: ./build-and-deploy.sh ~/Desktop/VMApps

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default destination is Desktop
DESTINATION="${1:-$HOME/Desktop}"

cd "$PROJECT_ROOT"

# The .xcworkspace is Tuist-generated and gitignored, so (re)generate it before
# building. Tuist is resolved via mise (see .mise.toml). We generate every time
# so a fresh checkout — or one where Project.swift changed — builds cleanly.
echo "🧩 Generating Xcode workspace with Tuist..."
mise trust --quiet "$PROJECT_ROOT/.mise.toml" >/dev/null 2>&1 || true
if ! mise exec tuist -- tuist generate --no-open; then
    echo "❌ tuist generate failed"
    echo "   If this is an authentication error, note that Tuist.swift must not"
    echo "   set a cloud 'fullHandle' for local, offline builds."
    exit 1
fi

if [ ! -d "HarvestBin.xcworkspace" ]; then
    echo "❌ HarvestBin.xcworkspace was not generated"
    exit 1
fi

echo "🔨 Building HarvestBin..."

# Build HarvestBin
xcodebuild -workspace HarvestBin.xcworkspace \
    -scheme HarvestBin \
    -configuration Debug \
    -derivedDataPath ./DerivedData \
    build 2>&1 | grep -E "(BUILD|error:|warning:)" | tail -5

# Check if build succeeded
if [ ! -d "./DerivedData/Build/Products/Debug/HarvestBin.app" ]; then
    echo "❌ Build failed - HarvestBin.app not found"
    exit 1
fi

echo "✅ Build succeeded"

# Create destination directory if it doesn't exist
mkdir -p "$DESTINATION"

# Copy the app
echo "📦 Copying HarvestBin.app to $DESTINATION"
rm -rf "$DESTINATION/HarvestBin.app"
cp -R ./DerivedData/Build/Products/Debug/HarvestBin.app "$DESTINATION/"

# Create a zip as well
echo "🗜️  Creating HarvestBin.zip"
cd "$DESTINATION"
zip -r HarvestBin.zip HarvestBin.app > /dev/null 2>&1

# Show file info
echo ""
echo "✅ Deployment complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 App location:  $DESTINATION/HarvestBin.app"
echo "📦 Zip location:  $DESTINATION/HarvestBin.zip"
echo ""
echo "To install in VM:"
echo "  1. Copy HarvestBin.zip to your VM"
echo "  2. In VM: unzip HarvestBin.zip"
echo "  3. In VM: sudo mv HarvestBin.app /Applications/"
echo "  4. In VM: sudo /Applications/HarvestBin.app/Contents/MacOS/HarvestBin"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
