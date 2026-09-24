import AppKit
import NeteaseNowPlaying
import SwiftUI

// Standalone test window for the NetEase reader, kept apart from the dashboard until verified.

struct ProbeView: View {
    let np: NeteaseNowPlaying

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(stateColor).frame(width: 8, height: 8)
                Text(stateText).font(.system(size: 12, weight: .semibold)).foregroundStyle(stateColor)
                Spacer()
                Text(np.source.map { "来源：\($0.rawValue)" } ?? "")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let t = np.track {
                HStack(alignment: .top, spacing: 14) {
                    cover(t)
                        .frame(width: 72, height: 72)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.title).font(.system(size: 18, weight: .semibold)).lineLimit(1)
                        Text(t.artists).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                        Text(t.album).font(.system(size: 12)).foregroundStyle(.tertiary).lineLimit(1)
                    }
                }
                VStack(spacing: 4) {
                    ProgressView(value: min(np.position, t.duration), total: max(t.duration, 1))
                    HStack {
                        Text(mmss(np.position))
                        Spacer()
                        Text(mmss(t.duration))
                    }
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            } else {
                Text(np.isRunning ? "还没有读到正在播放的歌曲" : "网易云音乐未运行")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 440)
    }

    @ViewBuilder
    private func cover(_ t: NeteaseTrack) -> some View {
        if let data = t.artwork, let img = NSImage(data: data) {
            Image(nsImage: img).resizable().scaledToFill()
        } else {
            AsyncImage(url: t.coverURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "music.note").font(.system(size: 26)).foregroundStyle(.secondary)
            }
        }
    }

    private var stateText: String {
        !np.isRunning ? "未运行" : np.isPlaying ? "播放中" : "已暂停"
    }

    private var stateColor: Color {
        !np.isRunning ? .red : np.isPlaying ? .green : .orange
    }

    private func mmss(_ s: TimeInterval) -> String {
        let t = Int(max(0, s))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// Inside the .app the adapter sits in Resources/mediaremote; from `swift run` use build/mediaremote.
func makeReader() -> NeteaseNowPlaying {
    let bundled = Bundle.main.resourceURL?.appendingPathComponent("mediaremote")
    if let bundled, FileManager.default.fileExists(atPath: bundled.path) {
        return NeteaseNowPlaying(adapterDirectory: bundled)
    }
    return NeteaseNowPlaying(adapterDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("build/mediaremote"))
}

final class ProbeDelegate: NSObject, NSApplicationDelegate {
    let np = makeReader()
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        np.start()
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 200),
                         styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        w.title = "网易云 · 正在播放（测试）"
        w.contentView = NSHostingView(rootView: ProbeView(np: np))
        w.center()
        w.makeKeyAndOrderFront(nil)
        window = w
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) { np.stop() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// `--dump`: print what the reader sees for a few seconds, no window.
if CommandLine.arguments.contains("--dump") {
    let np = makeReader()
    np.start()
    var n = 0
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        n += 1
        let t = np.track
        print("source=\(np.source?.rawValue ?? "-") playing=\(np.isPlaying) pos=\(String(format: "%.1f", np.position))s/\(Int(t?.duration ?? 0))s",
              t.map { "\($0.title) — \($0.artists) [\($0.album)] artwork=\($0.artwork?.count ?? 0)B" } ?? "-")
        if n >= 4 { np.stop(); exit(0) }
    }
    RunLoop.main.run()
}

let app = NSApplication.shared
let delegate = ProbeDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
