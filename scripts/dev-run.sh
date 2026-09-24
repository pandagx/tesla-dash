#!/bin/zsh
# Dev helper: relaunch the built app as a regular (Dock) app so screenshot tools can see it.
#   scripts/dev-run.sh <square|vertical|strip|dashboard> [行驶|高速|充电|停车|休眠|离开范围] [light|dark]
cd "${0:A:h}/.."
/usr/libexec/PlistBuddy -c "Set :LSUIElement false" build/TeslaDash.app/Contents/Info.plist
codesign --force -s - build/TeslaDash.app 2>/dev/null
pkill -x TeslaDash; sleep 1
open -n build/TeslaDash.app --args -mode "${1:-square}" -scenario "${2:-行驶}" ${3:+-appearance $3}
