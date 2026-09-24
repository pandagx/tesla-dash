import Foundation

// Mirrors the BLE `state` categories from vehicle-command. Every category carries its own
// timestamp: over BLE each one is fetched separately and can go stale independently.

enum Gear: String, CaseIterable {
    case P, R, N, D
}

enum CarStatus {
    case driving, charging, parked, asleep, outOfRange

    var label: String {
        switch self {
        case .driving: "行驶中"
        case .charging: "充电中"
        case .parked: "已停车"
        case .asleep: "休眠中"
        case .outOfRange: "不在范围内"
        }
    }
}

struct DriveState {
    var speed: Double          // km/h
    var gear: Gear
    var power: Double          // kW, negative = regen
    var heading: Double        // degrees
    var latitude: Double
    var longitude: Double
    var odometer: Double       // km
    var updatedAt: Date
}

struct ChargeState {
    var level: Int             // %
    var rangeKm: Double
    var limit: Int             // %
    var isCharging: Bool
    var power: Double          // kW
    var addedKmPerHour: Double
    var minutesToFull: Int
    var chargerType: String
    var updatedAt: Date
}

struct ClimateState {
    var inside: Double         // °C
    var outside: Double
    var isOn: Bool
    var isAuto: Bool
    var driverSetTemp: Double
    var passengerSetTemp: Double
    var fanSpeed: Int          // 0...10 (`fan_status`)
    var updatedAt: Date
}

/// Route summary from DriveState (`active_route_*`). BLE has no turn-by-turn guidance.
struct NavState {
    var destination: String
    var minutesToArrival: Double
    var kmToArrival: Double
    var trafficDelayMinutes: Double
    var arrivalBatteryPercent: Int?   // `active_route_energy_at_arrival`; unit to confirm on the car
    var updatedAt: Date
}

enum Corner: CaseIterable {
    case frontLeft, frontRight, rearLeft, rearRight
}

struct ClosuresState {
    var locked: Bool
    var sentry: Bool
    var openDoors: Set<Corner>
    var frunkOpen: Bool
    var trunkOpen: Bool
    var windowsOpen: Bool
    var updatedAt: Date
}

struct TireState {
    var pressure: [Corner: Double]   // bar
    var updatedAt: Date

    static let lowThreshold = 2.6
}

struct VehicleSnapshot {
    var name = "Model Y"
    var softwareVersion = "2026.32.6"
    var status: CarStatus = .parked
    var bleConnected = true
    var drive: DriveState?
    var charge: ChargeState?
    var climate: ClimateState?
    var closures: ClosuresState?
    var tires: TireState?
    var nav: NavState?
}
