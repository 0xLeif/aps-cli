import AppState
#if canImport(Combine)
import Combine
#endif
import Foundation
import Observation

/// Reads and writes demo keys through AppState idioms (including `@AppDependency`
/// and `@ObservedDependency` for observable services).
///
/// Callers must be on the main thread: AppState asserts that in `notifyChange()`,
/// and ArgumentParser's synchronous `@main` entry point provides that.
///
/// FileState path configuration belongs to CLI `boot()` (or the test harness).
/// `StateStore` does not call `APSPaths.configure()`, so injected test paths stay put.
@MainActor
public final class StateStore {
    @AppDependency(\.clock) private var clock: any APSClock
    @AppDependency(\.jsonCoding) private var jsonCoding: JSONCoding
    #if !os(Linux) && !os(Windows)
    @ObservedDependency(\.stats) private var stats: DemoStats
    #else
    @AppDependency(\.stats) private var stats: DemoStats
    #endif

    public init() {
        Application.load(dependency: \.clock)
        Application.load(dependency: \.jsonCoding)
        Application.load(dependency: \.stats)
#if canImport(Security)
        Application.load(dependency: \.keychain)
#endif
    }

    /// Wall clock from the injected `APSClock` dependency.
    public var now: Date { clock.now }

    /// Current snapshot of the `@ObservedDependency` stats service.
    public func statsSnapshot() -> DemoStatsSnapshot {
        DemoStatsSnapshot(
            mutationCount: stats.mutationCount,
            lastMutatedKey: stats.lastMutatedKey
        )
    }

    /// Clears process-local stats counters (test / reset helpers).
    public func resetStats() {
        stats.reset()
    }

    public func get(_ key: DemoKey) -> String {
        switch key {
        case .counter:
            return String(Application.state(\.counter).value)
        case .message:
            return Application.state(\.message).value
        case .flag:
            return String(Application.state(\.flag).value)
        case .note:
            return Application.fileState(\.note).value
        case .profile:
            return (try? encodeProfile(Application.fileState(\.profile).value)) ?? "{\"name\":\"\",\"version\":0}"
        case .secret:
#if canImport(Security)
            return Application.secureState(\.secret).value ?? ""
#else
            return ""
#endif
        case .profileName:
            return Application.slice(\.profile, \.name).value
        }
    }

    /// `ProfileDocument.name` read through AppState `Slice` (same path as `get(.profileName)`).
    public func profileName() -> String {
        Application.slice(\.profile, \.name).value
    }

    public func profileDocument() throws -> ProfileDocument {
        Application.fileState(\.profile).value
    }

    public func set(_ key: DemoKey, value: String) throws {
        switch key {
        case .counter:
            guard let intValue = Int(value) else {
                throw APSError.invalidValue(key: key, value: value)
            }
            var state = Application.state(\.counter)
            state.value = intValue
        case .message:
            var state = Application.state(\.message)
            state.value = value
        case .flag:
            guard let boolValue = Self.parseBool(value) else {
                throw APSError.invalidValue(key: key, value: value)
            }
            var state = Application.state(\.flag)
            state.value = boolValue
            // Linux Foundation does not always flush UserDefaults on process exit.
            UserDefaults.standard.synchronize()
        case .note:
            var state = Application.fileState(\.note)
            state.value = value
            // AppState FileState swallows save errors after updating its cache.
            // Confirm the value is actually on disk before claiming success.
            let onDisk = try Self.readNoteFromDisk()
            guard onDisk == value else {
                throw APSError.persistenceFailed(key: .note)
            }
        case .profile:
            let document: ProfileDocument
            do {
                document = try jsonCoding.decode(ProfileDocument.self, from: value)
            } catch {
                throw APSError.invalidValue(key: key, value: value)
            }
            var state = Application.fileState(\.profile)
            state.value = document
            let onDisk = try Self.readProfileFromDisk()
            guard onDisk == document else {
                throw APSError.persistenceFailed(key: .profile)
            }
        case .secret:
#if canImport(Security)
            var state = Application.secureState(\.secret)
            state.value = value
            let stored = Application.dependency(\.keychain).get(APSKeychain.secretAccount)
            guard stored == value else {
                throw APSError.persistenceFailed(key: .secret)
            }
#else
            throw APSError.keychainUnavailable
#endif
        case .profileName:
            // Refresh FileState from disk before Slice write so a stale cached
            // ProfileDocument cannot clobber a newer on-disk version.
            try Self.refreshProfileFileStateFromDisk()
            let expectedVersion = (try? Self.readProfileFromDisk())?.version ?? 0
            var slice = Application.slice(\.profile, \.name)
            slice.value = value
            let onDisk = try Self.readProfileFromDisk()
            guard onDisk.name == value, onDisk.version == expectedVersion else {
                throw APSError.persistenceFailed(key: .profileName)
            }
        }
        stats.recordMutation(key: key)
    }

