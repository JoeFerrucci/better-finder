#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
swift build -c release --disable-sandbox
APP="$PWD/build/Better Finder.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/BetterFinder "$APP/Contents/MacOS/BetterFinder"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>BetterFinder</string>
<key>CFBundleIdentifier</key><string>com.joe.better-finder</string>
<key>CFBundleName</key><string>Better Finder</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSDownloadsFolderUsageDescription</key><string>Browse and filter files in your Downloads folder.</string>
<key>NSDesktopFolderUsageDescription</key><string>Browse files when you choose Desktop.</string>
<key>NSDocumentsFolderUsageDescription</key><string>Browse files when you choose Documents.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
printf '%s\n' "$APP"
