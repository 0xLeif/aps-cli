import Foundation
import AppState
import Crypto

internal protocol UserDefaultsSynchronizing: UserDefaultsManaging {
    func synchronize() -> Bool
}

/// Process-local and file-backed storage for user-defined schema keys.
@MainActor
enum DynamicKeyStorage {
    internal struct FileOperations: Sendable {
        internal let fileExists: @Sendable (URL) -> Bool
        internal let read: @Sendable (URL) throws -> Data
        internal let write: @Sendable (Data, URL) throws -> Void
        internal let remove: @Sendable (URL) throws -> Void

        internal init(
            fileExists: @escaping @Sendable (URL) -> Bool,
            read: @escaping @Sendable (URL) throws -> Data,
            write: @escaping @Sendable (Data, URL) throws -> Void,
            remove: @escaping @Sendable (URL) throws -> Void
        ) {
            self.fileExists = fileExists
            self.read = read
            self.write = write
            self.remove = remove
        }

        internal static let live = FileOperations(
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            read: { try Data(contentsOf: $0) },
            write: { try $0.write(to: $1, options: .atomic) },
            remove: { try FileManager.default.removeItem(at: $0) }
        )
    }

    private enum FileSnapshot: Equatable {
        case absent
        case present(Data)
    }

    private static var memoryStrings: [String: String] = [:]
    private static var memoryInts: [String: Int] = [:]
    private static var memoryBools: [String: Bool] = [:]

    static func resetProcessMemory() {
        memoryStrings = [:]
        memoryInts = [:]
        memoryBools = [:]
    }

    static func clearMemory(named name: String) {
        memoryStrings.removeValue(forKey: name)
        memoryInts.removeValue(forKey: name)
        memoryBools.removeValue(forKey: name)
    }

    static func get(entry: SchemaKeyEntry, stateRoot: String, schema: UserSchemaDocument) throws -> String {
        let value: String
        switch entry.storage {
        case "State":
            value = memoryGet(entry)
        case "StoredState":
            value = storedGet(entry)
        case "FileState":
            value = try fileGet(entry, stateRoot: stateRoot)
        case "EncryptedFile":
            value = try encryptedGet(entry, stateRoot: stateRoot)
        case "Slice":
            value = try sliceGet(entry: entry, stateRoot: stateRoot, schema: schema)
        default:
            throw APSError.schemaInvalid(reason: "unsupported storage \(entry.storage)")
        }
        try validateReadValue(value, for: entry)
        return value
    }

    static func set(
        entry: SchemaKeyEntry,
        value: String,
        stateRoot: String,
        schema: UserSchemaDocument
    ) throws {
        _ = try requestedValue(value, for: entry)
        switch entry.storage {
        case "State":
            try memorySet(entry, value: value)
        case "StoredState":
            try storedSet(entry, value: value)
        case "FileState":
            try fileSet(entry, value: value, stateRoot: stateRoot)
        case "EncryptedFile":
            try encryptedSet(entry, value: value, stateRoot: stateRoot)
        case "Slice":
            try sliceSet(entry: entry, value: value, stateRoot: stateRoot, schema: schema)
        default:
            throw APSError.schemaInvalid(reason: "unsupported storage \(entry.storage)")
        }
    }

