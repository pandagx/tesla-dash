// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TeslaDash",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TeslaDash",
            dependencies: ["NeteaseNowPlaying"],
            path: "Sources/TeslaDash",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Experimental: NetEase Cloud Music "now playing", read from local data only.
        .target(
            name: "NeteaseNowPlaying",
            path: "Sources/NeteaseNowPlaying",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // Standalone test window for NeteaseNowPlaying (not part of the dashboard yet).
        .executableTarget(
            name: "NeteaseProbe",
            dependencies: ["NeteaseNowPlaying"],
            path: "Sources/NeteaseProbe",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
