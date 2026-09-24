import NeteaseNowPlaying
import SwiftUI

extension VehicleStore {
    func freshness(_ date: Date?, staleAfter: TimeInterval) -> Freshness? {
        guard let date else { return nil }
        return Freshness(age: now.timeIntervalSince(date), staleAfter: staleAfter)
    }
}

extension CarStatus {
    var color: Color {
        switch self {
        case .driving: Theme.blue
        case .charging: Theme.green
        case .parked: Theme.secondary
        case .asleep: Theme.amber
        case .outOfRange: Theme.red
        }
    }
}

private struct StatusDot: View {
    let status: CarStatus
    var size: CGFloat = 11
    var body: some View {
        HStack(spacing: size * 0.55) {
            Circle().fill(status.color).frame(width: size * 0.55, height: size * 0.55)
            Text(status.label).foregroundStyle(status.color.opacity(0.9))
        }
        .font(.label(size, .semibold))
    }
}

private struct StaleNote: View {
    let f: Freshness?
    var body: some View {
        if let f, f.isStale {
            Label(f.label, systemImage: "clock.arrow.circlepath")
                .font(.label(10))
                .foregroundStyle(Theme.amber)
        }
    }
}

private struct MiniBatteryBar: View {
    let charge: ChargeState
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(charge.isCharging ? Theme.green : charge.level <= 20 ? Theme.red : Theme.text.opacity(0.7))
                    .frame(width: g.size.width * CGFloat(charge.level) / 100)
                    .animation(.easeOut(duration: 0.5), value: charge.level)
                Rectangle().fill(Theme.text.opacity(0.5))
                    .frame(width: 1, height: height + 4)
                    .offset(x: g.size.width * CGFloat(charge.limit) / 100)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Shared compact pieces

/// Header line for compact modes: status on the left, clock / Bluetooth / window controls top-right.
private struct CompactHeader: View {
    let store: VehicleStore
    var showName = true

    var body: some View {
        let s = store.snapshot
        HStack(spacing: 10) {
            // Drop the car name first, then the status text, when the window gets narrow.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    if showName {
                        Text(s.name).font(.label(12, .semibold)).foregroundStyle(Theme.secondary)
                    }
                    StatusDot(status: s.status)
                }
                StatusDot(status: s.status)
                Circle().fill(s.status.color).frame(width: 6, height: 6)
            }
            .lineLimit(1)
            Spacer(minLength: 6)
            ClockText(now: store.now, size: 13).fixedSize()
            BluetoothIcon(connected: s.bleConnected, size: 13)
            WindowControls()
        }
        .background(WindowDragArea()) // the whole header row also moves the window
    }
}

/// Battery: percentage is primary, range secondary, charging countdown in green.
private struct BatteryLine: View {
    let charge: ChargeState
    var pctSize: CGFloat = 20

    var body: some View {
        // Falls back to a second row for the charging countdown when the width is tight.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                levelAndRange
                Spacer(minLength: 4)
                chargingLabel
            }
            VStack(alignment: .leading, spacing: 4) {
                levelAndRange
                chargingLabel
            }
        }
        .lineLimit(1)
    }

    private var levelAndRange: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(charge.level)%").font(.num(pctSize, .medium)).foregroundStyle(Theme.text)
            Text("\(Int(charge.rangeKm)) km").font(.num(pctSize * 0.65)).foregroundStyle(Theme.secondary)
        }
        .fixedSize()
    }

    @ViewBuilder private var chargingLabel: some View {
        if charge.isCharging {
            Label("剩 \(chargeDuration(charge.minutesToFull)) → \(charge.limit)%", systemImage: "bolt.fill")
                .font(.num(pctSize * 0.55, .medium)).foregroundStyle(Theme.green)
                .fixedSize()
        }
    }
}

/// Tertiary line: A/C setpoint + fan, lock.
private struct ClimateLockLine: View {
    let climate: ClimateState?
    let closures: ClosuresState?
    var size: CGFloat = 11

    var body: some View {
        HStack(spacing: 10) {
            if let cl = climate {
                HStack(spacing: 4) {
                    Image(systemName: cl.isOn ? "fan.fill" : "fan")
                    Text(cl.isOn ? "\(tempText(cl.driverSetTemp)) · 风量 \(cl.fanSpeed)" : "空调关")
                }
                .foregroundStyle(cl.isOn ? Theme.blue.opacity(0.85) : Theme.tertiary)
            }
            if let cz = closures {
                Image(systemName: cz.locked ? "lock.fill" : "lock.open.fill")
                    .foregroundStyle(cz.locked ? Theme.tertiary : Theme.amber)
            }
        }
        .font(.num(size))
    }
}