    @discardableResult
    static func reset(
        entry: SchemaKeyEntry,
        stateRoot: String,
        schema: UserSchemaDocument,
        fileOperations: FileOperations = .live,
        afterReset: () throws -> Void = {}
    ) throws -> ResetOutcome {
        guard
            let initialValue = entry.initial,
            initialValue.matches(type: entry.type, objectShape: entry.objectShape)
        else {
            throw APSError.schemaInvalid(reason: "\(entry.name) initial does not match \(entry.type)")
        }
        let initial = initialValue.wireString
        switch entry.storage {
        case "State":
            let oldString = memoryStrings[entry.name]
            let oldInt = memoryInts[entry.name]
            let oldBool = memoryBools[entry.name]
            do {
                memoryStrings.removeValue(forKey: entry.name)
                memoryInts.removeValue(forKey: entry.name)
                memoryBools.removeValue(forKey: entry.name)
                try memorySet(entry, value: initial)
                try afterReset()
            } catch {
                restoreMemoryValue(oldString, forKey: entry.name, in: &memoryStrings)
                restoreMemoryValue(oldInt, forKey: entry.name, in: &memoryInts)
                restoreMemoryValue(oldBool, forKey: entry.name, in: &memoryBools)
                throw error
            }
        case "StoredState":
            let store = userDefaults
            try resetStoredValue(
                entry,
                initial: initial,
                in: store,
                afterReset: afterReset
            )
        case "FileState":
            try SchemaFileLock.withExclusiveStorageLock(
                stateRoot: stateRoot,
                lockFileName: try fileLockName(entry),
                resourceKey: entry.name
            ) {
                try resetFileTransaction(
                    entry: entry,
                    stateRoot: stateRoot,
                    operations: fileOperations
                ) {
                    try fileSetUnlocked(
                        entry,
                        value: initial,
                        stateRoot: stateRoot,
                        operations: fileOperations
                    )
                    guard try fileGet(
                        entry,
                        stateRoot: stateRoot,
                        operations: fileOperations
                    ) == initial else {
                        throw APSError.persistenceFailed(key: entry.name)
                    }
                    try afterReset()
                }
            }
        case "EncryptedFile":
            // The default encrypted adapter is intentionally a no-op. Run the
            // callback first so a future injected adapter failure cannot delete
            // an existing envelope without a rollback-capable secret transaction.
            try afterReset()
            _ = try encryptedStore(entry, stateRoot: stateRoot).reset()
        case "Slice":
            let parent = try sliceParent(entry: entry, schema: schema)
            try SchemaFileLock.withExclusiveStorageLock(
                stateRoot: stateRoot,
                lockFileName: try fileLockName(parent),
                resourceKey: entry.name
            ) {
                try resetFileTransaction(
                    entry: parent,
                    stateRoot: stateRoot,
                    operations: fileOperations
                ) {
                    try sliceSetUnlocked(
                        entry: entry,
                        parent: parent,
                        value: initial,
                        stateRoot: stateRoot,
                        operations: fileOperations
                    )
                    guard try sliceGetUnlocked(
                        entry: entry,
                        parent: parent,
                        stateRoot: stateRoot,
                        operations: fileOperations
                    ) == initial else {
                        throw APSError.persistenceFailed(key: entry.name)
                    }
                    try afterReset()
                }
            }
        default:
            throw APSError.schemaInvalid(reason: "unsupported storage \(entry.storage)")
        }
        return ResetOutcome(key: entry.name)
    }

    private static func requestedValue(
        _ rawValue: String,
        for entry: SchemaKeyEntry
    ) throws -> SchemaJSON {
        guard
            let value = SchemaJSON.parse(rawValue, as: entry.type),
            value.matches(type: entry.type, objectShape: entry.objectShape)
        else {
            throw APSError.invalidValue(key: entry.name, value: rawValue)
        }
        return value
    }

    private static func validateReadValue(
        _ rawValue: String,
        for entry: SchemaKeyEntry
    ) throws {
        guard
            let value = SchemaJSON.parse(rawValue, as: entry.type),
            value.matches(type: entry.type, objectShape: entry.objectShape)
        else {
            throw APSError.corruptState(key: entry.name)
        }
    }

