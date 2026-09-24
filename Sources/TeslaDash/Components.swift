import SwiftUI

// Shared building blocks used by every display mode.

extension Theme {
    static let yellow = Color(light: 0xB88A00, dark: 0xFFD60A)
    static let orange = Color(light: 0xE07000, dark: 0xFF9F0A)
    /// Between orange and red (hue ≈ 18°) so 100–120 reads apart from both neighbours.
    static let vermilion = Color(light: 0xE6450C, dark: 0xFF6421)
    /// Speed-only red, pushed toward crimson to stay distinct from vermilion.
    static let speedRed = Color(light: 0xD10F2C, dark: 0xFF2A3D)

    /// <60 white, 60–80 yellow, 80–100 orange, 100–120 vermilion, >120 red.
    static func speedColor(_ speed: Double) -> Color {
        let v = Int(speed.rounded())
        switch v {
        case ..<60: return text
        case 60..<80: return yellow
        case 80..<100: return orange
        case 100...120: return vermilion
        default: return speedRed
        }
    }
}

struct SpeedText: View {
    let speed: Double
    let size: CGFloat

    var body: some View {
        let v = Int(speed.rounded())
        Text("\(v)")
            .font(.hero(size))
            .foregroundStyle(Theme.speedColor(speed))
            .contentTransition(.numericText(value: Double(v)))
            .animation(.easeOut(duration: 0.3), value: v)
    }
}

/// Bluetooth rune: blue when connected, red with a slash when disconnected.
struct BluetoothIcon: View {
    let connected: Bool
    var size: CGFloat = 18

    var body: some View {
        let color = connected ? Theme.blue : Theme.red
        ZStack {
            BluetoothRune()
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round, lineJoin: .round))
            if !connected {
                Path { p in
                    p.move(to: CGPoint(x: size * 0.08, y: size * 0.08))
                    p.addLine(to: CGPoint(x: size * 0.92, y: size * 0.92))
                }
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
        .help(connected ? "蓝牙已连接" : "蓝牙已断开")
    }
}

private struct BluetoothRune: Shape {
    func path(in r: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
        var p = Path()
        p.move(to: pt(0.25, 0.30))
        p.addLine(to: pt(0.72, 0.70))
        p.addLine(to: pt(0.50, 0.90))
        p.addLine(to: pt(0.50, 0.10))
        p.addLine(to: pt(0.72, 0.30))
        p.addLine(to: pt(0.25, 0.70))
        return p
    }
}

struct ClockText: View {
    let now: Date
    var size: CGFloat = 16

    var body: some View {
        Text(now, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            .font(.num(size))
            .foregroundStyle(Theme.secondary)
    }
}

/// Vertical P/R/N/D stack with the active gear highlighted.
struct GearColumn: View {
    let gear: Gear
    var size: CGFloat = 15

    var body: some View {
        VStack(spacing: 1) {
            ForEach(Gear.allCases, id: \.self) { g in
                Text(g.rawValue)
                    .font(.num(size, .semibold))
                    .foregroundStyle(g == gear ? Color.white : Theme.tertiary)
                    .frame(width: size * 1.7, height: size * 1.35)
                    .background(g == gear ? Theme.blue : .clear,
                                in: RoundedRectangle(cornerRadius: size * 0.35, style: .continuous))
            }
        }
    }
}

/// 2×2 tyre pressures in car layout (front row on top).
struct TireGrid: View {
    let tires: TireState?
    var size: CGFloat = 16
    var spacing: CGFloat = 14

    var body: some View {
        Grid(horizontalSpacing: spacing, verticalSpacing: 2) {
            GridRow { cell(.frontLeft); cell(.frontRight) }
            GridRow { cell(.rearLeft); cell(.rearRight) }
        }
    }

    private func cell(_ c: Corner) -> some View {
        let p = tires?.pressure[c]
        let low = (p ?? 9) < TireState.lowThreshold
        return Text(p.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "--")
            .font(.num(size))
            .foregroundStyle(low ? Theme.amber : Theme.secondary)
    }
}

/// Road sign: white disc, red ring, black number. Kept sign-coloured in dark mode too.
struct SpeedLimitSign: View {
    let limit: Double
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Color.white)
            Circle().strokeBorder(Color(hex: 0xE3001B), lineWidth: size * 0.13)
            Text("\(Int(limit))")
                .font(.system(size: size * (limit >= 100 ? 0.36 : 0.44), weight: .bold).width(.condensed))
                .monospacedDigit()
                .foregroundStyle(Color.black)
        }
        .frame(width: size, height: size)
        .help("当前道路限速 \(Int(limit)) km/h")
    }
}

extension View {
    /// Flashes a red glow behind the view (≈2 Hz) while `active`; used around the speed readout
    /// when driving more than 20 % over the posted limit.
    func overspeedFlash(_ active: Bool, cornerRadius: CGFloat = 16, inset: CGFloat = 6) -> some View {
        background {
            if active {
                TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                    let phase = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.6) / 0.6
                    let on = 0.5 - 0.5 * cos(phase * 2 * .pi)   // smooth 0→1→0
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(hex: 0xE3001B).opacity(0.10 + 0.35 * on))
                        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color(hex: 0xE3001B).opacity(0.4 + 0.6 * on), lineWidth: 2))
                        .padding(-inset)
                }
            }
        }
    }
}