// MARK: - Square (widget-like)

struct SquareWidget: View {
    let store: VehicleStore
    private var s: VehicleSnapshot { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CompactHeader(store: store)

            // Hero: speed.
            if let d = s.drive {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: -6) {
                        SpeedText(speed: d.speed, size: 112)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        Text("km/h").font(.label(12)).foregroundStyle(Theme.tertiary).padding(.leading, 4)
                    }
                    .overspeedFlash(d.overspeed)
                    Spacer(minLength: 0)
                    if let limit = d.speedLimit { SpeedLimitSign(limit: limit, size: 42) }
                    GearColumn(gear: d.gear, size: 12)
                }
                .opacity(store.freshness(d.updatedAt, staleAfter: 5)?.isStale == true ? 0.45 : 1)
                .frame(maxHeight: .infinity)
            }

            if let c = s.charge {
                BatteryLine(charge: c, pctSize: 20)
                MiniBatteryBar(charge: c, height: 4).padding(.top, 7)
            }

            HStack(alignment: .bottom) {
                TireGrid(tires: s.tires, size: 11, spacing: 10)
                Spacer()
                ClimateLockLine(climate: s.climate, closures: s.closures)
            }
            .padding(.top, 14)
        }
        .padding(18)
    }
}

// MARK: - Vertical bar

struct VerticalBar: View {
    let store: VehicleStore
    @Environment(NeteaseNowPlaying.self) private var music
    private var s: VehicleSnapshot { store.snapshot }

