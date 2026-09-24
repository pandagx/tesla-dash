// Dev helper: prints "<windowID> <w>x<h>" for TeslaDash's on-screen windows.
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowOwnerName as String] as? String) == "TeslaDash" {
    let b = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
    print(w[kCGWindowNumber as String]!, "\(Int(b["Width"] ?? 0))x\(Int(b["Height"] ?? 0)) @\(Int(b["X"] ?? 0)),\(Int(b["Y"] ?? 0))", "layer=\(w[kCGWindowLayer as String]!)")
}
