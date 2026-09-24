#!/bin/zsh
# Builds TeslaDash and wraps it into build/TeslaDash.app (ad-hoc signed).
set -e
cd "${0:A:h}/.."
CONFIG="${1:-release}"

[ -d build/mediaremote ] || ./scripts/build-mediaremote.sh
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/TeslaDash"

APP=build/TeslaDash.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TeslaDash"
cp -R build/mediaremote "$APP/Contents/Resources/" # NetEase now-playing adapter

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.gaoxin.tesladash</string>
  <key>CFBundleName</key><string>TeslaDash</string>
  <key>CFBundleDisplayName</key><string>TeslaDash</string>
  <key>CFBundleExecutable</key><string>TeslaDash</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>通过蓝牙读取特斯拉车辆状态（只读）。</string>
</dict></plist>
EOF

codesign --force -s - "$APP"
echo "Built $APP"
