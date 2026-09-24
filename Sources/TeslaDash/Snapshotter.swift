import NeteaseNowPlaying
import SwiftUI
import AppKit

/// Dev tool: offscreen renders of each display mode, so layout and colours can be checked
/// without screen access. Map tiles and the blur material are AppKit-backed and don't render here.
@MainActor
enum Snapshotter {
    static func renderAll(store: VehicleStore, windows: WindowManager, music: NeteaseNowPlaying, to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let modes: [(DisplayMode, CGSize)] = [
            (.square, CGSize(width: 360, height: 360)),
            (.vertical, CGSize(width: 200, height: 876)),
            (.strip, CGSize(width: 940, height: 88)),
            (.strip, CGSize(width: 1300, height: 180)),
            (.dashboard, CGSize(width: 1366, height: 916)),
        ]
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                for (mode, size) in modes {
                    let view = content(mode, store: store)
                        .environment(windows)
                        .environment(music)
                        .frame(width: size.width, height: size.height)
                        .background(Theme.bg)
                        .environment(\.colorScheme, name == "dark" ? .dark : .light)
                    let r = ImageRenderer(content: view)
                    r.scale = 2
                    guard let cg = r.cgImage,
                          let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { continue }
                    try? png.write(to: dir.appendingPathComponent("\(mode.rawValue)-\(Int(size.height))-\(name).png"))
                }
            }
        }
    }

    @ViewBuilder
    private static func content(_ mode: DisplayMode, store: VehicleStore) -> some View {
        switch mode {
        case .square: SquareWidget(store: store)
        case .vertical: VerticalBar(store: store)
        case .strip: StripBar(store: store)
        case .dashboard: DashboardView(store: store)
        }
    }
}
