import SwiftUI
import AppKit

/// Every colour has a light and a dark variant and follows the macOS appearance.
enum Theme {
    static let bg = Color(light: 0xF2F3F5, dark: 0x0A0C0F)
    static let card = Color(light: 0xFFFFFF, dark: 0x14171C)
    static let cardEdge = Color(light: 0x000000, dark: 0xFFFFFF, alpha: 0.07)
    static let text = Color(light: 0x0B0D10, dark: 0xF2F4F7)
    static let secondary = Color(light: 0x5B6472, dark: 0x8B95A5)
    static let tertiary = Color(light: 0x9AA2AE, dark: 0x4A5261)
    static let track = Color(light: 0x000000, dark: 0xFFFFFF, alpha: 0.08)
    /// Module tile on top of the glass panel: a shade darker (light) / lighter (dark).
    static let tile = Color(light: 0x000000, dark: 0xFFFFFF, alpha: 0.05)
    static let blue = Color(light: 0x2563EB, dark: 0x3E7BFA)
    static let green = Color(light: 0x16A34A, dark: 0x30D158)
    static let amber = Color(light: 0xC27803, dark: 0xFFB020)
    static let red = Color(light: 0xDC2626, dark: 0xFF453A)
    /// Car silhouette body / glass.
    static let carBody = Color(light: 0xD5D9DF, dark: 0x262B33)
    static let carGlass = Color(light: 0x8C939E, dark: 0x0E1116)
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }

    /// Resolves per appearance at draw time, so the UI flips with the system light/dark setting.
    init(light: UInt32, dark: UInt32, alpha: CGFloat = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: dark, alpha: alpha)
                : NSColor(hex: light, alpha: alpha)
        })
    }
}

// Typography. Figures use one switchable typeface; labels stay plain SF Pro.
// Hierarchy lives in size + colour: hero (speed) ≫ primary (gear, battery) ≫ secondary ≫ tertiary.
// Samples of each option: docs/font-options-2.png
enum Typeface {
    case sfLight, sfCondensed, dinAlternate, dinCondensed, avenirNext, helveticaThin, sfExpanded

    static let current: Typeface = .sfExpanded

    func hero(_ size: CGFloat) -> Font {
        switch self {
        case .sfLight: .system(size: size, weight: .light)
        case .sfCondensed: .system(size: size, weight: .light).width(.condensed)
        case .dinAlternate: .custom("DIN Alternate", size: size)
        case .dinCondensed: .custom("DIN Condensed", size: size * 1.2)
        case .avenirNext: .custom("AvenirNext-UltraLight", size: size)
        case .helveticaThin: .custom("HelveticaNeue-Thin", size: size)
        case .sfExpanded: .system(size: size, weight: .light).width(.expanded)
        }
    }

    func num(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        let heavy = weight == .medium || weight == .semibold || weight == .bold
        switch self {
        case .sfLight: return .system(size: size, weight: weight)
        case .sfCondensed: return .system(size: size, weight: weight).width(.condensed)
        case .dinAlternate: return .custom("DIN Alternate", size: size)
        case .dinCondensed: return .custom("DIN Condensed", size: size * 1.2)
        case .avenirNext: return .custom(heavy ? "AvenirNext-DemiBold" : "AvenirNext-Medium", size: size)
        case .helveticaThin: return .custom(heavy ? "HelveticaNeue-Medium" : "HelveticaNeue", size: size)
        case .sfExpanded: return .system(size: size, weight: weight).width(.expanded)
        }
    }
}

extension Font {
    /// The one thing to read at a glance: speed.
    static func hero(_ size: CGFloat) -> Font {
        Typeface.current.hero(size).monospacedDigit()
    }

    static func num(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Typeface.current.num(size, weight).monospacedDigit()
    }

    static func label(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }
}

/// How old a category's data is, and whether it should be shown as stale.
struct Freshness {
    let age: TimeInterval
    let staleAfter: TimeInterval

    var isStale: Bool { age > staleAfter }

    var label: String {
        switch age {
        case ..<3: "实时"
        case ..<60: "\(Int(age)) 秒前"
        case ..<3600: "\(Int(age / 60)) 分钟前"
        default: "\(Int(age / 3600)) 小时前"
        }
    }
}

struct Card<Content: View>: View {
    let title: String
    var freshness: Freshness?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.label(12, .semibold))
                    .foregroundStyle(Theme.tertiary)
                Spacer()
                if let f = freshness {
                    HStack(spacing: 5) {
                        Circle().fill(f.isStale ? Theme.amber : Theme.green).frame(width: 6, height: 6)
                        Text(f.isStale ? "数据过期 · \(f.label)" : f.label)
                    }
                    .font(.label(11))
                    .foregroundStyle(f.isStale ? Theme.amber : Theme.tertiary)
                }
            }
            content
                .opacity(freshness?.isStale == true ? 0.45 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.cardEdge))
    }
}

struct Chip: View {
    let text: String
    var systemImage: String?
    var color: Color = Theme.secondary

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.label(12, .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.14), in: Capsule())
    }
}
