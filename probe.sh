#!/bin/zsh
# Feasibility probe: reads every BLE state category once and records result + latency.
# Never sends `wake`; if infotainment is asleep, category reads are expected to fail.
cd "${0:A:h}"
VIN="${1:?usage: ./probe.sh <VIN>}"
OUT="probe-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

TC=(./tc.sh -ble -vin "$VIN" -keyring-type keychain -key-name tesla-dash-monitor)

run() {
  local name="$1"; shift
  local t0=$(perl -MTime::HiRes=time -e 'printf "%.0f", time*1000')
  "$@" > "$OUT/$name.json" 2> "$OUT/$name.err"
  local rc=$?
  local t1=$(perl -MTime::HiRes=time -e 'printf "%.0f", time*1000')
  printf "%-22s %s  %5d ms\n" "$name" "$([ $rc -eq 0 ] && echo OK || echo FAIL)" $((t1 - t0)) | tee -a "$OUT/summary.txt"
}

# VCSEC only: works while infotainment sleeps, no key required.
run body-controller-state ./tc.sh -ble -vin "$VIN" body-controller-state

for c in charge climate drive location closures tire-pressure media software-update \
         charge-schedule precondition-schedule parental-controls media-detail; do
  run "$c" "${TC[@]}" state "$c"
done

echo "结果目录: $OUT"
