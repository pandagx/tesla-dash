import SwiftUI
import MapKit

/// Full-screen layout: speed dominates the top-left; everything else is secondary.
struct DashboardView: View {
    let store: VehicleStore

    private var s: VehicleSnapshot { store.snapshot }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            VStack(spacing: 14) {
                TopBar(store: store)
                if let banner = bannerText {
                    Banner(text: banner, color: s.status == .outOfRange ? Theme.red : Theme.amber)
                }
                HStack(spacing: 14) {
                    Card(title: "驾驶", freshness: store.freshness(s.drive?.updatedAt, staleAfter: 5)) {
                        if let d = s.drive { DriveContent(drive: d) }
                    }
                    Card(title: "导航", freshness: store.freshness(s.nav?.updatedAt ?? s.drive?.updatedAt, staleAfter: 60)) {
                        NavContent(nav: s.nav, drive: s.drive, now: store.now)
                    }
                    .frame(width: w * 0.33)
                }
                // Shrink the top row when the banner takes space, so the music bar stays on screen.
                .frame(height: geo.size.height * (bannerText == nil ? 0.44 : 0.40))

                HStack(spacing: 14) {
                    Card(title: "电池", freshness: store.freshness(s.charge?.updatedAt, staleAfter: 60)) {
                        if let c = s.charge { BatteryContent(charge: c) }
                    }
                    .frame(width: w * 0.27)
                    Card(title: "空调", freshness: store.freshness(s.climate?.updatedAt, staleAfter: 60)) {
                        if let c = s.climate { ClimateContent(climate: c) }
                    }
                    .frame(width: w * 0.25)
                    Card(title: "车辆", freshness: store.freshness(s.closures?.updatedAt, staleAfter: 60)) {
                        VehicleContent(closures: s.closures, tires: s.tires,
                                       tiresStale: store.freshness(s.tires?.updatedAt, staleAfter: 120)?.isStale ?? true,
                                       odometer: s.drive?.odometer)
                    }
                }

                MusicBar() // NetEase Cloud Music on this Mac; hidden when nothing is playing
            }
            .padding(20)
            .padding(.top, 18) // room for the traffic-light buttons
        }
        .background(Theme.bg)
    }

    private var bannerText: String? {
        switch s.status {
        case .asleep: "车辆休眠中 · 仅锁车状态实时更新，其余为最后读取的数据（不会唤醒车辆）"
        case .outOfRange: "蓝牙未连接 · 车辆不在范围内，显示最后读取的数据"
        default: nil
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @Bindable var store: VehicleStore

    var body: some View {
        let s = store.snapshot
        HStack(spacing: 12) {
            Text(s.name).font(.label(17, .semibold)).foregroundStyle(Theme.secondary)
            Chip(text: s.status.label, systemImage: statusIcon(s.status), color: s.status.color)
            HStack(spacing: 6) {
                BluetoothIcon(connected: s.bleConnected, size: 14)
                Text(s.bleConnected ? "已连接" : "已断开")
            }
            .font(.label(12, .semibold))
            .foregroundStyle(s.bleConnected ? Theme.blue : Theme.red)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background((s.bleConnected ? Theme.blue : Theme.red).opacity(0.14), in: Capsule())
            Spacer()
            Picker("模拟场景", selection: $store.scenario) {
                ForEach(Scenario.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 280)
            .opacity(0.6)
            .help("模拟数据：切换场景")
            ClockText(now: store.now, size: 20)
                .padding(.leading, 8)
            WindowControls()
        }
    }

    private func statusIcon(_ s: CarStatus) -> String {
        switch s {
        case .driving: "steeringwheel"
        case .charging: "bolt.fill"
        case .parked: "parkingsign"
        case .asleep: "moon.fill"
        case .outOfRange: "questionmark"
        }
    }
}

struct Banner: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
            Text(text)
            Spacer()
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Drive

struct DriveContent: View {
    let drive: DriveState

    var body: some View {
        HStack(alignment: .center, spacing: 32) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: -20) {
                    SpeedText(speed: drive.speed, size: 250)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("km/h").font(.label(18)).foregroundStyle(Theme.tertiary)
                        .padding(.leading, 12)
                }
                .overspeedFlash(drive.isWellOverLimit, cornerRadius: 24)
                if let limit = drive.speedLimit { SpeedLimitSign(limit: limit, size: 88).padding(.top, 36) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 28) {
                GearSelector(gear: drive.gear)
                PowerMeter(power: drive.power)
            }
            .frame(width: 250)
        }
        .frame(maxHeight: .infinity)
    }
}