    public func reset(_ key: DemoKey) {
        switch key {
        case .counter:
            Application.reset(\.counter)
        case .message:
            Application.reset(\.message)
        case .flag:
            Application.reset(storedState: \.flag)
            UserDefaults.standard.synchronize()
        case .note:
            Application.reset(fileState: \.note)
        case .profile:
            Application.reset(fileState: \.profile)
        case .secret:
#if canImport(Security)
            Application.reset(secureState: \.secret)
#else
            break
#endif
        case .profileName:
            try? Self.refreshProfileFileStateFromDisk()
            var slice = Application.slice(\.profile, \.name)
            slice.value = ""
        }
        stats.recordMutation(key: key)
    }

    public func resetAll() {
        for key in DemoKey.allCases {
            reset(key)
        }
    }

    public func dump() throws -> String {
        let snapshot = DumpSnapshot(
            timestamp: clock.now,
            keys: try DemoKey.allCases.map { key in
                DumpEntry(
                    key: key.rawValue,
                    storage: key.storage,
                    type: key.valueType,
                    value: try CLIOutput.typedValue(for: key, store: self)
                )
            }
        )
        return try jsonCoding.encodePretty(snapshot)
    }

    /// Blocking watch over the `@ObservedDependency` stats service.
    ///
    /// Subscribes to Combine `objectWillChange` from `DemoStats` and polls the snapshot
    /// so mutations recorded by `set` / `reset` surface to the CLI without SwiftUI.
    public func watchStatsBlocking(
        pollInterval: TimeInterval = 0.25,
        shouldContinue: () -> Bool = { true },
        onChange: (DemoStatsSnapshot) -> Void
    ) {
        var last = statsSnapshot()
        onChange(last)

        #if canImport(Combine)
        let flag = ChangeFlag()
        let cancellable = stats.objectWillChange.sink { _ in
            flag.mark()
        }
        defer { _ = cancellable }
        #endif

        let slice = max(pollInterval / 5.0, 0.05)

        while shouldContinue() {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: slice))
            let current = statsSnapshot()
            if current != last {
                last = current
                onChange(current)
                #if canImport(Combine)
                flag.clear()
                #endif
            } else {
                #if canImport(Combine)
                if flag.isSet {
                    // objectWillChange is pre-publish; re-check next slice for the new value.
                    flag.clear()
                }
                #endif
            }
        }
    }

    /// Blocking watch for the synchronous CLI: Observation + RunLoop polling.
    ///
    /// - Observation covers in-process mutations (`State`).
    /// - Polling re-reads values so `FileState` / `StoredState` / `SecureState` updates can surface when
    ///   Observation alone would not (e.g. another process wrote the file).
    /// - For disk-backed keys, polling reads files directly so AppState's FileState cache
    ///   cannot hide cross-process writes.
    /// - `shouldContinue` lets tests (and CLI `--count` / `--timeout`) stop the loop cleanly.
    public func watchBlocking(
        _ key: DemoKey,
        pollInterval: TimeInterval = 0.25,
        shouldContinue: () -> Bool = { true },
        onChange: (String) -> Void
    ) {
        var last = freshValue(key)
        onChange(last)

        let slice = max(pollInterval / 5.0, 0.05)

        while shouldContinue() {
            let flag = ChangeFlag()

            withObservationTracking {
                self.readForObservation(key)
            } onChange: {
                flag.mark()
            }

            while shouldContinue() {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: slice))
                let current = freshValue(key)
                if flag.isSet || current != last {
                    if current != last {
                        last = current
                        onChange(current)
                    }
                    break
                }
            }
        }
    }

    /// Value used by watch polling. Disk-backed keys bypass AppState's FileState cache.
    private func freshValue(_ key: DemoKey) -> String {
        switch key {
        case .note:
            return (try? Self.readNoteFromDisk()) ?? get(key)
        case .profile:
            if let document = try? Self.readProfileFromDisk() {
                return (try? encodeProfile(document)) ?? get(key)
            }
            return get(key)
        case .counter, .message, .flag, .secret, .profileName:
            return get(key)
        }
    }

    /// Read `note.json` without touching AppState's in-memory FileState cache.
    ///
    /// Mirrors AppState's non-Base64 FileState encoding: UTF-8 JSON via `JSONEncoder`.
    public static func readNoteFromDisk() throws -> String {
        let fileURL = Self.fileStateURL(filename: "note.json")
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(String.self, from: data)
        } catch {
            throw APSError.persistenceFailed(key: .note)
        }
    }

    public static func readProfileFromDisk() throws -> ProfileDocument {
        let fileURL = Self.fileStateURL(filename: "profile.json")
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(ProfileDocument.self, from: data)
        } catch {
            throw APSError.persistenceFailed(key: .profile)
        }
    }

    /// Loads `profile.json` into AppState's FileState cache when present.
    ///
    /// Slice writes mutate the cached parent document; without this refresh, a
    /// long-lived `StateStore` can preserve a stale `version` after another
    /// process updated the file.
    private static func refreshProfileFileStateFromDisk() throws {
        let fresh: ProfileDocument
        do {
            fresh = try readProfileFromDisk()
        } catch {
            fresh = ProfileDocument(name: "", version: 0)
        }
        var parent = Application.fileState(\.profile)
        parent.value = fresh
    }

    private static func fileStateURL(filename: String) -> URL {
        URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent(filename)
    }

    private func encodeProfile(_ document: ProfileDocument) throws -> String {
        let data = try JSONEncoder().encode(document)
        guard let string = String(data: data, encoding: .utf8) else {
            throw APSError.encodingFailed
        }
        return string
    }

    private func readForObservation(_ key: DemoKey) {
        switch key {
        case .counter:
            _ = Application.state(\.counter).value
        case .message:
            _ = Application.state(\.message).value
        case .flag:
            _ = Application.state(\.flag).value
        case .note:
            _ = Application.fileState(\.note).value
        case .profile:
            _ = Application.fileState(\.profile).value
        case .secret:
#if canImport(Security)
            _ = Application.secureState(\.secret).value
#endif
        case .profileName:
            _ = Application.slice(\.profile, \.name).value
        }
    }

    public nonisolated static func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "1", "yes", "y", "on": return true
        case "false", "0", "no", "n", "off": return false
        default: return nil
        }
    }
}

/// `@Sendable` flag for Observation / Combine `onChange` closures.
private final class ChangeFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func mark() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func clear() {
        lock.lock()
        value = false
        lock.unlock()
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private struct DumpSnapshot: Encodable {
    let timestamp: Date
    let keys: [DumpEntry]
}

private struct DumpEntry: Encodable {
    let key: String
    let storage: String
    let type: String
    let value: CLIOutput.JSONValue
}
