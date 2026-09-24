import Foundation
import Observation

enum Scenario: String, CaseIterable, Identifiable {
    case driving = "行驶"
    case highway = "高速"
    case charging = "充电"
    case parked = "停车"
    case asleep = "休眠"
    case outOfRange = "离开范围"

    var id: String { rawValue }
}

/// Simulated vehicle feed. Produces the same shapes the BLE helper will later emit,
/// including the stale-data behaviour of sleep / out-of-range.
@Observable
final class VehicleStore {
    private(set) var snapshot = VehicleSnapshot()
    private(set) var now = Date()
    var scenario: Scenario = .driving {
        didSet { enter(scenario) }
    }

    private var timer: Timer?
    private var t: Double = 0
    private var targetSpeed: Double = 60
    /// No real speed-limit source yet, so simulated limits are off by default; toggled from the
    /// menu (模拟限速) or with `-mockSpeedLimit YES`. Persisted.
    var mockSpeedLimit = UserDefaults.standard.bool(forKey: "mockSpeedLimit") {
        didSet {
            UserDefaults.standard.set(mockSpeedLimit, forKey: "mockSpeedLimit")
            enter(scenario)
        }
    }

    init() {
        seed()
        // `-scenario 充电` on the command line picks the starting scenario (handy for screenshots).
        if let s = UserDefaults.standard.string(forKey: "scenario").flatMap(Scenario.init(rawValue:)) {
            scenario = s
        }
        enter(scenario)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick(dt: 0.5)
        }
    }

    /// Dev: pin speed / limit (used by the snapshot renderer via `-snapshotSpeed` / `-snapshotLimit`).
    func debugPin(speed: Double, limit: Double?) {
        snapshot.drive?.speed = speed
        snapshot.drive?.speedLimit = limit
    }

    private func seed() {
        let d = Date()
        snapshot.drive = DriveState(speed: 0, gear: .P, power: 0, heading: 72,
                                    latitude: 31.2304, longitude: 121.4737, odometer: 28_416.3, speedLimit: nil, updatedAt: d)
        snapshot.charge = ChargeState(level: 68, rangeKm: 362, limit: 90, isCharging: false, power: 0,
                                      addedKmPerHour: 0, minutesToFull: 0, chargerType: "", updatedAt: d)
        snapshot.climate = ClimateState(inside: 23.5, outside: 27.0, isOn: true, isAuto: true,
                                        driverSetTemp: 22.0, passengerSetTemp: 22.5, fanSpeed: 3, updatedAt: d)
        snapshot.closures = ClosuresState(locked: true, sentry: false, openDoors: [], frunkOpen: false,
                                          trunkOpen: false, windowsOpen: false, updatedAt: d)
        snapshot.tires = TireState(pressure: [.frontLeft: 2.9, .frontRight: 2.9, .rearLeft: 2.875, .rearRight: 2.5],
                                   updatedAt: d)
    }

    private func enter(_ s: Scenario) {
        let d = Date()
        snapshot.bleConnected = s != .outOfRange
        switch s {
        case .driving, .highway:
            snapshot.status = .driving
            snapshot.drive?.speedLimit = mockSpeedLimit ? (s == .highway ? 100 : 60) : nil
            snapshot.nav = NavState(destination: "上海虹桥站", minutesToArrival: 26, kmToArrival: 18.4,
                                    trafficDelayMinutes: 4, arrivalBatteryPercent: 64, updatedAt: d)
            snapshot.drive?.gear = .D
            snapshot.charge?.isCharging = false
            snapshot.closures?.locked = true
            snapshot.closures?.sentry = false
            snapshot.closures?.openDoors = []
            snapshot.climate?.isOn = true
        case .charging:
            snapshot.status = .charging
            snapshot.nav = nil
            snapshot.drive?.gear = .P
            snapshot.drive?.speedLimit = nil
            snapshot.drive?.speed = 0
            snapshot.drive?.power = 0
            snapshot.charge?.isCharging = true
            snapshot.charge?.chargerType = "超级充电"
        case .parked:
            snapshot.status = .parked
            snapshot.nav = nil
            snapshot.drive?.gear = .P
            snapshot.drive?.speedLimit = nil
            snapshot.drive?.speed = 0
            snapshot.drive?.power = 0
            snapshot.charge?.isCharging = false
            snapshot.closures?.sentry = true
            snapshot.closures?.trunkOpen = false
            snapshot.climate?.isOn = false
        case .asleep:
            // Infotainment asleep: only VCSEC (lock/closures) stays fresh; the rest is last-known.
            snapshot.status = .asleep
            snapshot.nav = nil
            let old = d.addingTimeInterval(-27 * 60)
            snapshot.drive?.speed = 0
            snapshot.drive?.gear = .P
            snapshot.drive?.power = 0
            snapshot.drive?.updatedAt = old
            snapshot.charge?.isCharging = false
            snapshot.charge?.updatedAt = old
            snapshot.climate?.isOn = false
            snapshot.climate?.updatedAt = old
            snapshot.tires?.updatedAt = old
            snapshot.closures?.sentry = false
        case .outOfRange:
            snapshot.status = .outOfRange
        }
    }

    private func tick(dt: Double) {
        t += dt
        now = Date()
        let d = now
        switch scenario {
        case .driving, .highway: tickDriving(dt: dt, at: d)
        case .charging: tickCharging(dt: dt, at: d)
        case .parked:
            snapshot.drive?.updatedAt = d
            if Int(t * 2) % 20 == 0 { touchSlowCategories(at: d) }
            snapshot.closures?.updatedAt = d
        case .asleep:
            snapshot.closures?.updatedAt = d
        case .outOfRange:
            break
        }
    }

    private func tickDriving(dt: Double, at d: Date) {
        guard var drive = snapshot.drive, var charge = snapshot.charge else { return }
        if Int.random(in: 0..<16) == 0 {
            targetSpeed = (scenario == .highway ? [90, 105, 115, 125, 135, 140] : [0, 30, 45, 60, 80, 100, 115])
                .randomElement()!
        }
        // Posted limit changes now and then, like passing signs.
        if mockSpeedLimit, Int.random(in: 0..<60) == 0 {
            drive.speedLimit = (scenario == .highway ? [100, 120] : [40, 60, 80]).randomElement()
        }
        let delta = max(-6, min(4, (targetSpeed - drive.speed) * 0.25))
        drive.speed = max(0, drive.speed + delta)
        // Rough EV power model: rolling + aero load, acceleration term, regen when slowing.
        let cruise = 0.004 * drive.speed * drive.speed / 10 + drive.speed * 0.08
        drive.power = (delta > 0 ? cruise + delta * 18 : cruise + delta * 12).rounded()
        drive.heading = (drive.heading + Double.random(in: -3...3)).truncatingRemainder(dividingBy: 360)
        let km = drive.speed * dt / 3600
        drive.odometer += km
        let rad = drive.heading * .pi / 180
        drive.latitude += km / 111 * cos(rad)
        drive.longitude += km / (111 * cos(drive.latitude * .pi / 180)) * sin(rad)
        drive.updatedAt = d
        snapshot.drive = drive

        charge.rangeKm = max(0, charge.rangeKm - km * 1.1)
        charge.level = Int((charge.rangeKm / 533 * 100).rounded())
        if Int(t * 2) % 20 == 0 { charge.updatedAt = d; touchSlowCategories(at: d) }
        snapshot.charge = charge
        snapshot.closures?.updatedAt = d
        if var nav = snapshot.nav {
            nav.kmToArrival = max(0, nav.kmToArrival - km)
            nav.minutesToArrival = max(0, nav.minutesToArrival - dt / 60)
            nav.updatedAt = d
            snapshot.nav = nav
        }
    }

    private func tickCharging(dt: Double, at d: Date) {
        guard var charge = snapshot.charge else { return }
        let pct = Double(charge.level)
        charge.power = pct < 50 ? 185 : max(20, 185 - (pct - 50) * 4.2)
        charge.addedKmPerHour = charge.power * 6.2
        // Sped up ×60 so the demo visibly moves.
        charge.rangeKm = min(533 * Double(charge.limit) / 100, charge.rangeKm + charge.addedKmPerHour * dt / 60)
        charge.level = Int((charge.rangeKm / 533 * 100).rounded())
        charge.isCharging = charge.level < charge.limit
        if !charge.isCharging { charge.power = 0; charge.addedKmPerHour = 0 }
        let remainingKm = 533 * Double(charge.limit) / 100 - charge.rangeKm
        charge.minutesToFull = charge.addedKmPerHour > 0 ? Int(remainingKm / charge.addedKmPerHour * 60) : 0
        charge.updatedAt = d
        snapshot.charge = charge
        snapshot.drive?.updatedAt = d
        snapshot.closures?.updatedAt = d
        if Int(t * 2) % 20 == 0 { touchSlowCategories(at: d) }
    }

    /// Climate / tires are polled every ~10 s in the real design.
    private func touchSlowCategories(at d: Date) {
        if var c = snapshot.climate {
            c.inside += c.isOn ? (c.driverSetTemp - c.inside) * 0.1 : (c.outside - c.inside) * 0.02
            c.updatedAt = d
            snapshot.climate = c
        }
        snapshot.tires?.updatedAt = d
    }
}
