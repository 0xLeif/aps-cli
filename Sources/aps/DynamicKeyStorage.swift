import Foundation
import AppState
import Crypto

internal protocol UserDefaultsSynchronizing: UserDefaultsManaging {
    func synchronize() -> Bool
}

/// Process-local and file-backed storage for user-defined schema keys.
@MainActor
enum DynamicKeyStorage {
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
        switch entry.storage {
        case "State":
            return memoryGet(entry)
        case "StoredState":
            return storedGet(entry)
        case "FileState":
            return try fileGet(entry, stateRoot: stateRoot)
        case "EncryptedFile":
            return try encryptedGet(entry, stateRoot: stateRoot)
        case "Slice":
            return try sliceGet(entry: entry, stateRoot: stateRoot, schema: schema)
        default:
            throw APSError.schemaInvalid(reason: "unsupported storage \(entry.storage)")
        }
    }

    static func set(
        entry: SchemaKeyEntry,
        value: String,
        stateRoot: String,
        schema: UserSchemaDocument
    ) throws {
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
        schema: UserSchemaDocument
    ) throws -> ResetOutcome {
        let initial = entry.initial?.wireString ?? ""
        switch entry.storage {
        case "State":
            memoryStrings.removeValue(forKey: entry.name)
            memoryInts.removeValue(forKey: entry.name)
            memoryBools.removeValue(forKey: entry.name)
            if entry.initial != nil {
                try memorySet(entry, value: initial)
            }
        case "StoredState":
            let store = userDefaults
            try resetStoredValue(entry, initial: entry.initial == nil ? nil : initial, in: store)
        case "FileState":
            if entry.initial != nil {
                try SchemaFileLock.withExclusiveStorageLock(
                    stateRoot: stateRoot,
                    lockFileName: try fileLockName(entry)
                ) {
                    try fileSetUnlocked(entry, value: initial, stateRoot: stateRoot)
                    guard try fileGet(entry, stateRoot: stateRoot) == initial else {
                        throw APSError.persistenceFailed(key: entry.name)
                    }
                }
            } else {
                _ = try SchemaFileLock.withExclusiveStorageLock(
                    stateRoot: stateRoot,
                    lockFileName: try fileLockName(entry)
                ) {
                    try storagePath(for: entry).removeRegularFileIfPresent(stateRoot: stateRoot)
                }
            }
        case "EncryptedFile":
            _ = try encryptedStore(entry, stateRoot: stateRoot).reset()
        case "Slice":
            let parent = try sliceParent(entry: entry, schema: schema)
            try SchemaFileLock.withExclusiveStorageLock(
                stateRoot: stateRoot,
                lockFileName: try fileLockName(parent)
            ) {
                try sliceSetUnlocked(
                    entry: entry,
                    parent: parent,
                    value: initial,
                    stateRoot: stateRoot
                )
                guard try sliceGetUnlocked(entry: entry, parent: parent, stateRoot: stateRoot) == initial else {
                    throw APSError.persistenceFailed(key: entry.name)
                }
            }
        default:
            throw APSError.schemaInvalid(reason: "unsupported storage \(entry.storage)")
        }
        return ResetOutcome(key: entry.name)
    }

    static func purge(entry: SchemaKeyEntry, stateRoot: String) throws {
        switch entry.storage {
        case "FileState":
            _ = try SchemaFileLock.withExclusiveStorageLock(
                stateRoot: stateRoot,
                lockFileName: try fileLockName(entry)
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
            let url = try fileURL(entry, stateRoot: stateRoot)
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            _ = try Data(contentsOf: url)
            // Presence is enough; typed decode happens on get.
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
        in store: any UserDefaultsManaging
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
        let store = userDefaults
        try storedSet(entry, value: value, in: store)
        guard synchronize(store) else {
            throw APSError.persistenceFailed(key: entry.name)
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

    private static func fileGet(_ entry: SchemaKeyEntry, stateRoot: String) throws -> String {
        let url = try fileURL(entry, stateRoot: stateRoot)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return entry.initial?.wireString ?? (entry.type == "object" ? "{}" : "")
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw APSError.corruptState(key: entry.name)
        }
        if entry.type == "String" {
            do {
                return try JSONDecoder().decode(String.self, from: data)
            } catch {
                throw APSError.corruptState(key: entry.name)
            }
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw APSError.corruptState(key: entry.name)
        }
        return string
    }

    private static func fileSet(_ entry: SchemaKeyEntry, value: String, stateRoot: String) throws {
        try SchemaFileLock.withExclusiveStorageLock(
            stateRoot: stateRoot,
            lockFileName: try fileLockName(entry)
        ) {
            try fileSetUnlocked(entry, value: value, stateRoot: stateRoot)
        }
    }

    private static func fileSetUnlocked(_ entry: SchemaKeyEntry, value: String, stateRoot: String) throws {
        let url = try fileURL(entry, stateRoot: stateRoot)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data: Data
        if entry.type == "String" {
            data = try JSONEncoder().encode(value)
        } else if entry.type == "object" {
            guard let valueData = value.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: valueData)) != nil
            else {
                throw APSError.invalidValue(key: entry.name, value: value)
            }
            data = valueData
        } else if entry.type == "Int" {
            guard let intValue = Int(value) else {
                throw APSError.invalidValue(key: entry.name, value: value)
            }
            data = try JSONEncoder().encode(intValue)
        } else if entry.type == "Bool" {
            guard let boolValue = StateStore.parseBool(value) else {
                throw APSError.invalidValue(key: entry.name, value: value)
            }
            data = try JSONEncoder().encode(boolValue)
        } else {
            throw APSError.invalidValue(key: entry.name, value: value)
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw APSError.persistenceFailed(key: entry.name)
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

    private static func encryptedStore(
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
        stateRoot: String
    ) throws -> String {
        guard let parentName = entry.sliceOf, let field = entry.sliceField else {
            throw APSError.schemaInvalid(reason: "slice \(entry.name) missing parent")
        }
        let raw = try fileGet(parent, stateRoot: stateRoot)
        guard
            let data = raw.data(using: .utf8),
            let object = try? JSONDecoder().decode([String: SchemaJSON].self, from: data)
        else {
            throw APSError.corruptState(key: parentName)
        }
        guard let value = object[field] else {
            return entry.initial?.wireString ?? ""
        }
        let declaredType = parent.objectShape?[field] ?? entry.type
        switch (declaredType, value) {
        case ("String", .string(let stringValue)):
            return stringValue
        case ("Int", .int(let intValue)):
            return String(intValue)
        case ("Bool", .bool(let boolValue)):
            return boolValue ? "true" : "false"
        case ("object", .object):
            return value.wireString
        default:
            throw APSError.corruptState(key: parentName)
        }
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
            lockFileName: try fileLockName(parent)
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
            let parent = UserSchema.entry(named: parentName, in: schema)
        else {
            throw APSError.schemaInvalid(reason: "slice \(entry.name) missing parent")
        }
        return parent
    }

    private static func sliceSetUnlocked(
        entry: SchemaKeyEntry,
        parent: SchemaKeyEntry,
        value: String,
        stateRoot: String
    ) throws {
        guard let parentName = entry.sliceOf, let field = entry.sliceField else {
            throw APSError.schemaInvalid(reason: "slice \(entry.name) missing parent")
        }
        let raw = try fileGet(parent, stateRoot: stateRoot)
        guard let inputData = raw.data(using: .utf8) else {
            throw APSError.corruptState(key: parentName)
        }
        let objectValue: Any
        do {
            objectValue = try JSONSerialization.jsonObject(with: inputData)
        } catch {
            throw APSError.corruptState(key: parentName)
        }
        guard var object = objectValue as? [String: Any] else {
            throw APSError.corruptState(key: parentName)
        }
        if let shape = parent.objectShape?[field] {
            switch shape {
            case "Int":
                guard let intValue = Int(value) else {
                    throw APSError.invalidValue(key: entry.name, value: value)
                }
                object[field] = intValue
            case "Bool":
                guard let boolValue = StateStore.parseBool(value) else {
                    throw APSError.invalidValue(key: entry.name, value: value)
                }
                object[field] = boolValue
            default:
                object[field] = value
            }
        } else {
            object[field] = value
        }
        // Avoid `.sortedKeys`: not available on all Linux Foundation builds we smoke.
        let outputData = try JSONSerialization.data(withJSONObject: object)
        guard let encoded = String(data: outputData, encoding: .utf8) else {
            throw APSError.encodingFailed
        }
        try fileSetUnlocked(parent, value: encoded, stateRoot: stateRoot)
    }
}
