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
        let schema = try loadSchema()
        guard let entry = UserSchema.entry(named: name, in: schema) else {
            throw APSError.unknownKey(name: name)
        }
        return try DynamicKeyStorage.get(
            entry: entry,
            stateRoot: stateRoot,
            schema: schema
        )
    }

    @MainActor
    public func set(name: String, value: String) throws {
        let schema = try loadSchema()
        guard let entry = UserSchema.entry(named: name, in: schema) else {
            throw APSError.unknownKey(name: name)
        }
        try DynamicKeyStorage.set(
            entry: entry,
            value: value,
            stateRoot: stateRoot,
            schema: schema
        )
        stats.recordMutation(key: name)
    }

    @MainActor
    public func reset(name: String) throws {
        let schema = try loadSchema()
        guard let entry = UserSchema.entry(named: name, in: schema) else {
            throw APSError.unknownKey(name: name)
        }
        try DynamicKeyStorage.reset(
            entry: entry,
            stateRoot: stateRoot,
            schema: schema
        )
        stats.recordMutation(key: name)
    }

    @MainActor
    public func resetAllRegistered() throws {
        let schema = try loadSchema()
        for entry in schema.keys {
            try DynamicKeyStorage.reset(
                entry: entry,
                stateRoot: stateRoot,
                schema: schema
            )
            stats.recordMutation(key: entry.name)
        }
    }

    @MainActor
    internal func resetAllSeedKeys() throws {
        let schema = try loadSchema()
        let seedNames = Set(DemoKey.allCases.map(\.rawValue))
        for entry in schema.keys where seedNames.contains(entry.name) {
            try DynamicKeyStorage.reset(
                entry: entry,
                stateRoot: stateRoot,
                schema: schema
            )
            stats.recordMutation(key: entry.name)
        }
    }

    @MainActor
    public static func requireDecodableDiskState(forName name: String) throws {
        let root = FileManager.defaultFileStatePath
        let schema = try UserSchema.loadOrMaterialize(stateRoot: root)
        guard let entry = UserSchema.entry(named: name, in: schema) else {
            throw APSError.unknownKey(name: name)
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
                    try SchemaStoragePath(path).removeRegularFileIfPresent(stateRoot: root)
                }
            case "EncryptedFile":
                if let path = entry.path {
                    try SchemaStoragePath(path).removeRegularFileIfPresent(stateRoot: root)
                }
            case "StoredState":
                DynamicKeyStorage.removeStoredValue(entry)
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
        let schema = try loadSchema()
        guard let entry = UserSchema.entry(named: name, in: schema) else {
            throw APSError.unknownKey(name: name)
        }
        var last = try DynamicKeyStorage.get(
            entry: entry,
            stateRoot: stateRoot,
            schema: schema
        )
        onChange(last)
        let slice = max(pollInterval / 5.0, 0.05)
        while shouldContinue() {
            waitForWatchPoll(interval: slice, deadline: pollDeadline)
            let current = try DynamicKeyStorage.get(
                entry: entry,
                stateRoot: stateRoot,
                schema: schema
            )
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

private struct DumpEntry: Encodable {
    let key: String
    let storage: String
    let type: String
    let value: CLIOutput.JSONValue
}
