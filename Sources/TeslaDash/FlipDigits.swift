import SwiftUI

// Split-flap ("flip clock") speed readout, one of the selectable digit effects.

extension Theme {
    static let flipCard = Color(light: 0xFFFFFF, dark: 0x1C1F25)
    static let flipHinge = Color(light: 0xD5D9DF, dark: 0x0A0C0F)
}

/// Squarer than the rolling readout's SF Pro Expanded Light, so the two effects read differently.
private func flipFont(_ size: CGFloat) -> Font {
    .system(size: size, weight: .semibold).width(.condensed).monospacedDigit()
}

/// One split-flap card. `from` flips over to `to`:
/// the upper half of `from` falls (topAngle 0 → -90°), then the lower half of `to` lands (bottomAngle 90° → 0).
struct FlipCard: View {
    let from: String
    let to: String
    var topAngle: Double = 0
    var bottomAngle: Double = 0
    let size: CGFloat
    let color: Color

    private var w: CGFloat { size * 0.72 }
    private var h: CGFloat { size * 1.18 }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                half(to, top: true)                                              // revealed behind the falling flap
                half(topAngle > -90 || bottomAngle > 0 ? from : to, top: false)  // covered by the landing flap
            }
            VStack(spacing: 0) {
                half(from, top: true)
                    .rotation3DEffect(.degrees(topAngle), axis: (1, 0, 0), anchor: .bottom, perspective: 0.45)
                    .opacity(topAngle <= -89.9 ? 0 : 1)
                Color.clear.frame(width: w, height: h / 2)
            }
            VStack(spacing: 0) {
                Color.clear.frame(width: w, height: h / 2)
                half(to, top: false)
                    .rotation3DEffect(.degrees(bottomAngle), axis: (1, 0, 0), anchor: .top, perspective: 0.45)
                    .opacity(bottomAngle >= 89.9 ? 0 : 1)
            }
            Rectangle().fill(Theme.flipHinge).frame(width: w, height: max(1, size * 0.018))
        }
        .frame(width: w, height: h)
    }

    private func half(_ s: String, top: Bool) -> some View {
        let r = size * 0.1
        return Text(s)
            .font(flipFont(size))
            .foregroundStyle(color)
            .frame(width: w, height: h)
            .frame(width: w, height: h / 2, alignment: top ? .top : .bottom)
            .clipped()
            .background(Theme.flipCard)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: top ? r : 0, bottomLeadingRadius: top ? 0 : r,
                                              bottomTrailingRadius: top ? 0 : r, topTrailingRadius: top ? r : 0,
                                              style: .continuous))
    }
}

/// Flips from the shown character to `value` whenever it changes; if a newer value arrives
/// mid-flip, it flips again to catch up.
struct FlipDigit: View {
    let value: String
    let size: CGFloat
    let color: Color
    var duration: Double = 0.18

    // `State` used directly: the @State macro plugin ships with Xcode, not the Command Line Tools.
    private let shown = State(initialValue: "")
    private let target = State(initialValue: "")
    private let topAngle = State(initialValue: 0.0)
    private let bottomAngle = State(initialValue: 0.0)
    private let flipping = State(initialValue: false)

    var body: some View {
        FlipCard(from: shown.wrappedValue.isEmpty ? value : shown.wrappedValue,
                 to: target.wrappedValue.isEmpty ? value : target.wrappedValue,
                 topAngle: topAngle.wrappedValue, bottomAngle: bottomAngle.wrappedValue,
                 size: size, color: color)
            .onAppear { shown.wrappedValue = value; target.wrappedValue = value }
            .onChange(of: value) { _, new in flip(to: new) }
    }

    private func flip(to new: String) {
        target.wrappedValue = new
        guard !flipping.wrappedValue else { return }
        flipping.wrappedValue = true
        topAngle.wrappedValue = 0
        bottomAngle.wrappedValue = 90
        withAnimation(.easeIn(duration: duration / 2)) {
            topAngle.wrappedValue = -90
        } completion: {
            withAnimation(.easeOut(duration: duration / 2)) {
                bottomAngle.wrappedValue = 0
            } completion: {
                shown.wrappedValue = target.wrappedValue
                topAngle.wrappedValue = 0
                flipping.wrappedValue = false
                if shown.wrappedValue != value { flip(to: value) }
            }
        }
    }
}

/// A number as flip cards, one per digit (no leading zeros).
struct FlipNumber: View {
    let value: Int
    let size: CGFloat
    let color: Color

    var body: some View {
        let digits = Array(String(max(0, value)))
        HStack(spacing: size * 0.08) {
            // Identity counted from the right, so the ones digit stays the same card as the width changes.
            ForEach(Array(digits.enumerated()), id: \.offset) { i, ch in
                FlipDigit(value: String(ch), size: size, color: color)
                    .id(digits.count - i)
            }
        }
    }
}
