#!/bin/zsh
# Runs tesla-control inside TeslaBLE.app so macOS attributes Bluetooth access to the app
# (a bare CLI launched from a shell is killed by the privacy check). Prints stdout/stderr, keeps exit code.
D="${0:A:h}"; T=$(mktemp -d)
open -W -n "$D/TeslaBLE.app" --stdout "$T/out" --stderr "$T/err" --args "$@"
cat "$T/out"; cat "$T/err" >&2
if grep -q '^Error' "$T/err"; then rc=1; else rc=0; fi
rm -rf "$T"; exit $rc