    private static func restoreMemoryValue<Value>(
        _ value: Value?,
        forKey key: String,
        in storage: inout [String: Value]
    ) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }

    static func purge(entry: SchemaKeyEntry, stateRoot: String) throws {
        switch entry.storage {
        case "FileState":
            _ = try SchemaFileLock.withExclusiveStorageLock(
                stateRoot: stateRoot,
                lockFileName: try fileLockName(entry),
                resourceKey: entry.name
            ) {
                try storagePath(for: entry).removeRegularFileIfPresent(stateRoot: stateRoot)
            }
        case "EncryptedFile":
            _ = try encryptedStore(entry, stateRoot: stateRoot).reset()
        case "StoredState":
            try removeStoredValue(entry)
        case "State":
            clearMemory(named: entry.name)
        case "Slice":
            break
        default:
            throw APSError.schemaInvalid(reason: "unsupported storage \(entry.storage)")
        }
    }

    static func requireDecodable(entry: SchemaKeyEntry, stateRoot: String) throws {
        switch entry.storage {
        case "FileState":
            _ = try fileGet(entry, stateRoot: stateRoot)
        case "EncryptedFile":
            let store = try encryptedStore(entry, stateRoot: stateRoot)
            if store.hasSecret {
                _ = try store.get()
            }
        default:
            break
        }
    }

    // MARK: - State

    private static func memoryGet(_ entry: SchemaKeyEntry) -> String {
        switch entry.type {
        case "Int":
            if let value = memoryInts[entry.name] { return String(value) }
            return entry.initial?.wireString ?? "0"
        case "Bool":
            if let value = memoryBools[entry.name] { return value ? "true" : "false" }
            return entry.initial?.wireString ?? "false"
        default:
            return memoryStrings[entry.name] ?? entry.initial?.wireString ?? ""
        }
    }

    private static func memorySet(_ entry: SchemaKeyEntry, value: String) throws {
        switch entry.type {
        case "Int":
            guard let intValue = Int(value) else {
                throw APSError.invalidValue(key: entry.name, value: value)
            }
            memoryInts[entry.name] = intValue
        case "Bool":
            guard let boolValue = StateStore.parseBool(value) else {
                throw APSError.invalidValue(key: entry.name, value: value)
            }
            memoryBools[entry.name] = boolValue
        default:
            memoryStrings[entry.name] = value
        }
    }

    // MARK: - StoredState

    private static var userDefaults: any UserDefaultsManaging {
        Application.dependency(\Application.userDefaults)
    }

    private static func storedDefaultsKey(_ name: String) -> String {
        "aps.user.\(name)"
    }

    internal static func removeStoredValue(_ entry: SchemaKeyEntry) throws {
        try removeStoredValue(entry, from: userDefaults)
    }

    private static func removeStoredValue(
        _ entry: SchemaKeyEntry,
        from store: any UserDefaultsManaging
    ) throws {
        let canonicalKey = storedDefaultsKey(entry.name)
        let oldCanonical = store.object(forKey: canonicalKey)
        let oldLegacy = usesLegacyFlagStorage(entry) ? store.object(forKey: legacyFlagDefaultsKey) : nil

        do {
            store.removeObject(forKey: canonicalKey)
            if usesLegacyFlagStorage(entry) {
                store.removeObject(forKey: legacyFlagDefaultsKey)
            }
            guard synchronize(store),
                  store.object(forKey: canonicalKey) == nil,
                  !usesLegacyFlagStorage(entry) || store.object(forKey: legacyFlagDefaultsKey) == nil
            else {
                throw APSError.persistenceFailed(key: entry.name)
            }
        } catch {
            try restoreStoredObjects(
                canonical: oldCanonical,
                legacy: oldLegacy,
                entry: entry,
                in: store,
                after: error
            )
            throw error
        }
    }

    private static let legacyFlagDefaultsKey = "App/aps.flag"

    private static func usesLegacyFlagStorage(_ entry: SchemaKeyEntry) -> Bool {
        entry.name == "flag" && entry.type == "Bool" && entry.storage == "StoredState"
    }

    private static func storedObject(
        _ entry: SchemaKeyEntry,
        in store: any UserDefaultsManaging
    ) -> Any? {
        if let object = store.object(forKey: storedDefaultsKey(entry.name)) {
            return object
        }
        guard usesLegacyFlagStorage(entry) else { return nil }
        return store.object(forKey: legacyFlagDefaultsKey)
    }

    private static func decodeStoredInt(_ object: Any) -> Int? {
        if let data = object as? Data {
            return try? JSONDecoder().decode(Int.self, from: data)
        }
        if let intValue = object as? Int {
            return intValue
        }
        if let stringValue = object as? String {
            return Int(stringValue)
        }
        return nil
    }

    private static func decodeStoredBool(_ object: Any) -> Bool? {
        if let data = object as? Data {
            return try? JSONDecoder().decode(Bool.self, from: data)
        }
        if let boolValue = object as? Bool {
            return boolValue
        }
        if let stringValue = object as? String {
            return StateStore.parseBool(stringValue)
        }
        return nil
    }

    private static func decodeStoredString(_ object: Any) -> String? {
        if let data = object as? Data {
            return try? JSONDecoder().decode(String.self, from: data)
        }
        return object as? String
    }

    private static func storedGet(_ entry: SchemaKeyEntry) -> String {
        storedPersistedValue(entry, in: userDefaults)
            ?? entry.initial?.wireString
            ?? storedFallbackValue(entry)
    }

    private static func resetStoredValue(
        _ entry: SchemaKeyEntry,
        initial: String?,
        in store: any UserDefaultsManaging,
        afterReset: () throws -> Void
    ) throws {
        let canonicalKey = storedDefaultsKey(entry.name)
        let oldCanonical = store.object(forKey: canonicalKey)
        let oldLegacy = usesLegacyFlagStorage(entry) ? store.object(forKey: legacyFlagDefaultsKey) : nil

        do {
            store.removeObject(forKey: canonicalKey)
            if usesLegacyFlagStorage(entry) {
                store.removeObject(forKey: legacyFlagDefaultsKey)
            }
            if let initial {
                try storedSet(entry, value: initial, in: store)
            }
            guard synchronize(store),
                  storedPersistedValue(entry, in: store) == initial,
                  !usesLegacyFlagStorage(entry) || store.object(forKey: legacyFlagDefaultsKey) == nil
            else {
                throw APSError.persistenceFailed(key: entry.name)
            }
            try afterReset()
        } catch {
            try restoreStoredObjects(
                canonical: oldCanonical,
                legacy: oldLegacy,
                entry: entry,
                in: store,
                after: error
            )
            throw error
        }
    }

    private static func restoreStoredObjects(
        canonical: Any?,
        legacy: Any?,
        entry: SchemaKeyEntry,
        in store: any UserDefaultsManaging,
        after originalError: Error
    ) throws {
        let canonicalKey = storedDefaultsKey(entry.name)
        restoreStoredObject(canonical, forKey: canonicalKey, in: store)
        if usesLegacyFlagStorage(entry) {
            restoreStoredObject(legacy, forKey: legacyFlagDefaultsKey, in: store)
        }
        guard synchronize(store),
              storedObjectsEqual(store.object(forKey: canonicalKey), canonical),
              !usesLegacyFlagStorage(entry)
                || storedObjectsEqual(store.object(forKey: legacyFlagDefaultsKey), legacy)
        else {
            throw rollbackFailure(after: originalError, key: entry.name)
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

    private static func rollbackFailure(after originalError: Error, key: String) -> APSError {
        let failure = originalError as? APSError ?? .persistenceFailed(key: "StoredState")
        return .rollbackFailed(
            context: .storedState(key: key),
            originalErrorCode: failure.code,
            originalErrorDescription: failure.description
        )
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

    private static func storedFallbackValue(_ entry: SchemaKeyEntry) -> String {
        switch entry.type {
        case "Int": return "0"
        case "Bool": return "false"
        default: return ""
        }
    }

    private static func storedPersistedValue(
        _ entry: SchemaKeyEntry,
        in store: any UserDefaultsManaging
    ) -> String? {
        switch entry.type {
        case "Int":
            if let object = storedObject(entry, in: store), let intValue = decodeStoredInt(object) {
                return String(intValue)
            }
            return nil
        case "Bool":
            if let object = storedObject(entry, in: store), let boolValue = decodeStoredBool(object) {
                return boolValue ? "true" : "false"
            }
            return nil
        default:
            if let object = storedObject(entry, in: store), let stringValue = decodeStoredString(object) {
                return stringValue
            }
            return nil
        }
    }

    private static func storedSet(_ entry: SchemaKeyEntry, value: String) throws {
        try validateStoredValue(entry, value: value)
        let store = userDefaults
        let canonicalKey = storedDefaultsKey(entry.name)
        let oldCanonical = store.object(forKey: canonicalKey)
        let oldLegacy = usesLegacyFlagStorage(entry) ? store.object(forKey: legacyFlagDefaultsKey) : nil

        do {
            try storedSet(entry, value: value, in: store)
            guard
                synchronize(store),
                storedCanonicalValueMatches(entry, value: value, in: store)
            else {
                throw APSError.persistenceFailed(key: entry.name)
            }
        } catch {
            try restoreStoredObjects(
                canonical: oldCanonical,
                legacy: oldLegacy,
                entry: entry,
                in: store,
                after: error
            )
            throw error
        }
    }

    private static func validateStoredValue(_ entry: SchemaKeyEntry, value: String) throws {
        switch entry.type {
        case "Int":
            guard Int(value) != nil else {
                throw APSError.invalidValue(key: entry.name, value: value)
            }
        case "Bool":
            guard StateStore.parseBool(value) != nil else {
                throw APSError.invalidValue(key: entry.name, value: value)
            }
        default:
            break
        }
    }

    private static func storedCanonicalValueMatches(
        _ entry: SchemaKeyEntry,
        value: String,
        in store: any UserDefaultsManaging
    ) -> Bool {
        guard
            let object = store.object(forKey: storedDefaultsKey(entry.name)),
            JSONSerialization.isValidJSONObject([object]),
            let data = try? JSONSerialization.data(withJSONObject: [object])
        else {
            return false
        }
        switch entry.type {
        case "Int":
            guard
                let expected = Int(value),
                let persisted = try? JSONDecoder().decode([Int].self, from: data)
            else {
                return false
            }
            return persisted == [expected]
        case "Bool":
            guard
                let expected = StateStore.parseBool(value),
                let persisted = try? JSONDecoder().decode([Bool].self, from: data)
            else {
                return false
            }
            return persisted == [expected]
        default:
            guard let persisted = try? JSONDecoder().decode([String].self, from: data) else {
                return false
            }
            return persisted == [value]
        }
    }

    private static func storedSet(
        _ entry: SchemaKeyEntry,
        value: String,
        in store: any UserDefaultsManaging
    ) throws {
        let key = storedDefaultsKey(entry.name)
        switch entry.type {
        case "Int":
            guard let intValue = Int(value) else {
                throw APSError.invalidValue(key: entry.name, value: value)
            }
            store.set(intValue, forKey: key)
        case "Bool":
            guard let boolValue = StateStore.parseBool(value) else {
                throw APSError.invalidValue(key: entry.name, value: value)
            }
            store.set(boolValue, forKey: key)
        default:
            store.set(value, forKey: key)
        }
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

    // MARK: - FileState

    private static func storagePath(for entry: SchemaKeyEntry) throws -> SchemaStoragePath {
        guard let rawPath = entry.path else {
            throw APSError.schemaInvalid(
                reason: "\(entry.name) requires a safe relative path"
            )
        }
        return try SchemaStoragePath(rawPath)
    }

    private static func fileURL(_ entry: SchemaKeyEntry, stateRoot: String) throws -> URL {
        try storagePath(for: entry).resolve(stateRoot: stateRoot)
    }

    internal static func fileLockName(_ entry: SchemaKeyEntry) throws -> String {
        let path = try storagePath(for: entry)
        guard path.collisionKey.contains("/") else {
            return "\(path.collisionKey).lock"
        }
        let digest = SHA256.hash(data: Data(path.collisionKey.utf8))
        let digits = Array("0123456789abcdef".utf8)
        var encoded: [UInt8] = []
        encoded.reserveCapacity(SHA256.byteCount * 2)
        for byte in digest {
            encoded.append(digits[Int(byte >> 4)])
            encoded.append(digits[Int(byte & 0x0f)])
        }
        return "storage-\(String(decoding: encoded, as: UTF8.self)).lock"
    }

    private static func fileGet(
        _ entry: SchemaKeyEntry,
        stateRoot: String,
        operations: FileOperations = .live
    ) throws -> String {
        let url = try fileURL(entry, stateRoot: stateRoot)
        guard operations.fileExists(url) else {
            return entry.initial?.wireString ?? (entry.type == "object" ? "{}" : "")
        }
        let data: Data
        do {
            data = try operations.read(url)
        } catch {
            throw APSError.corruptState(key: entry.name)
        }
        guard
            let value = try? JSONDecoder().decode(SchemaJSON.self, from: data),
            value.matches(type: entry.type, objectShape: entry.objectShape)
        else {
            throw APSError.corruptState(key: entry.name)
        }
        return value.wireString
    }

    private static func fileSet(_ entry: SchemaKeyEntry, value: String, stateRoot: String) throws {
        try SchemaFileLock.withExclusiveStorageLock(
            stateRoot: stateRoot,
            lockFileName: try fileLockName(entry),
            resourceKey: entry.name
        ) {
            try fileSetUnlocked(entry, value: value, stateRoot: stateRoot)
        }
    }

    private static func fileSetUnlocked(
        _ entry: SchemaKeyEntry,
        value: String,
        stateRoot: String,
        operations: FileOperations = .live
    ) throws {
        let requested = try requestedValue(value, for: entry)
        let url = try fileURL(entry, stateRoot: stateRoot)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(requested)
        do {
            try operations.write(data, url)
        } catch {
            throw APSError.persistenceFailed(key: entry.name)
        }
    }

    private static func resetFileTransaction(
        entry: SchemaKeyEntry,
        stateRoot: String,
        operations: FileOperations,
        mutation: () throws -> Void
    ) throws {
        let url = try fileURL(entry, stateRoot: stateRoot)
        let snapshot = try fileSnapshot(at: url, operations: operations, key: entry.name)
        do {
            try mutation()
        } catch {
            let originalError = error
            do {
                try restoreFileSnapshot(
                    snapshot,
                    entry: entry,
                    stateRoot: stateRoot,
                    operations: operations
                )
            } catch {
                let failure = originalError as? APSError ?? .persistenceFailed(key: entry.name)
                throw APSError.rollbackFailed(
                    context: .fileState(path: entry.path ?? entry.name),
                    originalErrorCode: failure.code,
                    originalErrorDescription: failure.description
                )
            }
            throw originalError
        }
    }

    private static func fileSnapshot(
        at url: URL,
        operations: FileOperations,
        key: String
    ) throws -> FileSnapshot {
        guard operations.fileExists(url) else { return .absent }
        do {
            return .present(try operations.read(url))
        } catch {
            throw APSError.persistenceFailed(key: key)
        }
    }

    private static func restoreFileSnapshot(
        _ snapshot: FileSnapshot,
        entry: SchemaKeyEntry,
        stateRoot: String,
        operations: FileOperations
    ) throws {
        let key = entry.name
        let url = try fileURL(entry, stateRoot: stateRoot)
        do {
            switch snapshot {
            case .absent:
                if operations.fileExists(url) {
                    let checkedURL = try storagePath(for: entry).resolve(stateRoot: stateRoot)
                    guard checkedURL == url else {
                        throw APSError.persistenceFailed(key: key)
                    }
                    try operations.remove(checkedURL)
                }
            case .present(let data):
                try operations.write(data, url)
            }
        } catch {
            throw APSError.persistenceFailed(key: key)
        }
        guard try fileSnapshot(at: url, operations: operations, key: key) == snapshot else {
            throw APSError.persistenceFailed(key: key)
        }
    }

    // MARK: - EncryptedFile

    private static func encryptedGet(_ entry: SchemaKeyEntry, stateRoot: String) throws -> String {
        let store = try encryptedStore(entry, stateRoot: stateRoot)
        return store.hasSecret ? try store.get() : (entry.initial?.wireString ?? "")
    }

    private static func encryptedSet(_ entry: SchemaKeyEntry, value: String, stateRoot: String) throws {
        let store = try encryptedStore(entry, stateRoot: stateRoot)
        try store.set(value)
    }

    internal static func encryptedStore(
        _ entry: SchemaKeyEntry,
        stateRoot: String
    ) throws -> SecretStore {
        let path = try storagePath(for: entry)
        _ = try path.resolve(stateRoot: stateRoot)
        return SecretStore(
            directory: stateRoot,
            storeFileName: path.rawValue,
            keyName: entry.name
        )
    }

    // MARK: - Slice

    private static func sliceGet(
        entry: SchemaKeyEntry,
        stateRoot: String,
        schema: UserSchemaDocument
    ) throws -> String {
        let parent = try sliceParent(entry: entry, schema: schema)
        return try sliceGetUnlocked(entry: entry, parent: parent, stateRoot: stateRoot)
    }

    private static func sliceGetUnlocked(
        entry: SchemaKeyEntry,
        parent: SchemaKeyEntry,
        stateRoot: String,
        operations: FileOperations = .live
    ) throws -> String {
        guard let parentName = entry.sliceOf, let field = entry.sliceField else {
            throw APSError.schemaInvalid(reason: "slice \(entry.name) missing parent")
        }
        let declaredType = try sliceFieldType(entry: entry, parent: parent)
        let raw = try fileGet(parent, stateRoot: stateRoot, operations: operations)
        guard
            let data = raw.data(using: .utf8),
            let parentValue = try? JSONDecoder().decode(SchemaJSON.self, from: data),
            case .object(let object) = parentValue
        else {
            throw APSError.corruptState(key: parentName)
        }
        guard let value = object[field] else {
            return entry.initial?.wireString ?? ""
        }
        guard value.matches(type: declaredType, objectShape: entry.objectShape) else {
            throw APSError.corruptState(key: parentName)
        }
        return value.wireString
    }

    private static func sliceSet(
        entry: SchemaKeyEntry,
        value: String,
        stateRoot: String,
        schema: UserSchemaDocument
    ) throws {
        let parent = try sliceParent(entry: entry, schema: schema)
        try SchemaFileLock.withExclusiveStorageLock(
            stateRoot: stateRoot,
            lockFileName: try fileLockName(parent),
            resourceKey: entry.name
        ) {
            try sliceSetUnlocked(entry: entry, parent: parent, value: value, stateRoot: stateRoot)
        }
    }

    private static func sliceParent(
        entry: SchemaKeyEntry,
        schema: UserSchemaDocument
    ) throws -> SchemaKeyEntry {
        guard
            let parentName = entry.sliceOf,
            let parent = UserSchema.entry(named: parentName, in: schema),
            parent.type == "object",
            parent.storage == "FileState"
        else {
            throw APSError.schemaInvalid(
                reason: "slice \(entry.name) requires a FileState object parent"
            )
        }
        return parent
    }

    private static func sliceFieldType(
        entry: SchemaKeyEntry,
        parent: SchemaKeyEntry
    ) throws -> String {
        guard
            let field = entry.sliceField,
            let declaredType = parent.objectShape?[field],
            declaredType == entry.type
        else {
            throw APSError.schemaInvalid(
                reason: "slice \(entry.name) field must be explicitly declared as \(entry.type)"
            )
        }
        return declaredType
    }

    private static func sliceSetUnlocked(
        entry: SchemaKeyEntry,
        parent: SchemaKeyEntry,
        value: String,
        stateRoot: String,
        operations: FileOperations = .live
    ) throws {
        guard let parentName = entry.sliceOf, let field = entry.sliceField else {
            throw APSError.schemaInvalid(reason: "slice \(entry.name) missing parent")
        }
        let declaredType = try sliceFieldType(entry: entry, parent: parent)
        let requested = try requestedValue(value, for: entry)
        let raw = try fileGet(parent, stateRoot: stateRoot, operations: operations)
        guard let inputData = raw.data(using: .utf8) else {
            throw APSError.corruptState(key: parentName)
        }
        guard
            let parentValue = try? JSONDecoder().decode(SchemaJSON.self, from: inputData),
            case .object(var object) = parentValue
        else {
            throw APSError.corruptState(key: parentName)
        }
        guard requested.matches(type: declaredType, objectShape: entry.objectShape) else {
            throw APSError.invalidValue(key: entry.name, value: value)
        }
        object[field] = requested
        let updatedParent = SchemaJSON.object(object)
        guard updatedParent.matches(type: parent.type, objectShape: parent.objectShape) else {
            throw APSError.corruptState(key: parentName)
        }
        let encoded = updatedParent.wireString
        try fileSetUnlocked(parent, value: encoded, stateRoot: stateRoot, operations: operations)
    }
}
