import AppKit
import CoreAudio
import Foundation
import Observation
import SQLite3

/// What NetEase Cloud Music (desktop) is playing. Two local sources, no network:
///
/// 1. System Now Playing (preferred): NetEase publishes title / artist / album / duration /
///    elapsed time / artwork to MediaRemote. Apps can't read that directly since macOS 15.4,
///    so we go through vendor/mediaremote-adapter, which loads a helper framework into the
///    entitled /usr/bin/perl and streams JSON updates. Position is exact, including after seeks.
/// 2. Fallback: NetEase's own play-history table for metadata, and CoreAudio "is the process
///    outputting audio" for playing/paused. NetEase does not write a history row for every
///    track, so this can show an earlier song; position is estimated and ignores seeks.
public struct NeteaseTrack: Equatable {
    public var title: String
    public var artists: String
    public var album: String
    public var duration: TimeInterval
    public var coverURL: URL?
    public var artwork: Data?
}

@Observable
public final class NeteaseNowPlaying {
    public enum Source: String {
        case systemNowPlaying = "系统「正在播放」"
        case playHistory = "本地播放记录（可能滞后）"
    }

    public private(set) var isRunning = false
    public private(set) var isPlaying = false
    public private(set) var track: NeteaseTrack?
    public private(set) var position: TimeInterval = 0
    public private(set) var source: Source?

    static let bundleID = "com.netease.163music"
    private let adapterDir: URL?
    private var timer: Timer?
    private let stream = NowPlayingStream()
    private let history = PlayHistorySource()

    /// `adapterDirectory` holds MediaRemoteAdapter.framework + mediaremote-adapter.pl
    /// (see scripts/build-mediaremote.sh). Defaults to the app bundle's Resources/mediaremote.
    public init(adapterDirectory: URL? = nil) {
        adapterDir = adapterDirectory ?? Bundle.main.resourceURL?.appendingPathComponent("mediaremote")
    }

    public func start() {
        if let dir = adapterDir { stream.start(adapterDirectory: dir) }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        stream.stop()
    }

    private func refresh() {
        let now = Date()
        isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
        guard isRunning else {
            isPlaying = false
            return
        }
        if let p = stream.state, p.bundleID == Self.bundleID {
            source = .systemNowPlaying
            isPlaying = p.playing
            track = p.track
            position = p.position(at: now)
        } else {
            // Adapter unavailable, or another app currently owns Now Playing.
            source = .playHistory
            history.refresh(now: now)
            isPlaying = history.isPlaying
            track = history.track
            position = history.position
        }
    }
}

// MARK: - Source 1: system Now Playing via mediaremote-adapter

/// Runs `/usr/bin/perl mediaremote-adapter.pl <framework> stream --micros` and merges its
/// JSON lines (full payloads, then diffs where `null` means "key removed").
final class NowPlayingStream {
    struct State {
        var bundleID: String
        var playing: Bool
        var track: NeteaseTrack
        var elapsed: TimeInterval
        var timestamp: Date
        var rate: Double

        func position(at now: Date) -> TimeInterval {
            let p = playing ? elapsed + now.timeIntervalSince(timestamp) * rate : elapsed
            return min(max(0, p), track.duration)
        }
    }

    private(set) var state: State?
    private var payload: [String: Any] = [:]
    private var process: Process?
    private var buffer = Data()
    private var wanted = false
    private var dir: URL?

    func start(adapterDirectory: URL) {
        dir = adapterDirectory
        wanted = true
        launch()
    }

    func stop() {
        wanted = false
        process?.terminate()
        process = nil
    }

