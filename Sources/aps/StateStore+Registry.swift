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
        try valueSnapshot(name: name).raw
    }

    @MainActor
    internal func valueSnapshot(name: String) throws -> (entry: SchemaKeyEntry, raw: String) {
        let schema = try loadSchema()
        guard let entry = UserSchema.entry(named: name, in: schema) else {
            throw APSError.unknownKey(name: name)
        }
        let raw = try DynamicKeyStorage.get(
            entry: entry,
            stateRoot: stateRoot,
            schema: schema
        )
        return (entry, raw)
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
    @discardableResult
    public func reset(name: String) throws -> ResetOutcome {
        try reset(name: name, recordMutation: true)
    }

    @MainActor
    @discardableResult
    internal func reset(name: String, recordMutation: Bool) throws -> ResetOutcome {
        let schema = try loadSchema()
        guard let entry = UserSchema.entry(named: name, in: schema) else {
            throw APSError.unknownKey(name: name)
        }
        let outcome: ResetOutcome
        do {
            outcome = try DynamicKeyStorage.reset(
                entry: entry,
                stateRoot: stateRoot,
                schema: schema
            )
        } catch let error as APSError {
            throw error
        } catch {
            throw APSError.persistenceFailed(key: name)
        }
        if recordMutation {
            stats.recordMutation(key: name)
        }
        return outcome
    }

    @MainActor
    @discardableResult
    public func resetAllRegistered() throws -> BulkResetReport {
        let schema = try loadSchema()
        return try reset(entries: schema.keys, schema: schema)
    }

    @MainActor
    @discardableResult
    internal func resetAllSeedKeys() throws -> BulkResetReport {
        let schema = try loadSchema()
        let seedNames = Set(DemoKey.allCases.map(\.rawValue))
        return try reset(
            entries: schema.keys.filter { seedNames.contains($0.name) },
            schema: schema
        )
    }

    @MainActor
    private func reset(
        entries: [SchemaKeyEntry],
        schema: UserSchemaDocument
    ) throws -> BulkResetReport {
        var resetNames: [String] = []
        for (index, entry) in entries.enumerated() {
            do {
                _ = try DynamicKeyStorage.reset(
                    entry: entry,
                    stateRoot: stateRoot,
                    schema: schema
                )
                stats.recordMutation(key: entry.name)
                resetNames.append(entry.name)
            } catch let error as APSError {
                let report = BulkResetReport(
                    reset: resetNames,
                    failed: ResetFailure(key: entry.name, error: error),
                    notAttempted: entries.dropFirst(index + 1).map(\.name)
                )
                throw BulkResetError(report: report, underlying: error)
            } catch {
                let normalized = APSError.persistenceFailed(key: entry.name)
                let report = BulkResetReport(
                    reset: resetNames,
                    failed: ResetFailure(key: entry.name, error: normalized),
                    notAttempted: entries.dropFirst(index + 1).map(\.name)
                )
                throw BulkResetError(report: report, underlying: normalized)
            }
        }
        return .success(reset: resetNames)
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
        try removeKey(
            name: name,
            purge: purge,
            purgeOperation: { entry, root in
                try DynamicKeyStorage.purge(entry: entry, stateRoot: root)
            },
            schemaWriter: { schema, root in
                try UserSchema.write(schema, stateRoot: root)
            }
        )
    }

    /// Transactional removal seam for deterministic purge and rollback tests.
    @MainActor
    internal func removeKey(
        name: String,
        purge: Bool,
        purgeOperation: (SchemaKeyEntry, String) throws -> Void,
        schemaWriter: (UserSchemaDocument, String) throws -> Void
    ) throws {
        let root = stateRoot
        try SchemaFileLock.withExclusiveLock(stateRoot: root) {
            let original = try UserSchema.loadOrMaterializeUnlocked(stateRoot: root)
            guard let index = original.keys.firstIndex(where: { $0.name == name }) else {
                throw APSError.unknownKey(name: name)
            }
            let removed = original.keys[index]
            if original.keys.contains(where: { $0.storage == "Slice" && $0.sliceOf == name }) {
                throw APSError.schemaInvalid(
                    reason: "cannot remove '\(name)' while slice keys still reference it"
                )
            }
            var candidate = original
            candidate.keys.remove(at: index)
            try schemaWriter(candidate, root)
            guard purge else { return }

            do {
                try purgeOperation(removed, root)
            } catch {
                let purgeError = (error as? APSError) ?? APSError.persistenceFailed(key: name)
                do {
                    try schemaWriter(original, root)
                } catch {
                    throw APSError.rollbackFailed
                }
                throw purgeError
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
                let raw = try DynamicKeyStorage.get(
                    entry: entry,
                    stateRoot: stateRoot,
                    schema: schema
                )
                return DumpEntry(
                    key: entry.name,
                    storage: entry.storage,
                    type: entry.type,
                    value: try CLIOutput.typedValue(for: entry, from: raw)
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
