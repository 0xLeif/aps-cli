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
    @AppDependency(\.clock) var clock: any APSClock
    @AppDependency(\.jsonCoding) var jsonCoding: JSONCoding
    #if !os(Linux) && !os(Windows)
    @ObservedDependency(\.stats) var stats: DemoStats
    #else
    @AppDependency(\.stats) var stats: DemoStats
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
            // Encrypted-file store; a missing store file means the initial value.
            return (try? SecretStore().get()) ?? ""
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
                throw APSError.invalidValue(key: key.rawValue, value: value)
            }
            var state = Application.state(\.counter)
            state.value = intValue
        case .message:
            var state = Application.state(\.message)
            state.value = value
        case .flag:
            guard let boolValue = Self.parseBool(value) else {
                throw APSError.invalidValue(key: key.rawValue, value: value)
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
                throw APSError.persistenceFailed(key: "note")
            }
        case .profile:
            let document: ProfileDocument
            do {
                guard let data = value.data(using: .utf8) else {
                    throw APSError.decodingFailed
                }
                document = try JSONDecoder().decode(ProfileDocument.self, from: data)
            } catch {
                throw APSError.invalidValue(key: key.rawValue, value: value)
            }
            try SchemaFileLock.withExclusiveLock(
                stateRoot: FileManager.defaultFileStatePath,
                lockFileName: "profile.json.lock"
            ) {
                try Self.refreshProfileFileStateFromDisk()
                var state = Application.fileState(\.profile)
                state.value = document
                let onDisk = try Self.readProfileFromDisk()
                guard onDisk == document else {
                    throw APSError.persistenceFailed(key: "profile")
                }
            }
        case .secret:
            // Encrypted-file store (issue #35): age-style envelope under the
            // state root; no Keychain, no prompts. Write then read-back verify.
            try SecretStore().set(value)
        case .profileName:
            // Refresh FileState from disk before Slice write so a stale cached
            // ProfileDocument cannot clobber a newer on-disk version.
            try SchemaFileLock.withExclusiveLock(
                stateRoot: FileManager.defaultFileStatePath,
                lockFileName: "profile.json.lock"
            ) {
                try Self.refreshProfileFileStateFromDisk()
                let expectedVersion = (try? Self.readProfileFromDisk())?.version ?? 0
                var slice = Application.slice(\.profile, \.name)
                slice.value = value
                let onDisk = try Self.readProfileFromDisk()
                guard onDisk.name == value, onDisk.version == expectedVersion else {
                    throw APSError.persistenceFailed(key: "profileName")
                }
            }
        }
        stats.recordMutation(key: key.rawValue)
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
            SecretStore().reset()
        case .profileName:
            try? Self.refreshProfileFileStateFromDisk()
            var slice = Application.slice(\.profile, \.name)
            slice.value = ""
        }
        stats.recordMutation(key: key.rawValue)
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
        return try jsonCoding.encodeAuto(snapshot)
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
    /// - An existing-but-undecodable FileState file throws `APSError.corruptState` instead of
    ///   falling back to AppState's initial/cached value.
    /// - `shouldContinue` lets tests (and CLI `--count` / `--timeout`) stop the loop cleanly.
    public func watchBlocking(
        _ key: DemoKey,
        pollInterval: TimeInterval = 0.25,
        shouldContinue: () -> Bool = { true },
        onChange: (String) -> Void
    ) throws {
        var last = try freshValue(key)
        onChange(last)

        let slice = max(pollInterval / 5.0, 0.05)

        while shouldContinue() {
            let flag = ChangeFlag()

            #if canImport(ObjectiveC)
            withObservationTracking {
                self.readForObservation(key)
            } onChange: {
                flag.mark()
            }
            #endif

            while shouldContinue() {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: slice))
                let current = try freshValue(key)
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
    ///
    /// Missing files fall back to `get`; existing undecodable files throw `corruptState`.
    private func freshValue(_ key: DemoKey) throws -> String {
        switch key {
        case .note:
            if let onDisk = try Self.readNoteFromDiskIfPresent() {
                return onDisk
            }
            return get(key)
        case .profile:
            if let document = try Self.readProfileFromDiskIfPresent() {
                return try encodeProfile(document)
            }
            return get(key)
        case .profileName:
            if let document = try Self.readProfileFromDiskIfPresent() {
                return document.name
            }
            return get(key)
        case .secret:
            // Encrypted store is file-backed: read it directly so cross-process
            // writes surface (there is no in-memory cache to consult anyway).
            // A missing store file means the initial value.
            let store = SecretStore()
            return store.hasSecret ? try store.get() : ""
        case .counter, .message, .flag:
            return get(key)
        }
    }

    /// Read `note.json` without touching AppState's in-memory FileState cache.
    ///
    /// Returns `nil` when the file is absent. Throws `corruptState` when the file exists
    /// but cannot be decoded (torn concurrent write). Throws `persistenceFailed` only when
    /// the caller required a present value (see `readNoteFromDisk()`).
    public static func readNoteFromDiskIfPresent() throws -> String? {
        let fileURL = Self.fileStateURL(filename: "note.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(String.self, from: data)
        } catch {
            throw APSError.corruptState(key: "note")
        }
    }

    /// Requires `note.json` to exist and decode; used after writes.
    public static func readNoteFromDisk() throws -> String {
        guard let value = try readNoteFromDiskIfPresent() else {
            throw APSError.persistenceFailed(key: "note")
        }
        return value
    }

    public static func readProfileFromDiskIfPresent() throws -> ProfileDocument? {
        let fileURL = Self.fileStateURL(filename: "profile.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(ProfileDocument.self, from: data)
        } catch {
            throw APSError.corruptState(key: "profile")
        }
    }

    /// Requires `profile.json` to exist and decode; used after writes.
    public static func readProfileFromDisk() throws -> ProfileDocument {
        guard let document = try readProfileFromDiskIfPresent() else {
            throw APSError.persistenceFailed(key: "profile")
        }
        return document
    }

    /// Ensures FileState-backed keys do not hide a torn on-disk file behind AppState initials.
    public static func requireDecodableDiskState(for key: DemoKey) throws {
        switch key {
        case .note:
            _ = try readNoteFromDiskIfPresent()
        case .profile, .profileName:
            _ = try readProfileFromDiskIfPresent()
        case .secret:
            // Loud failures for the encrypted store: corrupt envelope
            // (decodingFailed) and wrong passphrase/key (secretUnlockFailed).
            let store = SecretStore()
            if store.hasSecret {
                _ = try store.get()
            }
        case .counter, .message, .flag:
            break
        }
    }

    /// Loads `profile.json` into AppState's FileState cache when present.
    ///
    /// Slice writes mutate the cached parent document; without this refresh, a
    /// long-lived `StateStore` can preserve a stale `version` after another
    /// process updated the file. Corrupt on-disk JSON throws `corruptState`.
    private static func refreshProfileFileStateFromDisk() throws {
        let fresh = try readProfileFromDiskIfPresent() ?? ProfileDocument(name: "", version: 0)
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
            break // encrypted store has no Observation surface; polling covers it
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
