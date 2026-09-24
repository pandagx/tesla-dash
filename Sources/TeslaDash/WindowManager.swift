import AppKit
import NeteaseNowPlaying
import SwiftUI
import Observation

enum DisplayMode: String, CaseIterable, Identifiable {
    case square, vertical, strip, dashboard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .square: "小方格"
        case .vertical: "竖条"
        case .strip: "横条"
        case .dashboard: "仪表盘"
        }
    }

    var icon: String {
        switch self {
        case .square: "square"
        case .vertical: "rectangle.portrait"
        case .strip: "rectangle"
        case .dashboard: "rectangle.inset.filled"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .square: "1"
        case .vertical: "2"
        case .strip: "3"
        case .dashboard: "4"
        }
    }

    var isCompact: Bool { self != .dashboard }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "跟随系统"
        case .light: "白色背景"
        case .dark: "黑色背景"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// How the speed readout changes value.
enum DigitEffect: String, CaseIterable, Identifiable {
    case flip, roll, jump

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flip: "翻页"
        case .roll: "滚动"
        case .jump: "直接跳变"
        }
    }

    var icon: String {
        switch self {
        case .flip: "rectangle.split.1x2"
        case .roll: "arrow.up.arrow.down"
        case .jump: "bolt"
        }
    }
}

/// Borderless windows refuse key status by default; the compact modes still need clicks and shortcuts.
final class DashWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Hard floor for user resizing. `contentMinSize` alone is not reliably honoured by a
/// borderless window hosting SwiftUI, so clamp in the delegate as well.
final class MinSizeDelegate: NSObject, NSWindowDelegate {
    var minSize = NSSize.zero

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(width: max(frameSize.width, minSize.width), height: max(frameSize.height, minSize.height))
    }
}

/// Owns the single app window and reshapes it for each display mode.
@Observable
final class WindowManager {
    private(set) var mode: DisplayMode
    private(set) var pinned: Bool
    private(set) var appearance: AppearanceMode
    private(set) var digitEffect: DigitEffect
    private var window: DashWindow?
    private let sizeGuard = MinSizeDelegate()
    private let defaults = UserDefaults.standard

    init() {
        mode = DisplayMode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .square
        pinned = UserDefaults.standard.object(forKey: "pinned") as? Bool ?? true
        appearance = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .system
        digitEffect = DigitEffect(rawValue: UserDefaults.standard.string(forKey: "digitEffect") ?? "") ?? .roll
    }

    func show(store: VehicleStore, music: NeteaseNowPlaying) {
        let w = DashWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: RootView(store: store).environment(self).environment(music))
        // Don't let SwiftUI's fitting size resize the window; each mode's frame/min size is set in apply().
        host.sizingOptions = []
        w.contentView = host
        w.delegate = sizeGuard
        window = w
        apply(mode, animate: false)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setMode(_ new: DisplayMode) {
        guard new != mode, let w = window else { return }
        if w.styleMask.contains(.fullScreen) { w.toggleFullScreen(nil) }
        w.saveFrame(usingName: frameName(mode))
        mode = new
        defaults.set(new.rawValue, forKey: "mode")
        apply(new, animate: true)
    }

    /// Persisted; `-appearance light|dark` on the command line overrides it for one launch.
    func setAppearance(_ a: AppearanceMode) {
        appearance = a
        defaults.set(a.rawValue, forKey: "appearance")
        NSApp.appearance = a.nsAppearance
    }

    func setDigitEffect(_ e: DigitEffect) {
        digitEffect = e
        defaults.set(e.rawValue, forKey: "digitEffect")
    }

    func togglePinned() {
        pinned.toggle()
        defaults.set(pinned, forKey: "pinned")
        applyLevel()
    }

    func toggleFullScreen() {
        if mode != .dashboard { setMode(.dashboard) }
        window?.toggleFullScreen(nil)
    }

    func bringToFront() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func frameName(_ m: DisplayMode) -> String { "TeslaDash.frame.\(m.rawValue)" }

