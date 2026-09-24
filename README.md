# TeslaDash

A Tesla dashboard for macOS: floating on the desktop, it shows live vehicle data read over Bluetooth, **without going through the cloud or Tesla's developer API**. The design scenario is a Mac mini M4 kept in the car, driving an iPad Pro 12.9" as its display.

> Current status: the UI is finished and currently runs on **simulated data**. The Bluetooth read path (read-only key, pairing, reading each data category) has been verified; connecting it to a real car is the next step.

## Display modes

| Mode | Shortcut | Notes |
|---|---|---|
| Small square | ⌘1 | 360×360, like a desktop widget |
| Vertical | ⌘2 | Minimum width 200, fits beside a web page; each module sits on its own tile |
| Horizontal | ⌘3 | Speed centered and largest; enlarges proportionally when the window is dragged bigger |
| Dashboard | ⌘4 | Full screen or windowed |

- Always on top (⌘T), drag handle, minimum size limits, remembers each mode's position
- Background follows system light/dark mode, or can be forced to white/black
- Speed colors: <60 white, 60–80 yellow, 80–100 orange, 100–120 red-orange, >120 red
- Bluetooth status: blue = connected, red with a slash = disconnected
- Stale-data warning: a module dims and shows "x seconds ago" when its data hasn't updated for too long
- Speed digit effect, switchable from the right-click menu: flip clock / roll / jump
- Clock shows month/day and weekday ("9/24 星期四 16:30"); in the narrow vertical bar the date is stacked in front of the time
- Road speed-limit sign + two-level overspeed alert (≥10% faint slow flash, ≥20% deep fast flash). **Hidden by default until a real speed-limit source is available**; turn on 模拟限速 in the menu to demo

## Displayed data

Speed, gear, power, battery (% + km), charging (power, time remaining), cabin/outside temperature, A/C set temperature and fan speed, four tire pressures, doors/windows/lock/Sentry, location map, navigation summary, and the current time.

**Music**: reads the song NetEase Cloud Music is playing on this Mac (title, artist, cover, exact progress). Everything is read locally; nothing goes over the network.

## How it works

- **Vehicle data**: Tesla's official [vehicle-command](https://github.com/teslamotors/vehicle-command) talks to the car over BLE. The Mac is paired as a **read-only key (`vehicle_monitor`)** and cannot unlock or control the car.
- **NetEase Cloud Music**: macOS 15.4+ blocks apps from reading "Now Playing" directly. [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3, included in `vendor/`) reads it through the system's `/usr/bin/perl`. If it fails, the app falls back to NetEase's local play-history database.
- UI: SwiftUI + AppKit. Builds with the Command Line Tools alone; no Xcode needed.

## Build

```bash
./scripts/build-app.sh          # → build/TeslaDash.app (also builds the NetEase reader)
open build/TeslaDash.app
```

Bluetooth tools (only needed when connecting to a real car; requires Go):

```bash
./scripts/build-tesla-control.sh   # → bin/tesla-control, TeslaBLE.app
./bin/tesla-keygen -keyring-type keychain -key-name tesla-dash-monitor create > keys/public_key.pem
./pair.sh <VIN>                     # in the car; tap your key card on the console to confirm
./probe.sh <VIN>                    # read each data category once to check what's available
```

## Directory layout

```
Sources/TeslaDash/          Main app (UI, window modes, simulated data)
Sources/NeteaseNowPlaying/  NetEase Cloud Music now-playing reader
Sources/NeteaseProbe/       Standalone test window for the above
scripts/                    Build scripts
vendor/mediaremote-adapter/ Third-party (BSD-3)
docs/                       Font comparison images
```
