#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
architecture="$(uname -m)"
output_dir="$PWD/dist"
staging_dir="$(mktemp -d "$output_dir-stage.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
app="$staging_dir/ShellCue.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$output_dir"
cp "$binary_dir/ShellCue" "$app/Contents/MacOS/ShellCue"
chmod 755 "$app/Contents/MacOS/ShellCue"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>ShellCue</string>
  <key>CFBundleIdentifier</key><string>com.shellcue.app</string>
  <key>CFBundleName</key><string>ShellCue</string>
  <key>CFBundleDisplayName</key><string>ShellCue</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>열린 터미널 세션을 표시하고 선택한 Terminal 또는 iTerm2 세션으로 이동하기 위해 접근합니다.</string>
</dict></plist>
PLIST
/usr/bin/plutil -lint "$app/Contents/Info.plist"
# Local test signature only; this is not Developer ID signing or notarization.
/usr/bin/codesign --force --sign - "$app"
/usr/bin/codesign --verify --strict "$app"
/usr/bin/ditto "$app" "$output_dir/ShellCue.app"
archive="$output_dir/ShellCue-0.1.0-$architecture.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
printf 'App: %s\nZIP: %s\nLocal test build: not notarized.\n' "$output_dir/ShellCue.app" "$archive"
