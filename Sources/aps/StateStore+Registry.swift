import AppState
import Foundation

extension StateStore {
    /// Active state root (FileState / schema.json directory).
    @MainActor
    public var stateRoot: String {
        FileManager.defaultFileStatePath
    }

    /// Load or materialize `<state-root>/schema.json`.
    @MainActor
    public func loadSchema() throws -> UserSchemaDocument {
        try UserSchema.loadOrMaterialize(stateRoot: stateRoot)
    }

    /// Resolve a registered key name.
    @MainActor
    public func resolve(_ name: String) throws -> SchemaKeyEntry {
        let schema = try loadSchema()
        guard let entry = UserSchema.entry(named: name, in: schema) else {
            throw APSError.unknownKey(name: name)
        }
        return entry
    }

    @MainActor
    public func get(name: String) throws -> String {
        let entry = try resolve(name)
        if let demo = DemoKey(rawValue: name) {
            return get(demo)
        }
        return try DynamicKeyStorage.get(
            entry: entry,
            stateRoot: stateRoot,
            schema: try loadSchema()
        )
    }

    @MainActor
    public func set(name: String, value: String) throws {
        let entry = try resolve(name)
        if let demo = DemoKey(rawValue: name) {
            try set(demo, value: value)
            return
        }
        try DynamicKeyStorage.set(
            entry: entry,
            value: value,
            stateRoot: stateRoot,
            schema: try loadSchema()
        )
        stats.recordMutation(key: name)
    }

    @MainActor
    public func reset(name: String) throws {
        let entry = try resolve(name)
        if let demo = DemoKey(rawValue: name) {
            reset(demo)
            return
        }
        try DynamicKeyStorage.reset(
            entry: entry,
            stateRoot: stateRoot,
            schema: try loadSchema()
        )
        stats.recordMutation(key: name)
    }

    @MainActor
    public func resetAllRegistered() throws {
        let schema = try loadSchema()
        for entry in schema.keys {
            try reset(name: entry.name)
        }
    }

    @MainActor
    public static func requireDecodableDiskState(forName name: String) throws {
        let root = FileManager.defaultFileStatePath
        let schema = try UserSchema.loadOrMaterialize(stateRoot: root)
        guard let entry = UserSchema.entry(named: name, in: schema) else {
            throw APSError.unknownKey(name: name)
        }
        if let demo = DemoKey(rawValue: name) {
            try requireDecodableDiskState(for: demo)
            return
        }
        try DynamicKeyStorage.requireDecodable(entry: entry, stateRoot: root)
    }

    /// Add or replace a schema entry and persist schema.json.
    ///
    /// Holds `SchemaFileLock` and re-reads under the lock so parallel `key add`
    /// cannot drop peer updates (issue #90).
    @MainActor
    public func addKey(_ entry: SchemaKeyEntry, force: Bool) throws {
        let root = stateRoot
        try SchemaFileLock.withExclusiveLock(stateRoot: root) {
            var schema = try UserSchema.loadOrMaterializeUnlocked(stateRoot: root)
            if let index = schema.keys.firstIndex(where: { $0.name == entry.name }) {
                guard force else {
                    throw APSError.schemaConflict(name: entry.name)
                }
                schema.keys[index] = entry
            } else {
                schema.keys.append(entry)
            }
            try UserSchema.write(schema, stateRoot: root)
        }
    }

    /// Remove a schema entry. Optionally delete FileState/EncryptedFile data.
    @MainActor
    public func removeKey(name: String, purge: Bool) throws {
        let root = stateRoot
        let entry: SchemaKeyEntry = try SchemaFileLock.withExclusiveLock(stateRoot: root) {
            var schema = try UserSchema.loadOrMaterializeUnlocked(stateRoot: root)
            guard let index = schema.keys.firstIndex(where: { $0.name == name }) else {
                throw APSError.unknownKey(name: name)
            }
            let removed = schema.keys[index]
            if schema.keys.contains(where: { $0.storage == "Slice" && $0.sliceOf == name }) {
                throw APSError.schemaInvalid(
                    reason: "cannot remove '\(name)' while slice keys still reference it"
                )
            }
            schema.keys.remove(at: index)
            try UserSchema.write(schema, stateRoot: root)
            return removed
        }
        if purge {
            switch entry.storage {
            case "FileState":
                if let path = entry.path {
                    let url = URL(fileURLWithPath: root).appendingPathComponent(path)
                    try? FileManager.default.removeItem(at: url)
                }
            case "EncryptedFile":
                let store = SecretStore(
                    directory: root,
                    storeFileName: entry.path ?? "\(name).enc",
                    keyName: name
                )
                store.reset()
            case "StoredState":
                let store = Application.dependency(\Application.userDefaults)
                store.removeObject(forKey: "aps.user.\(name)")
                (store as? UserDefaults)?.synchronize()
                UserDefaults.standard.synchronize()
            case "State":
                DynamicKeyStorage.clearMemory(named: name)
            default:
                break
            }
        }
    }

    @MainActor
    public func watchBlocking(
        name: String,
        pollInterval: TimeInterval = 0.25,
        pollDeadline: Date? = nil,
        shouldContinue: () -> Bool = { true },
        onChange: (String) -> Void
    ) throws {
        if let demo = DemoKey(rawValue: name) {
            try watchBlocking(
                demo,
                pollInterval: pollInterval,
                pollDeadline: pollDeadline,
                shouldContinue: shouldContinue,
                onChange: onChange
            )
            return
        }
        _ = try resolve(name)
        var last = try get(name: name)
        onChange(last)
        let slice = max(pollInterval / 5.0, 0.05)
        while shouldContinue() {
            waitForWatchPoll(interval: slice, deadline: pollDeadline)
            let current = try get(name: name)
            if current != last {
                last = current
                onChange(current)
            }
        }
    }

    @MainActor
    public func dumpRegistered() throws -> String {
        let schema = try loadSchema()
        let snapshot = RegistryDumpSnapshot(
            timestamp: now,
            keys: try schema.keys.map { entry in
                DumpEntry(
                    key: entry.name,
                    storage: entry.storage,
                    type: entry.type,
                    value: try CLIOutput.typedValue(for: entry, store: self)
                )
            }
        )
        return try jsonCoding.encodeAuto(snapshot)
    }
}

private struct RegistryDumpSnapshot: Encodable {
    let timestamp: Date
    let keys: [DumpEntry]
}

// DumpEntry is fileprivate in StateStore.swift — duplicate a local Encodable mirror.
private struct DumpEntry: Encodable {
    let key: String
    let storage: String
    let type: String
    let value: CLIOutput.JSONValue
}
