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
        try set(
            name: name,
            value: value,
            storageOperation: { entry, rawValue, root, schema in
                if
                    entry.name == DemoKey.flag.rawValue,
                    isDefaultDefinition(entry, for: .flag, in: schema)
                {
                    try setDefaultFlagAdapter(entry, value: rawValue)
                    return
                }
                try DynamicKeyStorage.set(
                    entry: entry,
                    value: rawValue,
                    stateRoot: root,
                    schema: schema
                )
            }
        )
    }

    /// Storage seam used to prove the schema lock spans resolution and persistence.
    @MainActor
    internal func set(
        name: String,
        value: String,
        storageOperation: (
            SchemaKeyEntry,
            String,
            String,
            UserSchemaDocument
        ) throws -> Void
    ) throws {
        let root = stateRoot
        try SchemaFileLock.withExclusiveLock(stateRoot: root) {
            let schema = try UserSchema.loadOrMaterializeUnlocked(stateRoot: root)
            guard let entry = UserSchema.entry(named: name, in: schema) else {
                throw APSError.unknownKey(name: name)
            }
            try storageOperation(entry, value, root, schema)
        }
        stats.recordMutation(key: name)
    }

    @MainActor
    @discardableResult
    public func reset(name: String) throws -> ResetOutcome {
        try reset(name: name, recordMutation: true, afterReset: { _ in })
    }

    @MainActor
    @discardableResult
    internal func reset(
        name: String,
        recordMutation: Bool,
        fileOperations: DynamicKeyStorage.FileOperations = .live,
        afterReset: (SchemaKeyEntry) throws -> Void
    ) throws -> ResetOutcome {
        let root = stateRoot
        let outcome = try SchemaFileLock.withExclusiveLock(stateRoot: root) {
            let schema = try UserSchema.loadOrMaterializeUnlocked(stateRoot: root)
            guard let entry = UserSchema.entry(named: name, in: schema) else {
                throw APSError.unknownKey(name: name)
            }
            do {
                let resetOutcome = try DynamicKeyStorage.reset(
                    entry: entry,
                    stateRoot: root,
                    schema: schema,
                    fileOperations: fileOperations,
                    afterReset: {
                        try afterReset(entry)
                    }
                )
                return resetOutcome
            } catch let error as APSError {
                throw error
            } catch {
                throw APSError.persistenceFailed(key: name)
            }
        }
        if recordMutation {
            stats.recordMutation(key: name)
        }
        return outcome
    }

    @MainActor
    @discardableResult
    public func resetAllRegistered() throws -> BulkResetReport {
        let root = stateRoot
        return try publishingBulkResetStats {
            try SchemaFileLock.withExclusiveLock(stateRoot: root) {
                let schema = try UserSchema.loadOrMaterializeUnlocked(stateRoot: root)
                return try reset(entries: schema.keys, schema: schema)
            }
        }
    }

    @MainActor
    @discardableResult
    internal func resetAllSeedKeys() throws -> BulkResetReport {
        let root = stateRoot
        return try publishingBulkResetStats {
            try SchemaFileLock.withExclusiveLock(stateRoot: root) {
                let schema = try UserSchema.loadOrMaterializeUnlocked(stateRoot: root)
                let seedNames = Set(DemoKey.allCases.map(\.rawValue))
                return try reset(
                    entries: schema.keys.filter { seedNames.contains($0.name) },
                    schema: schema,
                    afterReset: { _ in }
                )
            }
        }
    }

    /// Publishes verified bulk-reset mutations after the enclosing schema lock returns.
    @MainActor
    internal func publishingBulkResetStats(
        _ operation: () throws -> BulkResetReport
    ) throws -> BulkResetReport {
        do {
            let report = try operation()
            publishBulkResetStats(for: report.reset)
            return report
        } catch let error as BulkResetError {
            publishBulkResetStats(for: error.report.reset)
            throw error
        }
    }

    @MainActor
    private func publishBulkResetStats(for resetNames: [String]) {
        for name in resetNames {
            stats.recordMutation(key: name)
        }
    }

    @MainActor
    internal func reset(
        entries: [SchemaKeyEntry],
        schema: UserSchemaDocument,
        fileOperations: DynamicKeyStorage.FileOperations = .live,
        beforeReset: (SchemaKeyEntry) throws -> Void = { _ in },
        afterReset: (SchemaKeyEntry) throws -> Void = { _ in }
    ) throws -> BulkResetReport {
        let selectedNames = entries.map(\.name)
        var resetNames: [String] = []
        for (index, entry) in entries.enumerated() {
            do {
                if let error = bulkResetCompatibilityError(
                    for: entry.name,
                    at: index,
                    selectedNames: selectedNames,
                    schema: schema
                ) {
                    throw error
                }
                try beforeReset(entry)
                _ = try DynamicKeyStorage.reset(
                    entry: entry,
                    stateRoot: stateRoot,
                    schema: schema,
                    fileOperations: fileOperations,
                    afterReset: {
                        try afterReset(entry)
                    }
                )
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

    /// Rejects incompatible parent/Slice and sibling Slice reset combinations.
    @MainActor
    internal func bulkResetCompatibilityError(
        for name: String,
        at index: Int,
        selectedNames: [String],
        schema: UserSchemaDocument
    ) -> APSError? {
        guard let entry = UserSchema.entry(named: name, in: schema) else {
            return nil
        }

        for laterName in selectedNames.dropFirst(index + 1) {
            guard let later = UserSchema.entry(named: laterName, in: schema) else {
                continue
            }
            if let error = incompatibleResetPair(first: entry, second: later, schema: schema) {
                return error
            }
        }
        return nil
    }

    @MainActor
    private func incompatibleResetPair(
        first: SchemaKeyEntry,
        second: SchemaKeyEntry,
        schema: UserSchemaDocument
    ) -> APSError? {
        if first.storage == "Slice", second.storage == "Slice" {
            guard
                first.sliceOf == second.sliceOf,
                first.sliceField == second.sliceField,
                first.initial != second.initial
                    || effectiveSliceType(first, schema: schema) != effectiveSliceType(second, schema: schema)
            else {
                return nil
            }
            return .schemaInvalid(
                reason: "\(first.name) initial conflicts with selected sibling slice '\(second.name)'"
            )
        }

        let slice: SchemaKeyEntry
        let parent: SchemaKeyEntry
        if first.storage == "Slice", first.sliceOf == second.name {
            slice = first
            parent = second
        } else if second.storage == "Slice", second.sliceOf == first.name {
            slice = second
            parent = first
        } else {
            return nil
        }

        guard
            let field = slice.sliceField,
            case .object(let initialObject) = parent.initial,
            (initialObject[field] ?? slice.initial) == slice.initial
        else {
            return .schemaInvalid(
                reason: "\(slice.name) initial conflicts with selected parent reset '\(parent.name)'"
            )
        }
        return nil
    }

    @MainActor
    private func effectiveSliceType(
        _ slice: SchemaKeyEntry,
        schema: UserSchemaDocument
    ) -> String {
        guard
            let parentName = slice.sliceOf,
            let field = slice.sliceField,
            let parent = UserSchema.entry(named: parentName, in: schema)
        else {
            return slice.type
        }
        return parent.objectShape?[field] ?? slice.type
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
        schemaWriter: (UserSchemaDocument, String) throws -> Void,
        schemaLoader: (String) throws -> UserSchemaDocument = { root in
            try UserSchema.loadUnlocked(stateRoot: root)
        }
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
            let postconditionError = APSError.persistenceFailed(key: UserSchema.fileName)
            do {
                try schemaWriter(candidate, root)
                do {
                    guard try schemaLoader(root) == candidate else {
                        throw postconditionError
                    }
                } catch {
                    throw postconditionError
                }
            } catch {
                let candidateError = (error as? APSError) ?? postconditionError
                do {
                    try schemaWriter(original, root)
                } catch {
                    // Verification below is authoritative when a writer persists
                    // the requested document and then reports an error.
                }
                do {
                    guard try schemaLoader(root) == original else {
                        throw APSError.persistenceFailed(key: UserSchema.fileName)
                    }
                } catch {
                    throw APSError.rollbackFailed(
                        context: .schemaCandidate(key: name),
                        originalErrorCode: candidateError.code,
                        originalErrorDescription: candidateError.description
                    )
                }
                throw candidateError
            }
            guard purge else { return }

            do {
                try purgeOperation(removed, root)
            } catch {
                let purgeError = (error as? APSError) ?? APSError.persistenceFailed(key: name)
                do {
                    try schemaWriter(original, root)
                } catch {
                    // Verification below is authoritative when a writer persists
                    // the requested document and then reports an error.
                }
                do {
                    guard try schemaLoader(root) == original else {
                        throw APSError.persistenceFailed(key: UserSchema.fileName)
                    }
                } catch {
                    throw APSError.rollbackFailed(
                        context: .schema(key: name),
                        originalErrorCode: purgeError.code,
                        originalErrorDescription: purgeError.description
                    )
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
        if entry.storage == "EncryptedFile" {
            let store = try DynamicKeyStorage.encryptedStore(entry, stateRoot: stateRoot)
            try watchEncryptedStore(
                store,
                initialValue: entry.initial?.wireString ?? "",
                pollInterval: pollInterval,
                pollDeadline: pollDeadline,
                shouldContinue: shouldContinue,
                onChange: onChange
            )
            return
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
        return try dumpRegistered(entries: schema.keys, schema: schema)
    }

    /// Encodes the selected registry entries in their supplied deterministic order.
    @MainActor
    internal func dumpRegistered(
        entries: [SchemaKeyEntry],
        schema: UserSchemaDocument
    ) throws -> String {
        try dumpRegistered(
            entries: entries,
            schema: schema,
            rawValueForEntry: { entry in
                try DynamicKeyStorage.get(
                    entry: entry,
                    stateRoot: stateRoot,
                    schema: schema
                )
            }
        )
    }

    /// Encodes selected entries while allowing seed adapters to supply their live values.
    @MainActor
    internal func dumpRegistered(
        entries: [SchemaKeyEntry],
        schema: UserSchemaDocument,
        rawValueForEntry: (SchemaKeyEntry) throws -> String
    ) throws -> String {
        let snapshot = RegistryDumpSnapshot(
            timestamp: now,
            keys: try entries.map { entry in
                let raw = try rawValueForEntry(entry)
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
