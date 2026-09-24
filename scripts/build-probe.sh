#!/bin/zsh
# Builds the NetEase "now playing" test tool as build/NeteaseProbe.app, bundling the
# MediaRemote adapter (scripts/build-mediaremote.sh) into Resources/mediaremote.
set -e
cd "${0:A:h}/.."
[ -d build/mediaremote ] || ./scripts/build-mediaremote.sh
swift build -c release --product NeteaseProbe
BIN="$(swift build -c release --show-bin-path)/NeteaseProbe"
APP=build/NeteaseProbe.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NeteaseProbe"
cp -R build/mediaremote "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.gaoxin.neteaseprobe</string>
  <key>CFBundleName</key><string>NeteaseProbe</string>
  <key>CFBundleExecutable</key><string>NeteaseProbe</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
codesign --force -s - "$APP"
echo "Built $APP"
