import AppKit
import NeteaseNowPlaying
import SwiftUI

// Compact "now playing" for NetEase Cloud Music on this Mac. Deliberately low-key (tertiary
// tier): one line of text plus a hairline progress bar. Renders nothing when nothing plays.

private func mmss(_ s: TimeInterval) -> String {
    let t = Int(max(0, s))
    return String(format: "%d:%02d", t / 60, t % 60)
}

private struct Artwork: View {
    let track: NeteaseTrack
    let size: CGFloat

    var body: some View {
        Group {
            if let data = track.artwork, let img = NSImage(data: data) {
                Image(nsImage: img).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .frame(width: size, height: size)
        .background(Theme.track)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

private struct Hairline: View {
    let fraction: Double
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(Theme.secondary.opacity(0.8))
                    .frame(width: g.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: height)
    }
}

/// Single-line text that scrolls (marquee) only when it doesn't fit: holds for `pause`
/// seconds at the start, then scrolls left and loops seamlessly with a `gap` between copies.
struct MarqueeText: View {
    let content: Text
    var speed: CGFloat = 28      // points per second
    var gap: CGFloat = 36
    var pause: Double = 2

    // `State` used directly: the @State macro plugin ships with Xcode, not the Command Line Tools.
    private let textWidth = State(initialValue: CGFloat(0))
    private let boxWidth = State(initialValue: CGFloat(0))
    private let start = State(initialValue: Date())

    var body: some View {
        let tw = textWidth.wrappedValue, bw = boxWidth.wrappedValue
        let scrolls = bw > 0 && tw > bw + 1
        content.lineLimit(1).hidden() // reserves the line height
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boxWidth.wrappedValue = $0 }
            .background(alignment: .leading) {
                content.fixedSize().hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                        textWidth.wrappedValue = $0
                        start.wrappedValue = Date() // restart from the beginning on a new title
                    }
            }
            .overlay(alignment: .leading) {
                if scrolls {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                        let travel = tw + gap
                        let cycle = pause + Double(travel / speed)
                        let t = ctx.date.timeIntervalSince(start.wrappedValue).truncatingRemainder(dividingBy: cycle)
                        let x = t < pause ? 0 : -CGFloat(t - pause) * speed
                        HStack(spacing: gap) {
                            content.fixedSize()
                            content.fixedSize()
                        }
                        .offset(x: x)
                    }
                } else {
                    content.lineLimit(1)
                }
            }
            .clipped()
            .mask {
                // Soft edges only while scrolling.
                LinearGradient(stops: [.init(color: scrolls ? .clear : .black, location: 0),
                                       .init(color: .black, location: scrolls ? 0.06 : 0),
                                       .init(color: .black, location: scrolls ? 0.9 : 1),
                                       .init(color: scrolls ? .clear : .black, location: 1)],
                               startPoint: .leading, endPoint: .trailing)
            }
    }
}

/// Dashboard: a single slim row under the cards.
struct MusicBar: View {
    @Environment(NeteaseNowPlaying.self) private var music

    var body: some View {
        if music.isRunning, let t = music.track {
            HStack(spacing: 12) {
                Artwork(track: t, size: 30)
                Image(systemName: music.isPlaying ? "play.fill" : "pause.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiary)
                MarqueeText(content: Text(t.title).foregroundStyle(Theme.secondary).font(.label(13, .semibold))
                    + Text("  \(t.artists)").foregroundStyle(Theme.tertiary).font(.label(12)))
                    .frame(maxWidth: 420, alignment: .leading)
                Text(mmss(music.position)).font(.num(11)).foregroundStyle(Theme.tertiary)
                Hairline(fraction: t.duration > 0 ? music.position / t.duration : 0)
                Text(mmss(t.duration)).font(.num(11)).foregroundStyle(Theme.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.cardEdge))
            .opacity(music.isPlaying ? 1 : 0.6)
        }
    }
}

/// Vertical bar / strip: title · artist on one line, hairline progress underneath.
struct MusicMini: View {
    @Environment(NeteaseNowPlaying.self) private var music
    var size: CGFloat = 11

    var body: some View {
        if music.isRunning, let t = music.track {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: music.isPlaying ? "music.note" : "pause.fill")
                        .font(.system(size: size * 0.9))
                    MarqueeText(content: Text(t.title).foregroundStyle(Theme.secondary).font(.label(size, .semibold))
                        + Text(" · \(t.artists)").font(.label(size)))
                }
                .foregroundStyle(Theme.tertiary)
                Hairline(fraction: t.duration > 0 ? music.position / t.duration : 0, height: max(2, size * 0.18))
            }
            .opacity(music.isPlaying ? 1 : 0.6)
        }
    }
}