struct GearSelector: View {
    let gear: Gear

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Gear.allCases, id: \.self) { g in
                Text(g.rawValue)
                    .font(.num(22, .semibold))
                    .foregroundStyle(g == gear ? Color.white : Theme.tertiary.opacity(0.7))
                    .frame(width: 52, height: 46)
                    .background(g == gear ? Theme.blue : Color.clear,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(5)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Horizontal power bar: regen grows left from zero (green), output grows right (blue).
struct PowerMeter: View {
    let power: Double
    var compact = false
    private let minP = -80.0, maxP = 250.0

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(power < 0 ? "动能回收" : "功率").foregroundStyle(Theme.tertiary)
                Spacer()
                Text("\(power > 0 ? "+" : "")\(Int(power)) kW")
                    .font(.num(compact ? 11 : 15))
                    .foregroundStyle(power < 0 ? Theme.green : Theme.secondary)
            }
            .font(.label(compact ? 10 : 12))
            GeometryReader { g in
                let zeroX = g.size.width * (-minP / (maxP - minP))
                let clamped = min(maxP, max(minP, power))
                let x = g.size.width * ((clamped - minP) / (maxP - minP))
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule()
                        .fill(power < 0 ? Theme.green : Theme.blue)
                        .frame(width: max(4, abs(x - zeroX)))
                        .offset(x: min(x, zeroX))
                    Rectangle().fill(Theme.secondary).frame(width: 2, height: 18).offset(x: zeroX - 1)
                }
                .frame(height: compact ? 4 : 8)
                .frame(maxHeight: .infinity)
                .animation(.easeOut(duration: 0.45), value: power)
            }
            .frame(height: compact ? 10 : 16)
        }
    }
}

// MARK: - Navigation

struct NavContent: View {
    let nav: NavState?
    let drive: DriveState?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let nav {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered").foregroundStyle(Theme.blue)
                    Text(nav.destination).lineLimit(1)
                }
                .font(.label(16, .semibold))
                .foregroundStyle(Theme.text)

                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(nav.minutesToArrival.rounded())) 分钟").font(.num(20)).foregroundStyle(Theme.text)
                        Text("\(nav.kmToArrival.formatted(.number.precision(.fractionLength(1)))) km")
                            .font(.num(14, .medium)).foregroundStyle(Theme.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(now.addingTimeInterval(nav.minutesToArrival * 60),
                             format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                            .font(.num(20)).foregroundStyle(Theme.secondary)
                        Text("预计到达").font(.system(size: 13)).foregroundStyle(Theme.secondary)
                    }
                    if let pct = nav.arrivalBatteryPercent {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(pct)%").font(.num(20)).foregroundStyle(Theme.secondary)
                            Text("到达电量").font(.system(size: 13)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                if nav.trafficDelayMinutes >= 1 {
                    Label("拥堵延误 \(Int(nav.trafficDelayMinutes)) 分钟", systemImage: "car.2.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.amber)
                }
            } else {
                Label("未在导航", systemImage: "location.slash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.secondary)
            }
            if let drive {
                LocationContent(drive: drive)
            }
        }
    }
}

// MARK: - Battery

struct BatteryContent: View {
    let charge: ChargeState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(charge.level)").font(.num(40, .medium)).foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                Text("%").font(.num(16)).foregroundStyle(Theme.secondary)
                Spacer()
                Text("\(Int(charge.rangeKm)) km").font(.num(18)).foregroundStyle(Theme.secondary)
            }
            BatteryBar(level: charge.level, limit: charge.limit, charging: charge.isCharging)
            Spacer(minLength: 0)
            if charge.isCharging {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "bolt.fill").foregroundStyle(Theme.green)
                    Text("剩余 \(chargeDuration(charge.minutesToFull))").font(.num(16, .medium)).foregroundStyle(Theme.green)
                    Text("→ \(charge.limit)%").font(.num(12)).foregroundStyle(Theme.secondary)
                }
                Text("\(charge.chargerType) · \(Int(charge.power)) kW · +\(Int(charge.addedKmPerHour)) km/h")
                    .font(.num(11))
                    .foregroundStyle(Theme.green.opacity(0.8))
            } else {
                Text("充电上限 \(charge.limit)% · 未充电")
                    .font(.label(12))
                    .foregroundStyle(Theme.tertiary)
            }
        }
    }
}

func chargeDuration(_ m: Int) -> String {
    m >= 60 ? "\(m / 60) 小时 \(m % 60) 分" : "\(m) 分钟"
}

