import NeteaseNowPlaying
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = VehicleStore()
    let windows = WindowManager()
    /// NetEase Cloud Music on this Mac (adapter bundled in Resources/mediaremote).
    let music = NeteaseNowPlaying()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = windows.appearance.nsAppearance
        music.start()
        if let dir = UserDefaults.standard.string(forKey: "snapshot") {
            // Dev: `-snapshot <dir>` renders every mode in light + dark to PNGs, then quits.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
                Snapshotter.renderAll(store: store, windows: windows, music: music, to: URL(fileURLWithPath: dir))
                NSApp.terminate(nil)
            }
            return
        }
        windows.show(store: store, music: music)
    }

    func applicationWillTerminate(_ notification: Notification) {
        music.stop() // ends the perl helper process
    }

    // Re-open the panel when the app is re-launched while already running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windows.bringToFront()
        return true
    }
}

@main
struct TeslaDashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            ModeMenuItems(store: delegate.store)
                .environment(delegate.windows)
            Divider()
            Button("显示面板") { delegate.windows.bringToFront() }
            Button("退出 TeslaDash") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            MenuBarLabel(store: delegate.store)
        }
    }
}

struct MenuBarLabel: View {
    let store: VehicleStore

    var body: some View {
        let c = store.snapshot.charge
        HStack(spacing: 3) {
            Image(systemName: c?.isCharging == true ? "bolt.car.fill" : "car.fill")
            Text(c.map { "\($0.level)%" } ?? "--")
        }
    }
}
