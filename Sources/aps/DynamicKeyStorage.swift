import AppState
import Foundation

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

    static func reset(entry: SchemaKeyEntry, stateRoot: String, schema: UserSchemaDocument) throws {
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
            store.removeObject(forKey: storedDefaultsKey(entry.name))
            (store as? UserDefaults)?.synchronize()
            UserDefaults.standard.synchronize()
            if entry.initial != nil {
                try storedSet(entry, value: initial)
            }
        case "FileState":
            let url = fileURL(entry, stateRoot: stateRoot)
            try? FileManager.default.removeItem(at: url)
            if entry.initial != nil {
                try fileSet(entry, value: initial, stateRoot: stateRoot)
            }
        case "EncryptedFile":
            let store = SecretStore(
                directory: stateRoot,
                storeFileName: entry.path ?? "\(entry.name).enc",
                keyName: entry.name
            )
            store.reset()
        case "Slice":
            try sliceSet(entry: entry, value: initial, stateRoot: stateRoot, schema: schema)
        default:
            throw APSError.schemaInvalid(reason: "unsupported storage \(entry.storage)")
        }
    }

    static func requireDecodable(entry: SchemaKeyEntry, stateRoot: String) throws {
        switch entry.storage {
        case "FileState":
            let url = fileURL(entry, stateRoot: stateRoot)
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            _ = try Data(contentsOf: url)
            // Presence is enough; typed decode happens on get.
        case "EncryptedFile":
            let store = SecretStore(
                directory: stateRoot,
                storeFileName: entry.path ?? "\(entry.name).enc",
                keyName: entry.name
            )
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

    private static func storedGet(_ entry: SchemaKeyEntry) -> String {
        let key = storedDefaultsKey(entry.name)
        let store = userDefaults
        switch entry.type {
        case "Int":
            if let object = store.object(forKey: key) {
                if let intValue = object as? Int { return String(intValue) }
                if let strValue = object as? String, let intValue = Int(strValue) { return String(intValue) }
            }
            return entry.initial?.wireString ?? "0"
        case "Bool":
            if let object = store.object(forKey: key) {
                if let boolValue = object as? Bool { return boolValue ? "true" : "false" }
                if let strValue = object as? String, let boolValue = StateStore.parseBool(strValue) { return boolValue ? "true" : "false" }
            }
            return entry.initial?.wireString ?? "false"
        default:
            if let object = store.object(forKey: key) as? String {
                return object
            }
            return entry.initial?.wireString ?? ""
        }
    }

    private static func storedSet(_ entry: SchemaKeyEntry, value: String) throws {
        let key = storedDefaultsKey(entry.name)
        let store = userDefaults
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
        (store as? UserDefaults)?.synchronize()
        UserDefaults.standard.synchronize()
    }

    // MARK: - FileState

    private static func fileURL(_ entry: SchemaKeyEntry, stateRoot: String) -> URL {
        URL(fileURLWithPath: stateRoot).appendingPathComponent(entry.path ?? "\(entry.name).json")
    }

    private static func fileLockName(_ entry: SchemaKeyEntry) -> String {
        let filename = URL(fileURLWithPath: entry.path ?? "\(entry.name).json").lastPathComponent
        return "\(filename).lock"
    }

    private static func fileGet(_ entry: SchemaKeyEntry, stateRoot: String) throws -> String {
        let url = fileURL(entry, stateRoot: stateRoot)
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
        try SchemaFileLock.withExclusiveLock(
            stateRoot: stateRoot,
            lockFileName: fileLockName(entry)
        ) {
            try fileSetUnlocked(entry, value: value, stateRoot: stateRoot)
        }
    }

    private static func fileSetUnlocked(_ entry: SchemaKeyEntry, value: String, stateRoot: String) throws {
        let url = fileURL(entry, stateRoot: stateRoot)
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
        let store = SecretStore(
            directory: stateRoot,
            storeFileName: entry.path ?? "\(entry.name).enc",
            keyName: entry.name
        )
        return store.hasSecret ? try store.get() : (entry.initial?.wireString ?? "")
    }

    private static func encryptedSet(_ entry: SchemaKeyEntry, value: String, stateRoot: String) throws {
        let store = SecretStore(
            directory: stateRoot,
            storeFileName: entry.path ?? "\(entry.name).enc",
            keyName: entry.name
        )
        try store.set(value)
    }

    // MARK: - Slice

    private static func sliceGet(
        entry: SchemaKeyEntry,
        stateRoot: String,
        schema: UserSchemaDocument
    ) throws -> String {
        guard
            let parentName = entry.sliceOf,
            let field = entry.sliceField,
            let parent = UserSchema.entry(named: parentName, in: schema)
        else {
            throw APSError.schemaInvalid(reason: "slice \(entry.name) missing parent")
        }
        let raw = try fileGet(parent, stateRoot: stateRoot)
        guard let data = raw.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw APSError.corruptState(key: parentName)
        }
        guard let value = object[field] else {
            return entry.initial?.wireString ?? ""
        }
        if let string = value as? String { return string }
        if let intValue = value as? Int { return String(intValue) }
        if let boolValue = value as? Bool { return boolValue ? "true" : "false" }
        return "\(value)"
    }

    private static func sliceSet(
        entry: SchemaKeyEntry,
        value: String,
        stateRoot: String,
        schema: UserSchemaDocument
    ) throws {
        guard
            let parentName = entry.sliceOf,
            let field = entry.sliceField,
            let parent = UserSchema.entry(named: parentName, in: schema)
        else {
            throw APSError.schemaInvalid(reason: "slice \(entry.name) missing parent")
        }
        try SchemaFileLock.withExclusiveLock(
            stateRoot: stateRoot,
            lockFileName: fileLockName(parent)
        ) {
            let raw = try fileGet(parent, stateRoot: stateRoot)
            var object: [String: Any]
            if let data = raw.data(using: .utf8),
               let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                object = parsed
            } else {
                object = [:]
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
            let data = try JSONSerialization.data(withJSONObject: object)
            guard let encoded = String(data: data, encoding: .utf8) else {
                throw APSError.encodingFailed
            }
            try fileSetUnlocked(parent, value: encoded, stateRoot: stateRoot)
        }
    }
}