    private func apply(_ m: DisplayMode, animate: Bool) {
        guard let w = window else { return }
        if m.isCompact {
            w.styleMask = [.borderless, .resizable]
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.isMovableByWindowBackground = true
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isOpaque = true
            w.backgroundColor = NSColor(Theme.bg)
            w.isMovableByWindowBackground = false
            w.collectionBehavior = [.fullScreenPrimary]
        }
        w.contentMinSize = minSize(m)
        w.minSize = minSize(m)
        sizeGuard.minSize = minSize(m)
        var target = savedFrame(m) ?? defaultFrame(m, on: w.screen ?? NSScreen.main)
        // A frame saved by an older build may be smaller than the current layout needs.
        let min = minSize(m)
        target.size = NSSize(width: max(target.width, min.width), height: max(target.height, min.height))
        w.setFrame(target, display: true, animate: animate)
        w.invalidateShadow()
        applyLevel()
    }

    private func applyLevel() {
        guard let w = window else { return }
        // Full-screen dashboard owns its Space; pinning only makes sense for windowed modes.
        w.level = pinned ? .floating : .normal
        if mode.isCompact {
            w.collectionBehavior = pinned ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.managed]
        }
    }

    private func savedFrame(_ m: DisplayMode) -> NSRect? {
        guard let s = defaults.string(forKey: "NSWindow Frame \(frameName(m))") else { return nil }
        // Stored as "x y w h screenX screenY screenW screenH".
        let n = s.split(separator: " ").prefix(4).compactMap { Double($0) }
        guard n.count == 4, n[2] > 0, n[3] > 0 else { return nil }
        let f = NSRect(x: n[0], y: n[1], width: n[2], height: n[3])
        // Ignore frames left on a display that is no longer attached.
        return NSScreen.screens.contains { $0.visibleFrame.intersects(f) } ? f : nil
    }

    private func minSize(_ m: DisplayMode) -> NSSize {
        switch m {
        case .square: NSSize(width: 300, height: 300)
        case .vertical: NSSize(width: 200, height: 560)
        case .strip: NSSize(width: 880, height: 80)
        case .dashboard: NSSize(width: 1024, height: 700)
        }
    }

    private func defaultFrame(_ m: DisplayMode, on screen: NSScreen?) -> NSRect {
        let v = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 20
        switch m {
        case .square:
            return NSRect(x: v.maxX - 360 - margin, y: v.maxY - 360 - margin, width: 360, height: 360)
        case .vertical:
            let h = min(900, v.height - margin * 2)
            return NSRect(x: v.maxX - 300 - margin, y: v.maxY - h - margin, width: 300, height: h)
        case .strip:
            return NSRect(x: v.midX - 470, y: v.maxY - 88 - margin, width: 940, height: 88)
        case .dashboard:
            let w = min(1366, v.width), h = min(1024, v.height)
            return NSRect(x: v.midX - w / 2, y: v.midY - h / 2, width: w, height: h)
        }
    }
}

// MARK: - Root

struct RootView: View {
    let store: VehicleStore
    @Environment(WindowManager.self) private var windows

    var body: some View {
        Group {
            switch windows.mode {
            case .dashboard: DashboardView(store: store)
            case .square: CompactShell { SquareWidget(store: store) }
            case .vertical: CompactShell { VerticalBar(store: store) }
            case .strip: CompactShell(cornerRadius: 22) { StripBar(store: store) }
            }
        }
        .contextMenu { ModeMenuItems(store: store) }
        .background { ShortcutButtons() }
    }
}

/// ⌘1–⌘4 switch modes, ⌘T toggles pinning, while the window is focused.
struct ShortcutButtons: View {
    @Environment(WindowManager.self) private var windows

