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
        if !usesDefaultDefinition(key) {
            return (try? get(name: key.rawValue)) ?? ""
        }
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
        try set(
            name: key.rawValue,
            value: value,
            storageOperation: { entry, rawValue, root, schema in
                guard isDefaultDefinition(entry, for: key) else {
                    try DynamicKeyStorage.set(
                        entry: entry,
                        value: rawValue,
                        stateRoot: root,
                        schema: schema
                    )
                    return
                }
                if key == .flag {
                    try setDefaultFlagAdapter(entry, value: rawValue)
                    return
                }
                try setDefaultAdapter(key, value: rawValue)
            }
        )
    }

    private func setDefaultAdapter(_ key: DemoKey, value: String) throws {
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
            guard
                let entry = UserSchema.defaultDocument().keys.first(where: { $0.name == key.rawValue })
            else {
                throw APSError.schemaInvalid(reason: "default flag definition is missing")
            }
            try setDefaultFlagAdapter(entry, value: value)
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
            try SchemaFileLock.withExclusiveStorageLock(
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
            try SchemaFileLock.withExclusiveStorageLock(
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
    }

    /// Persists the default flag through both registry and AppState keys as one
    /// verified operation, restoring their exact prior objects after failure.
    private func setDefaultFlagAdapter(_ entry: SchemaKeyEntry, value: String) throws {
        guard let boolValue = Self.parseBool(value) else {
            throw APSError.invalidValue(key: entry.name, value: value)
        }
        let store = Application.dependency(\Application.userDefaults)
        let canonicalKey = "aps.user.flag"
        let legacyKey = "App/aps.flag"
        let oldCanonical = store.object(forKey: canonicalKey)
        let oldLegacy = store.object(forKey: legacyKey)
        let oldAdapterValue = Self.decodeStoredBool(oldLegacy) ?? false

        do {
            store.set(boolValue, forKey: canonicalKey)
            var state = Application.state(\.flag)
            state.value = boolValue
            guard
                Self.synchronize(store),
                store.object(forKey: canonicalKey) as? Bool == boolValue,
                Self.decodeLegacyFlag(store.object(forKey: legacyKey)) == boolValue
            else {
                throw APSError.persistenceFailed(key: entry.name)
            }
        } catch {
            var state = Application.state(\.flag)
            state.value = oldAdapterValue
            Self.restoreStoredObject(oldCanonical, forKey: canonicalKey, in: store)
            Self.restoreStoredObject(oldLegacy, forKey: legacyKey, in: store)
            guard
                Self.synchronize(store),
                Self.storedObjectsEqual(store.object(forKey: canonicalKey), oldCanonical),
                Self.storedObjectsEqual(store.object(forKey: legacyKey), oldLegacy)
            else {
                let failure = error as? APSError ?? .persistenceFailed(key: entry.name)
                throw APSError.rollbackFailed(
                    context: .storedState(key: entry.name),
                    originalErrorCode: failure.code,
                    originalErrorDescription: failure.description
                )
            }
            throw error
        }
    }

    private static func decodeStoredBool(_ object: Any?) -> Bool? {
        if let data = object as? Data {
            return try? JSONDecoder().decode(Bool.self, from: data)
        }
        if let boolValue = object as? Bool {
            return boolValue
        }
        if let stringValue = object as? String {
            return parseBool(stringValue)
        }
        return nil
    }

    private static func decodeLegacyFlag(_ object: Any?) -> Bool? {
        guard let data = object as? Data else { return nil }
        return try? JSONDecoder().decode(Bool.self, from: data)
    }

    private static func synchronize(_ store: any UserDefaultsManaging) -> Bool {
        if let synchronizingStore = store as? any UserDefaultsSynchronizing {
            return synchronizingStore.synchronize()
        }
        if let defaults = store as? UserDefaults {
            return defaults.synchronize()
        }
        if store is Application.SendableUserDefaults {
            return UserDefaults.standard.synchronize()
        }
        return true
    }

    private static func restoreStoredObject(
        _ object: Any?,
        forKey key: String,
        in store: any UserDefaultsManaging
    ) {
        if let object {
            store.set(object, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    private static func storedObjectsEqual(_ left: Any?, _ right: Any?) -> Bool {
        switch (left, right) {
        case (.none, .none):
            return true
        case (.some(let leftObject), .some(let rightObject)):
            guard
                String(reflecting: type(of: leftObject)) == String(reflecting: type(of: rightObject)),
                let leftValue = leftObject as? NSObject,
                let rightValue = rightObject as? NSObject
            else { return false }
            return leftValue.isEqual(rightValue)
        default:
            return false
        }
    }

    @discardableResult
    public func reset(_ key: DemoKey) throws -> ResetOutcome {
        try reset(key, afterAcquiringProfileStorageLock: {})
    }

    /// Reset seam used to prove profile adapter synchronization stays inside its storage lock.
    @discardableResult
    internal func reset(
        _ key: DemoKey,
        afterAcquiringProfileStorageLock: () -> Void
    ) throws -> ResetOutcome {
        try reset(
            name: key.rawValue,
            recordMutation: true,
            afterReset: { entry in
                if isDefaultDefinition(entry, for: key) {
                    try synchronizeDefaultAdapter(
                        afterResetting: key,
                        afterAcquiringProfileStorageLock: afterAcquiringProfileStorageLock
                    )
                }
            }
        )
    }

    @discardableResult
    public func resetAll() throws -> BulkResetReport {
        let root = stateRoot
        return try SchemaFileLock.withExclusiveLock(stateRoot: root) {
            let schema = try UserSchema.loadOrMaterializeUnlocked(stateRoot: root)
            let entries = schema.keys.filter { DemoKey(rawValue: $0.name) != nil }
            return try reset(
                entries: entries,
                schema: schema,
                afterReset: { entry in
                    guard
                        let key = DemoKey(rawValue: entry.name),
                        isDefaultDefinition(entry, for: key)
                    else {
                        return
                    }
                    try synchronizeDefaultAdapter(afterResetting: key)
                }
            )
        }
    }

    private func usesDefaultDefinition(_ key: DemoKey) -> Bool {
        guard
            let current = try? resolve(key.rawValue)
        else {
            return false
        }
        return isDefaultDefinition(current, for: key)
    }

    private func isDefaultDefinition(_ entry: SchemaKeyEntry, for key: DemoKey) -> Bool {
        guard let defaultEntry = UserSchema.defaultDocument().keys.first(where: { $0.name == key.rawValue }) else {
            return false
        }
        return entry.name == defaultEntry.name
            && entry.type == defaultEntry.type
            && entry.storage == defaultEntry.storage
            && entry.initial == defaultEntry.initial
            && entry.path == defaultEntry.path
            && entry.objectShape == defaultEntry.objectShape
            && entry.sliceOf == defaultEntry.sliceOf
            && entry.sliceField == defaultEntry.sliceField
    }

    internal func synchronizeDefaultAdapter(
        afterResetting key: DemoKey,
        afterAcquiringProfileStorageLock: () -> Void = {}
    ) throws {
        switch key {
        case .counter:
            Application.reset(\.counter)
            guard Application.state(\.counter).value == 0 else {
                throw APSError.persistenceFailed(key: key.rawValue)
            }
        case .message:
            Application.reset(\.message)
            guard Application.state(\.message).value.isEmpty else {
                throw APSError.persistenceFailed(key: key.rawValue)
            }
        case .flag:
            Application.reset(storedState: \.flag)
            guard Application.state(\.flag).value == false else {
                throw APSError.persistenceFailed(key: key.rawValue)
            }
        case .note:
            try synchronizeNoteAdapter()
        case .profile:
            try synchronizeProfileAdapter()
        case .secret:
            break
        case .profileName:
            try synchronizeProfileNameAdapter(
                afterAcquiringStorageLock: afterAcquiringProfileStorageLock
            )
        }
    }

    /// Synchronizes the default note cache to the current disk value without
    /// replacing a valid write that arrived after the registry reset.
    private func synchronizeNoteAdapter() throws {
        try SchemaFileLock.withExclusiveStorageLock(
            stateRoot: stateRoot,
            lockFileName: "note.json.lock"
        ) {
            let fresh = try Self.readNoteFromDiskIfPresent() ?? ""
            var state = Application.fileState(\.note)
            state.value = fresh
            guard try Self.readNoteFromDisk() == fresh else {
                throw APSError.persistenceFailed(key: DemoKey.note.rawValue)
            }
        }
    }

    /// Synchronizes the default profile cache to the current disk value without
    /// replacing a valid write that arrived after the registry reset.
    private func synchronizeProfileAdapter() throws {
        try SchemaFileLock.withExclusiveStorageLock(
            stateRoot: stateRoot,
            lockFileName: "profile.json.lock"
        ) {
            let fresh = try Self.readProfileFromDiskIfPresent() ?? ProfileDocument()
            var state = Application.fileState(\.profile)
            state.value = fresh
            guard try Self.readProfileFromDisk() == fresh else {
                throw APSError.persistenceFailed(key: DemoKey.profile.rawValue)
            }
        }
    }

    /// Synchronizes the AppState profile-name adapter while holding the parent storage lock.
    ///
    /// The caller already holds the schema lock during public reset operations, preserving
    /// the supported schema-then-storage lock order. The test seam runs after storage locking
    /// and before the parent refresh so regression tests can prove the full read-modify-write
    /// remains serialized.
    internal func synchronizeProfileNameAdapter(
        afterAcquiringStorageLock: () -> Void = {}
    ) throws {
        try SchemaFileLock.withExclusiveStorageLock(
            stateRoot: stateRoot,
            lockFileName: "profile.json.lock"
        ) {
            afterAcquiringStorageLock()
            try Self.refreshProfileFileStateFromDisk()
            var slice = Application.slice(\.profile, \.name)
            slice.value = ""
            guard try Self.readProfileFromDisk().name.isEmpty else {
                throw APSError.persistenceFailed(key: DemoKey.profileName.rawValue)
            }
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
        pollDeadline: Date? = nil,
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
            waitForWatchPoll(interval: slice, deadline: pollDeadline)
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

    /// Blocking watch for the synchronous CLI: Observation plus platform-safe polling.
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
        pollDeadline: Date? = nil,
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
                waitForWatchPoll(interval: slice, deadline: pollDeadline)
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