    private func launch() {
        guard wanted, let dir,
              FileManager.default.fileExists(atPath: dir.appendingPathComponent("mediaremote-adapter.pl").path)
        else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [dir.appendingPathComponent("mediaremote-adapter.pl").path,
                       dir.appendingPathComponent("MediaRemoteAdapter.framework").path,
                       "stream", "--micros", "--debounce=50"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let chunk = h.availableData
            DispatchQueue.main.async { self?.consume(chunk) }
        }
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.state = nil
                // Restart after a pause if it died (e.g. perl killed); gives up quietly if it keeps failing.
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self?.launch() }
            }
        }
        do { try p.run(); process = p } catch { process = nil }
    }

    private func consume(_ chunk: Data) {
        buffer.append(chunk)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let body = obj["payload"] as? [String: Any] else { continue }
            if obj["diff"] as? Bool == true {
                for (k, v) in body {
                    if v is NSNull { payload.removeValue(forKey: k) } else { payload[k] = v }
                }
            } else {
                payload = body
            }
            state = Self.parse(payload)
        }
    }

    private static func parse(_ d: [String: Any]) -> State? {
        guard let bundle = d["bundleIdentifier"] as? String, let title = d["title"] as? String else { return nil }
        let micros = { (k: String) in (d[k] as? Double ?? 0) / 1_000_000 }
        return State(
            bundleID: bundle,
            playing: d["playing"] as? Bool ?? false,
            track: NeteaseTrack(
                title: title,
                artists: d["artist"] as? String ?? "",
                album: d["album"] as? String ?? "",
                duration: micros("durationMicros"),
                coverURL: nil,
                artwork: (d["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
            ),
            elapsed: micros("elapsedTimeMicros"),
            timestamp: Date(timeIntervalSince1970: micros("timestampEpochMicros")),
            rate: d["playbackRate"] as? Double ?? 1
        )
    }
}

// MARK: - Source 2 (fallback): play history + audio activity

final class PlayHistorySource {
    private(set) var isPlaying = false
    private(set) var track: NeteaseTrack?
    private(set) var position: TimeInterval = 0

    private let dbPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/com.netease.163music/Documents/storage/sqlite_storage.sqlite3").path
    private var dbModified: Date?
    private var startedAt: Date?
    private var lastTick = Date()

    func refresh(now: Date) {
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        let pids = NSRunningApplication.runningApplications(withBundleIdentifier: NeteaseNowPlaying.bundleID)
            .map(\.processIdentifier)
        // NetEase is Chromium-based; audio may come from a helper process, so match by name too.
        isPlaying = Self.outputtingPIDs().contains { pids.contains($0) || Self.processName($0).hasPrefix("NeteaseMusic") }

        // Re-read the DB only when the file changed.
        let modified = (try? FileManager.default.attributesOfItem(atPath: dbPath)[.modificationDate]) as? Date
        if modified != dbModified || track == nil {
            dbModified = modified
            if let (latest, started) = readLatest(), latest != track || started != startedAt {
                track = latest
                startedAt = started
                position = min(latest.duration, now.timeIntervalSince(started))
                return
            }
        }
        if isPlaying, let track { position = min(track.duration, position + dt) }
    }

    private func readLatest() -> (NeteaseTrack, Date)? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 200)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT playtime, jsonStr FROM historyTracks ORDER BY playtime DESC LIMIT 1",
                                 -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 1) else { return nil }
        let playtime = sqlite3_column_int64(stmt, 0)
        guard let data = String(cString: text).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let artists = (json["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        let album = json["album"] as? [String: Any]
        let track = NeteaseTrack(
            title: json["name"] as? String ?? "",
            artists: artists.joined(separator: " / "),
            album: album?["name"] as? String ?? "",
            duration: (json["duration"] as? Double ?? 0) / 1000,
            coverURL: (album?["picUrl"] as? String).flatMap(URL.init(string:)),
            artwork: nil
        )
        return (track, Date(timeIntervalSince1970: Double(playtime) / 1000))
    }

    static func outputtingPIDs() -> [pid_t] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            (read(id, kAudioProcessPropertyIsRunningOutput, UInt32(0)) != 0)
                ? read(id, kAudioProcessPropertyPID, pid_t(0)) : nil
        }
    }

    private static func read<T>(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector, _ fallback: T) -> T {
        var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var value = fallback
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &value) == noErr ? value : fallback
    }

    private static func processName(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buf, UInt32(buf.count))
        return String(cString: buf)
    }
}
