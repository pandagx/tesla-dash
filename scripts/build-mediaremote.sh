#!/bin/zsh
# Builds vendor/mediaremote-adapter (BSD-3, github.com/ungive/mediaremote-adapter) into
# build/mediaremote/{MediaRemoteAdapter.framework, mediaremote-adapter.pl} without CMake.
# /usr/bin/perl is entitled to read MediaRemote on macOS 15.4+; it loads this framework.
set -e
cd "${0:A:h}/.."
SRC=vendor/mediaremote-adapter
OUT=build/mediaremote
F=$OUT/MediaRemoteAdapter.framework
rm -rf "$OUT"; mkdir -p "$F/Versions/A/Resources"
clang -arch arm64 -dynamiclib -fobjc-arc -fvisibility=default -I$SRC/include -I$SRC/src \
  $SRC/src/adapter/{env,get,globals,keys,now_playing,repeat,seek,send,shuffle,speed,stream,test}.m \
  $SRC/src/private/MediaRemote.m $SRC/src/utility/{Debounce,helpers}.m \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -install_name @rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter \
  -o "$F/Versions/A/MediaRemoteAdapter"
cat > "$F/Versions/A/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
<key>CFBundleName</key><string>MediaRemoteAdapter</string>
<key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>CFBundleVersion</key><string>0.1.0</string>
</dict></plist>
PLIST
(cd "$F" && ln -sfn A Versions/Current && ln -sfn Versions/Current/MediaRemoteAdapter MediaRemoteAdapter \
  && ln -sfn Versions/Current/Resources Resources)
codesign --force --deep --sign - "$F"
cp $SRC/bin/mediaremote-adapter.pl "$OUT/"
echo "Built $OUT"