struct BatteryBar: View {
    let level: Int
    let limit: Int
    let charging: Bool

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.track)
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color)
                    .frame(width: w * CGFloat(level) / 100)
                    .animation(.easeOut(duration: 0.5), value: level)
                Rectangle().fill(Theme.text.opacity(0.7))
                    .frame(width: 2, height: 26)
                    .offset(x: w * CGFloat(limit) / 100 - 1)
            }
        }
        .frame(height: 10)
    }

    private var color: Color {
        if charging { return Theme.green }
        if level <= 20 { return Theme.red }
        return Theme.text.opacity(0.85)
    }
}

// MARK: - Climate

func tempText(_ v: Double) -> String {
    "\(v.formatted(.number.precision(.fractionLength(1))))°"
}

struct ClimateContent: View {
    let climate: ClimateState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(tempText(climate.inside)).font(.num(28)).foregroundStyle(Theme.text)
                    Text("车内").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(tempText(climate.outside)).font(.num(16)).foregroundStyle(Theme.secondary)
                    Text("车外").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
            }
            Spacer(minLength: 0)
            if climate.isOn {
                HStack(spacing: 16) {
                    setting("主驾", tempText(climate.driverSetTemp))
                    setting("副驾", tempText(climate.passengerSetTemp))
                }
                HStack(spacing: 8) {
                    Image(systemName: "fan.fill").foregroundStyle(Theme.blue)
                    FanLevel(level: climate.fanSpeed)
                    Text("风量 \(climate.fanSpeed)").font(.num(12)).foregroundStyle(Theme.secondary)
                    if climate.isAuto {
                        Text("AUTO").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.blue)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.blue.opacity(0.15), in: Capsule())
                    }
                }
            } else {
                Label("空调关闭", systemImage: "fan")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.secondary)
            }
        }
    }

    private func setting(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(k).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            Text(v).font(.num(15)).foregroundStyle(Theme.blue)
        }
    }
}

/// Ten small bars, filled up to the fan level.
struct FanLevel: View {
    let level: Int
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...10, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i <= level ? Theme.blue : Theme.track)
                    .frame(width: 3, height: 4 + CGFloat(i))
            }
        }
    }
}

// MARK: - Vehicle (closures + tires)

struct VehicleContent: View {
    let closures: ClosuresState?
    let tires: TireState?
    let tiresStale: Bool
    var odometer: Double?

    var body: some View {
        HStack(spacing: 18) {
            GeometryReader { g in
                // Car silhouette scales to the card height; tyre labels sit beside each wheel.
                let carH = min(190, g.size.height)
                let carW = carH * 0.49
                ZStack {
                    CarTopView(closures: closures).frame(width: carW, height: carH)
                    tireLabel(.frontLeft).offset(x: -carW / 2 - 44, y: -carH * 0.26)
                    tireLabel(.frontRight).offset(x: carW / 2 + 44, y: -carH * 0.26)
                    tireLabel(.rearLeft).offset(x: -carW / 2 - 44, y: carH * 0.26)
                    tireLabel(.rearRight).offset(x: carW / 2 + 44, y: carH * 0.26)
                }
                .frame(width: g.size.width, height: g.size.height)
            }

            VStack(alignment: .leading, spacing: 10) {
                if let c = closures {
                    status(c.locked ? "已锁车" : "未锁车", c.locked ? "lock.fill" : "lock.open.fill",
                           c.locked ? Theme.green : Theme.amber)
                    status(c.sentry ? "哨兵开启" : "哨兵关闭", "eye", c.sentry ? Theme.red : Theme.secondary)
                    status(openSummary(c), c.openItemsCount == 0 ? "checkmark.circle" : "exclamationmark.triangle.fill",
                           c.openItemsCount == 0 ? Theme.secondary : Theme.amber)
                }
                if let t = tires, t.pressure.values.contains(where: { $0 < TireState.lowThreshold }) {
                    status("胎压偏低", "exclamationmark.circle.fill", Theme.amber)
                }
                Spacer(minLength: 0)
                if let odometer {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(odometer.formatted(.number.precision(.fractionLength(0)))) km")
                            .font(.num(15, .medium)).foregroundStyle(Theme.secondary)
                        Text("总里程").font(.system(size: 11)).foregroundStyle(Theme.tertiary)
                    }
                }
            }
            .frame(width: 118, alignment: .leading)
        }
    }

    private func tireLabel(_ corner: Corner) -> some View {
        let p = tires?.pressure[corner]
        let low = (p ?? 9) < TireState.lowThreshold
        return VStack(spacing: 0) {
            Text(p.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "--")
                .font(.num(16))
                .foregroundStyle(low ? Theme.amber : Theme.secondary)
            Text("bar").font(.system(size: 11)).foregroundStyle(Theme.tertiary)
        }
        .opacity(tiresStale ? 0.45 : 1)
    }

    private func status(_ text: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).frame(width: 18)
            Text(text)
        }
        .font(.label(12))
        .foregroundStyle(color.opacity(0.9))
    }

    private func openSummary(_ c: ClosuresState) -> String {
        var items: [String] = []
        if !c.openDoors.isEmpty { items.append("\(c.openDoors.count) 门") }
        if c.frunkOpen { items.append("前备箱") }
        if c.trunkOpen { items.append("后备箱") }
        if c.windowsOpen { items.append("车窗") }
        return items.isEmpty ? "门窗已关" : items.joined(separator: "、") + " 未关"
    }
}

