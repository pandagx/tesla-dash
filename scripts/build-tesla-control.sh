#!/bin/zsh
# Fetches Tesla's official vehicle-command (pinned commit), builds tesla-control / tesla-keygen
# into bin/, and wraps tesla-control in TeslaBLE.app. macOS kills a bare CLI that touches
# Bluetooth without a usage description, so BLE calls go through the app (see tc.sh).
# Needs Go (e.g. ~/.local/go/bin/go).
set -e
cd "${0:A:h}/.."
COMMIT=f61e29e8e622f1f831daff60bcc24976201ff81d
export PATH="$HOME/.local/go/bin:$PATH"

if [ ! -d vendor/vehicle-command ]; then
  git clone -q https://github.com/teslamotors/vehicle-command.git vendor/vehicle-command
fi
git -C vendor/vehicle-command fetch -q --depth 1 origin $COMMIT 2>/dev/null || true
git -C vendor/vehicle-command checkout -q $COMMIT
mkdir -p bin
(cd vendor/vehicle-command && go build -o ../../bin/ ./cmd/tesla-control ./cmd/tesla-keygen)

A=TeslaBLE.app
rm -rf $A; mkdir -p $A/Contents/MacOS
cp bin/tesla-control $A/Contents/MacOS/tesla-control
cat > $A/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.gaoxin.tesla-ble</string>
  <key>CFBundleName</key><string>TeslaBLE</string>
  <key>CFBundleExecutable</key><string>tesla-control</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSBackgroundOnly</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>通过蓝牙读取特斯拉车辆状态（只读）。</string>
</dict></plist>
PLIST
codesign --force -s - $A
echo "Built bin/ and $A"
