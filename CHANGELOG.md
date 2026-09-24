# Changelog

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
