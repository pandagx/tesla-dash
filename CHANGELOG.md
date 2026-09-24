# Changelog

## Unreleased

### Added
- Road speed-limit sign (white disc, red ring) next to the speed in all four modes
- Two-level overspeed alert: a red glow behind the speed (strong in the centre, fading to the edges)
  - ≥10 % over the limit: mild (fainter, slow pulse, 1.2 s)
  - ≥20 % over (inclusive): severe (deeper, fast pulse, 0.5 s)

- Digit effect for the speed readout, switchable in the right-click / menu-bar menu (数字效果):
  翻页 flip-clock cards (SF Pro Condensed, 0.18 s per flip, only changed digits flip),
  滚动 rolling numbers (default), 直接跳变 plain jump; the choice is remembered
- Clock shows date and weekday: "9/24 星期四 16:30"; in the narrow vertical bar the date and weekday move to their own line under the time
- Navigation shows "未导航" (not navigating) when the car has no active route; the vertical
  mode now always keeps the navigation tile. Only the car's own navigation is synced
  (phone navigation isn't visible to the car)

### Notes
- The posted road speed limit is **not available over BLE** (the protocol only exposes the
  owner's own "Speed Limit Mode" cap). The car has it on the CAN bus only. Until a real source
  exists, the sign and alert are hidden; pass `-mockSpeedLimit YES` to demo with simulated limits.

### Fixed
- Vertical mode at its narrowest width truncated three-digit speeds ("12…")

## v0.1.0 — 2026-09-24

First version: the UI is complete and runs on simulated data.

### Display
- Four display modes: square, vertical, strip, dashboard (⌘1–⌘4)
- Pin on top (⌘T), drag handle at the top, minimum size per mode, window position remembered per mode
- Follows system light/dark, with optional forced white/black background
- Strip scales with the window (speed grows fastest, other info grows gently)
- Vertical: separate modules on tinted tiles; tyre pressure compressed to one row; navigation above the map
- Font: SF Pro Expanded (switchable in `Typeface.current`)
- Visual hierarchy: speed largest; gear/battery next; tyre pressure / climate / lock small and dim

### Data
- Speed (five colour bands), gear, power / regen
- Battery %, range km, charging power and time remaining
- Climate: cabin/outside temperature, driver/passenger set temperature, fan level, AUTO
- Four tyre pressures (low values highlighted), doors/windows/lock/Sentry
- Navigation summary: destination, minutes/km remaining, ETA, arrival battery, traffic delay
- Bluetooth connection indicator; stale data dims and shows its age
- Simulated scenarios: driving, highway, charging, parked, asleep, out of range

### Music
- Reads NetEase Cloud Music's current track locally: title, artist, cover, exact progress (follows seeking)
- Long titles scroll as a marquee

### Bluetooth (verified)
- Built the official vehicle-command; `vehicle_monitor` read-only key role confirmed available
- Bluetooth runs inside a .app wrapper (a bare CLI gets killed by macOS privacy checks)
- Pairing and probe scripts are ready; real-vehicle hookup is pending

### Not supported (by design)
- Autopilot status: not present in the BLE protocol
- Lyrics: not stored locally; they would need a network fetch, which the user declined
