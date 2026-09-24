#!/bin/zsh
# One-time pairing: enrolls the Mac's key as a read-only (vehicle_monitor) key.
# Run inside the car, then tap the key card on the center console when prompted.
set -e
cd "${0:A:h}"
VIN="${1:?usage: ./pair.sh <VIN>}"

./tc.sh -ble -vin "$VIN" \
  add-key-request keys/public_key.pem vehicle_monitor cloud_key

echo "请求已发出：请在 30 秒内把钥匙卡放在中控台读卡区（手机无线充电板附近），并在车机屏幕上确认。"