extension ClosuresState {
    var openItemsCount: Int {
        openDoors.count + (frunkOpen ? 1 : 0) + (trunkOpen ? 1 : 0) + (windowsOpen ? 1 : 0)
    }
}

/// Minimal top-down car silhouette; open doors / frunk / trunk light up amber.
struct CarTopView: View {
    let closures: ClosuresState?

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                ForEach(Array(Corner.allCases.enumerated()), id: \.offset) { _, c in
                    RoundedRectangle(cornerRadius: w * 0.03)
                        .fill(Theme.tertiary)
                        .frame(width: w * 0.11, height: h * 0.17)
                        .position(x: isLeft(c) ? w * 0.03 : w * 0.97, y: isFront(c) ? h * 0.24 : h * 0.76)
                }
                RoundedRectangle(cornerRadius: w * 0.42, style: .continuous)
                    .fill(Theme.carBody)
                    .overlay(RoundedRectangle(cornerRadius: w * 0.42, style: .continuous)
                        .strokeBorder(Theme.cardEdge, lineWidth: 1.5))
                    .padding(.horizontal, w * 0.05)
                RoundedRectangle(cornerRadius: w * 0.17, style: .continuous)
                    .fill(Theme.carGlass)
                    .frame(width: w * 0.66, height: h * 0.50)
                    .position(x: w / 2, y: h * 0.53)
                Capsule().fill(closures?.frunkOpen == true ? Theme.amber : Color.clear)
                    .frame(width: w * 0.5, height: 5).position(x: w / 2, y: h * 0.04)
                Capsule().fill(closures?.trunkOpen == true ? Theme.amber : Color.clear)
                    .frame(width: w * 0.5, height: 5).position(x: w / 2, y: h * 0.96)
                ForEach(Array(Corner.allCases.enumerated()), id: \.offset) { _, c in
                    Capsule()
                        .fill(closures?.openDoors.contains(c) == true ? Theme.amber : Color.clear)
                        .frame(width: 5, height: h * 0.2)
                        .position(x: isLeft(c) ? w * 0.07 : w * 0.93, y: isFront(c) ? h * 0.42 : h * 0.63)
                }
                Image(systemName: closures?.locked == false ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: max(10, w * 0.17), weight: .semibold))
                    .foregroundStyle(closures?.locked == false ? Theme.amber : Theme.secondary)
                    .position(x: w / 2, y: h * 0.53)
            }
        }
    }

    private func isLeft(_ c: Corner) -> Bool { c == .frontLeft || c == .rearLeft }
    private func isFront(_ c: Corner) -> Bool { c == .frontLeft || c == .frontRight }
}

// MARK: - Location

struct LocationContent: View {
    let drive: DriveState
    var compact = false
    // `State` used directly: the @State macro plugin ships with Xcode, not the Command Line Tools.
    private let position = State<MapCameraPosition>(initialValue: .automatic)

    private var coord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: drive.latitude, longitude: drive.longitude)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Map(position: position.projectedValue, interactionModes: []) {
                Annotation("", coordinate: coord) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(drive.heading))
                        .padding(7)
                        .background(Theme.blue, in: Circle())
                        .shadow(color: Theme.blue.opacity(0.6), radius: 8)
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onAppear { follow() }
            .onChange(of: drive.latitude) { follow() }

            if !compact { HStack {
                Text("\(direction(drive.heading)) \(Int(drive.heading))°")
                Spacer()
                Text("\(drive.latitude.formatted(.number.precision(.fractionLength(4)))), \(drive.longitude.formatted(.number.precision(.fractionLength(4))))")
                    .font(.num(10))
            }
            .font(.label(11))
            .foregroundStyle(Theme.tertiary) }
        }
    }

    private func follow() {
        position.wrappedValue = .camera(MapCamera(centerCoordinate: coord, distance: 1800))
    }

    private func direction(_ h: Double) -> String {
        let names = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        let i = Int(((h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) + 22.5) / 45) % 8
        return "朝" + names[i]
    }
}