    var body: some View {
        // Each module sits on its own tinted tile; gaps between tiles separate the modules.
        VStack(alignment: .leading, spacing: 8) {
            CompactHeader(store: store).padding(.horizontal, 4)

            if s.status == .asleep || s.status == .outOfRange {
                Text(s.status == .asleep ? "休眠中 · 仅锁车状态实时" : "蓝牙断开 · 显示最后数据")
                    .font(.label(11))
                    .foregroundStyle(s.status == .asleep ? Theme.amber : Theme.red)
                    .padding(.horizontal, 4)
            }

            // Hero: speed + power.
            if let d = s.drive {
                let f = store.freshness(d.updatedAt, staleAfter: 5)
                tile(nil, f) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: -8) {
                            SpeedText(speed: d.speed, size: 96)
                                .minimumScaleFactor(0.35) // three digits must fit at 200 pt wide
                                .lineLimit(1)
                            Text("km/h").font(.label(12)).foregroundStyle(Theme.tertiary).padding(.leading, 4)
                        }
                        .overspeedFlash(d.overspeed, cornerRadius: 12)
                        Spacer(minLength: 0)
                        VStack(spacing: 8) {
                            if let limit = d.speedLimit { SpeedLimitSign(limit: limit, size: 32) }
                            GearColumn(gear: d.gear, size: 12)
                        }
                    }
                    PowerMeter(power: d.power, compact: true)
                }
            }

            if music.isRunning, music.track != nil {
                tile(nil) { MusicMini() }
            }

            tile("空调 · 车辆", store.freshness(s.climate?.updatedAt, staleAfter: 60)) {
                if let cl = s.climate {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("车内 \(tempText(cl.inside))")
                        Text("车外 \(tempText(cl.outside))")
                    }
                    .lineLimit(1)
                    .font(.num(11)).foregroundStyle(Theme.secondary)
                }
                ClimateLockLine(climate: s.climate, closures: s.closures)
            }

            if let c = s.charge {
                tile("电池", store.freshness(c.updatedAt, staleAfter: 60)) {
                    BatteryLine(charge: c, pctSize: 24)
                    MiniBatteryBar(charge: c, height: 5)
                }
            }

            // Tyres: one compact row, no car drawing.
            tile(nil, store.freshness(s.tires?.updatedAt, staleAfter: 120)) {
                HStack(alignment: .center) {
                    Text("胎压 bar").font(.label(10, .semibold)).foregroundStyle(Theme.tertiary)
                    Spacer(minLength: 8)
                    TireGrid(tires: s.tires, size: 12, spacing: 12)
                }
            }

            // Navigation sits right above the map (phone navigation is the norm, so it's secondary).
            if let n = s.nav {
                tile("导航") {
                    Text(n.destination).font(.label(13, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    let eta = Text(store.now.addingTimeInterval(n.minutesToArrival * 60),
                                   format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)) + Text(" 到达")
                    let left = Text("\(Int(n.minutesToArrival.rounded())) 分钟 · \(n.kmToArrival.formatted(.number.precision(.fractionLength(1)))) km")
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { left; Spacer(minLength: 0); eta }
                        VStack(alignment: .leading, spacing: 2) { left; eta }
                    }
                    .lineLimit(1)
                    .font(.num(11)).foregroundStyle(Theme.secondary)
                }
            }

            if let d = s.drive {
                LocationContent(drive: d, compact: true)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(12)
        .padding(.top, 4)
    }

    /// A module: optional small title + stale note, content on a lightly tinted rounded tile.
    @ViewBuilder
    private func tile<C: View>(_ title: String?, _ f: Freshness? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if title != nil || f?.isStale == true {
                HStack {
                    if let title { Text(title).font(.label(10, .semibold)).foregroundStyle(Theme.tertiary) }
                    Spacer()
                    StaleNote(f: f)
                }
            }
            content().opacity(f?.isStale == true ? 0.45 : 1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.tile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Strip

struct StripBar: View {
    let store: VehicleStore
    private var s: VehicleSnapshot { store.snapshot }

    /// Designed at 940×88; everything scales when the window is enlarged.
    private static let base = CGSize(width: 940, height: 88)

    var body: some View {
        GeometryReader { g in
            // Speed follows the height directly; side info grows more gently so the hierarchy holds.
            let k = max(1, min(g.size.height / Self.base.height, g.size.width / Self.base.width))
            let side = 1 + (k - 1) * 0.6
            let speed = max(60, g.size.height * 0.68)
            content(speed: speed, side: side)
                .frame(width: g.size.width, height: g.size.height)
        }
    }

    private func content(speed: CGFloat, side f: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Left: quiet context.
            HStack(spacing: 16 * f) {
                StatusDot(status: s.status, size: 11 * f)
                if let c = s.charge {
                    VStack(alignment: .leading, spacing: 5 * f) {
                        BatteryLine(charge: c, pctSize: 15 * f).fixedSize()
                        MiniBatteryBar(charge: c, height: 3 * f).frame(width: 110 * f)
                    }
                }
                VStack(alignment: .leading, spacing: 5 * f) {
                    ClimateLockLine(climate: s.climate, closures: nil, size: 11 * f).fixedSize()
                    MusicMini(size: 10 * f).frame(maxWidth: 170 * f, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Centre: speed is the hero.
            if let d = s.drive {
                HStack(alignment: .center, spacing: speed * 0.2) {
                    SpeedText(speed: d.speed, size: speed)
                        .frame(minWidth: speed * 2.2, alignment: .trailing)
                        .overspeedFlash(d.overspeed, cornerRadius: 10, inset: 6 * f)
                    VStack(spacing: 3 * f) {
                        Text(d.gear.rawValue)
                            .font(.num(15 * f, .semibold))
                            .foregroundStyle(d.gear == .P ? Theme.text : Color.white)
                            .frame(width: 28 * f, height: 24 * f)
                            .background(d.gear == .P ? Theme.track : Theme.blue,
                                        in: RoundedRectangle(cornerRadius: 6 * f, style: .continuous))
                        Text("km/h").font(.label(10 * f)).foregroundStyle(Theme.tertiary)
                    }
                    if let limit = d.speedLimit { SpeedLimitSign(limit: limit, size: min(speed * 0.62, 56 * f)) }
                }
                .opacity(store.freshness(d.updatedAt, staleAfter: 5)?.isStale == true ? 0.45 : 1)
                .fixedSize()
            }

            // Right: tyres, lock, clock, Bluetooth, window controls.
            HStack(spacing: 14 * f) {
                TireGrid(tires: s.tires, size: 11 * f, spacing: 8 * f)
                if let cz = s.closures {
                    Image(systemName: cz.locked ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 11 * f))
                        .foregroundStyle(cz.locked ? Theme.tertiary : Theme.amber)
                }
                ClockText(now: store.now, size: 14 * f)
                BluetoothIcon(connected: s.bleConnected, size: 13 * f)
                WindowControls()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20 * f)
    }
}