    var body: some View {
        ZStack {
            ForEach(DisplayMode.allCases) { m in
                Button("") { windows.setMode(m) }.keyboardShortcut(m.shortcut, modifiers: .command)
            }
            Button("") { windows.togglePinned() }.keyboardShortcut("t", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }
}

/// Shared menu content for the menu bar item and the right-click menu.
struct ModeMenuItems: View {
    @Bindable var store: VehicleStore
    @Environment(WindowManager.self) private var windows

    var body: some View {
        ForEach(DisplayMode.allCases) { m in
            Button {
                windows.setMode(m)
                windows.bringToFront()
            } label: {
                Label(m.label, systemImage: windows.mode == m ? "checkmark" : m.icon)
            }
            .keyboardShortcut(m.shortcut, modifiers: .command)
        }
        Divider()
        ForEach(AppearanceMode.allCases) { a in
            Button {
                windows.setAppearance(a)
            } label: {
                Label(a.label, systemImage: windows.appearance == a ? "checkmark" : a.icon)
            }
        }
        Divider()
        Section("数字效果") {
            ForEach(DigitEffect.allCases) { e in
                Button {
                    windows.setDigitEffect(e)
                } label: {
                    Label(e.label, systemImage: windows.digitEffect == e ? "checkmark" : e.icon)
                }
            }
        }
        Divider()
        Button {
            windows.togglePinned()
        } label: {
            Label(windows.pinned ? "取消置顶" : "始终置顶", systemImage: windows.pinned ? "pin.slash" : "pin")
        }
        .keyboardShortcut("t", modifiers: .command)
        Button("全屏仪表盘") { windows.toggleFullScreen() }
            .keyboardShortcut("f", modifiers: [.command, .control])
        Divider()
        Picker("模拟场景", selection: $store.scenario) {
            ForEach(Scenario.allCases) { Text($0.rawValue).tag($0) }
        }
    }
}

/// Glass panel background for the borderless modes.
struct CompactShell<Content: View>: View {
    var cornerRadius: CGFloat = 26
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    VisualEffect()
                    Theme.bg.opacity(0.78)
                }
            }
            .overlay(alignment: .top) { DragGrip() }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.cardEdge))
    }
}

/// Dedicated handle along the top edge for moving a borderless window.
struct DragGrip: View {
    private let hovering = State(initialValue: false) // see WindowControls

    var body: some View {
        ZStack {
            WindowDragArea()
            Capsule()
                .fill(Theme.secondary.opacity(hovering.wrappedValue ? 0.8 : 0.35))
                .frame(width: hovering.wrappedValue ? 52 : 36, height: 4)
                .allowsHitTesting(false)
        }
        .frame(height: 14)
        .frame(maxWidth: .infinity)
        .onHover { h in
            hovering.wrappedValue = h
            if h { NSCursor.openHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeOut(duration: 0.15), value: hovering.wrappedValue)
        .help("拖动移动位置")
    }
}

/// An AppKit view that starts a window drag on mouse-down. SwiftUI content (map, text)
/// otherwise swallows the clicks that `isMovableByWindowBackground` relies on.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override var mouseDownCanMoveWindow: Bool { true }
    }

    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}
}

/// Pin + display-mode buttons. Always in the top-right corner, dim until hovered.
struct WindowControls: View {
    @Environment(WindowManager.self) private var windows
    // `State` used directly: the @State macro plugin ships with Xcode, not the Command Line Tools.
    private let hovering = State(initialValue: false)

    var body: some View {
        HStack(spacing: 10) {
            Button { windows.togglePinned() } label: {
                Image(systemName: windows.pinned ? "pin.fill" : "pin")
                    .foregroundStyle(windows.pinned ? Theme.blue : Theme.secondary)
            }
            .help(windows.pinned ? "取消置顶 (⌘T)" : "始终置顶 (⌘T)")
            Menu {
                ForEach(DisplayMode.allCases) { m in
                    Button { windows.setMode(m) } label: { Label(m.label, systemImage: m.icon) }
                }
            } label: {
                Image(systemName: "rectangle.3.group")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("切换显示模式 (⌘1–⌘4)")
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Theme.secondary)
        .opacity(hovering.wrappedValue ? 1 : 0.4)
        .animation(.easeOut(duration: 0.15), value: hovering.wrappedValue)
        .onHover { hovering.wrappedValue = $0 }
    }
}

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
