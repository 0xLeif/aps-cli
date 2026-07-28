import Crypto
import Foundation

/// On-disk user schema (`<state-root>/schema.json`) per RFC `docs/design/dynamic-schema.md`.
public struct UserSchemaDocument: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var namespace: String
    public var keys: [SchemaKeyEntry]

    public init(formatVersion: Int = 1, namespace: String = "default", keys: [SchemaKeyEntry]) {
        self.formatVersion = formatVersion
        self.namespace = namespace
        self.keys = keys
    }
}

/// One registry entry in `schema.json`.
public struct SchemaKeyEntry: Codable, Equatable, Sendable {
    public var name: String
    public var type: String
    public var storage: String
    public var initial: SchemaJSON?
    public var path: String?
    public var doc: String?
    public var objectShape: [String: String]?
    public var sliceOf: String?
    public var sliceField: String?

    public init(
        name: String,
        type: String,
        storage: String,
        initial: SchemaJSON? = nil,
        path: String? = nil,
        doc: String? = nil,
        objectShape: [String: String]? = nil,
        sliceOf: String? = nil,
        sliceField: String? = nil
    ) {
        self.name = name
        self.type = type
        self.storage = storage
        self.initial = initial
        self.path = path
        self.doc = doc
        self.objectShape = objectShape
        self.sliceOf = sliceOf
        self.sliceField = sliceField
    }

    public var detail: String {
        doc ?? "\(type) via \(storage)"
    }

    public var lifetime: String {
        switch storage {
        case "State":
            return "process"
        case "Slice":
            return "persisted (slice)"
        default:
            return "persisted"
        }
    }
}

/// Recursive structural JSON value shared by `schema.json` and machine-readable CLI payloads.
///
/// Equivalent integral number spellings may canonicalize to `int` after Codable decoding.
public enum SchemaJSON: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    indirect case array([SchemaJSON])
    indirect case object([String: SchemaJSON])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self), value.isFinite {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([SchemaJSON].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: SchemaJSON].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unsupported schema JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            guard value.isFinite else {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: encoder.codingPath,
                        debugDescription: "JSON numbers must be finite"
                    )
                )
            }
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    /// Wire string used by CLI set/reset. Structured values use stable key ordering.
    public var wireString: String {
        switch self {
        case .null:
            return "null"
        case .bool(let value):
            return value ? "true" : "false"
        case .int(let value):
            return String(value)
        case .double(let value):
            return value.isFinite ? String(value) : "null"
        case .string(let value):
            return value
        case .array, .object:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            if let data = try? encoder.encode(self),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
            return "null"
        }
    }

    /// Parses a CLI wire value while requiring the declared top-level JSON kind.
    public static func parse(_ raw: String, as type: String) -> SchemaJSON? {
        let value: SchemaJSON?
        switch type {
        case "String":
            value = .string(raw)
        case "Int":
            value = Int(raw).map(SchemaJSON.int)
        case "Bool":
            switch raw.lowercased() {
            case "true", "1", "yes", "on":
                value = .bool(true)
            case "false", "0", "no", "off":
                value = .bool(false)
            default:
                value = nil
            }
        case "Double":
            if let parsed = Double(raw), parsed.isFinite {
                value = .double(parsed)
            } else {
                value = nil
            }
        case "null", "array", "object":
            guard let data = raw.data(using: .utf8) else {
                return nil
            }
            value = try? JSONDecoder().decode(SchemaJSON.self, from: data)
        default:
            value = nil
        }
        guard let value, value.matches(type: type, objectShape: nil) else {
            return nil
        }
        return value
    }

    /// Returns the conventional empty initial for a declared aps value type.
    public static func defaultValue(for type: String) -> SchemaJSON? {
        switch type {
        case "null":
            return .null
        case "Bool":
            return .bool(false)
        case "Int":
            return .int(0)
        case "Double":
            return .double(0)
        case "String":
            return .string("")
        case "array":
            return .array([])
        case "object":
            return .object([:])
        default:
            return nil
        }
    }

    /// Returns whether the value has the declared type and satisfies an open object shape.
    ///
    /// Declared fields are required and recursively type-checked. Undeclared fields are preserved.
    public func matches(type: String, objectShape: [String: String]? = nil) -> Bool {
        guard containsOnlyFiniteNumbers else {
            return false
        }
        switch (type, self) {
        case ("null", .null), ("Bool", .bool), ("Int", .int), ("String", .string):
            return true
        case ("Double", .double(let value)):
            return value.isFinite
        case ("array", .array):
            return true
        case ("object", .object(let object)):
            guard let objectShape else {
                return true
            }
            return objectShape.allSatisfy { field, fieldType in
                guard let value = object[field] else {
                    return false
                }
                return value.matches(type: fieldType)
            }
        default:
            return false
        }
    }

    private var containsOnlyFiniteNumbers: Bool {
        switch self {
        case .double(let value):
            return value.isFinite
        case .array(let values):
            return values.allSatisfy(\.containsOnlyFiniteNumbers)
        case .object(let object):
            return object.values.allSatisfy(\.containsOnlyFiniteNumbers)
        case .null, .bool, .int, .string:
            return true
        }
    }
}

/// Load, materialize, validate, and write `schema.json`.
public enum UserSchema {
    public static let fileName = "schema.json"
    public static let currentFormatVersion = 1
    public static let namePattern = #"^[A-Za-z][A-Za-z0-9_]*$"#

    public static let allowedTypes: Set<String> = ["Int", "String", "Bool", "object"]
    public static let allowedStorage: Set<String> = [
        "State", "StoredState", "FileState", "EncryptedFile", "Slice"
    ]

    /// Built-in demo keys shipped as the default schema contents.
    public static func defaultDocument() -> UserSchemaDocument {
        UserSchemaDocument(keys: [
            SchemaKeyEntry(
                name: "counter",
                type: "Int",
                storage: "State",
                initial: .int(0),
                doc: "in-memory Int counter (process lifetime)"
            ),
            SchemaKeyEntry(
                name: "message",
                type: "String",
                storage: "State",
                initial: .string(""),
                doc: "in-memory String (process lifetime)"
            ),
            SchemaKeyEntry(
                name: "flag",
                type: "Bool",
                storage: "StoredState",
                initial: .bool(false),
                doc: "Bool via StoredState / UserDefaults"
            ),
            SchemaKeyEntry(
                name: "note",
                type: "String",
                storage: "FileState",
                initial: .string(""),
                path: "note.json",
                doc: "String via FileState"
            ),
            SchemaKeyEntry(
                name: "profile",
                type: "object",
                storage: "FileState",
                initial: .object(["name": .string(""), "version": .int(0)]),
                path: "profile.json",
                doc: "structured profile document",
                objectShape: ["name": "String", "version": "Int"]
            ),
            SchemaKeyEntry(
                name: "secret",
                type: "String",
                storage: "EncryptedFile",
                initial: .string(""),
                path: "secret.enc",
                doc: "encrypted string under the state root"
            ),
            SchemaKeyEntry(
                name: "profileName",
                type: "String",
                storage: "Slice",
                initial: .string(""),
                doc: "projection of profile.name",
                sliceOf: "profile",
                sliceField: "name"
            ),
        ])
    }

    public static func schemaURL(stateRoot: String) -> URL {
        URL(fileURLWithPath: stateRoot).appendingPathComponent(fileName)
    }

    /// Load schema.json or materialize the default document when missing.
    ///
    /// Materialize races with peer `key add` are serialized via `SchemaFileLock`.
    @MainActor
    public static func loadOrMaterialize(stateRoot: String) throws -> UserSchemaDocument {
        let url = schemaURL(stateRoot: stateRoot)
        if FileManager.default.fileExists(atPath: url.path) {
            return try load(from: url)
        }
        return try SchemaFileLock.withExclusiveLock(stateRoot: stateRoot) {
            if FileManager.default.fileExists(atPath: url.path) {
                return try load(from: url)
            }
            let document = defaultDocument()
            try write(document, to: url)
            return document
        }
    }

    /// Load without taking the schema lock (caller already holds it).
    public static func loadUnlocked(stateRoot: String) throws -> UserSchemaDocument {
        try load(from: schemaURL(stateRoot: stateRoot))
    }

    /// Load or materialize without taking the schema lock (caller already holds it).
    public static func loadOrMaterializeUnlocked(stateRoot: String) throws -> UserSchemaDocument {
        let url = schemaURL(stateRoot: stateRoot)
        if FileManager.default.fileExists(atPath: url.path) {
            return try load(from: url)
        }
        let document = defaultDocument()
        try write(document, to: url)
        return document
    }

    public static func load(from url: URL) throws -> UserSchemaDocument {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw APSError.schemaInvalid(reason: "could not read \(fileName)")
        }
        let document: UserSchemaDocument
        do {
            document = try JSONDecoder().decode(UserSchemaDocument.self, from: data)
        } catch {
            throw APSError.schemaInvalid(reason: "undecodable \(fileName)")
        }
        try validate(document, stateRoot: url.deletingLastPathComponent().path)
        return document
    }

    public static func write(_ document: UserSchemaDocument, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try validate(document, stateRoot: directory.path)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document)
            try data.write(to: url, options: .atomic)
        } catch let error as APSError {
            throw error
        } catch {
            throw APSError.persistenceFailed(key: fileName)
        }
    }

    @MainActor
    public static func write(_ document: UserSchemaDocument, stateRoot: String) throws {
        try write(document, to: schemaURL(stateRoot: stateRoot))
    }

    public static func validate(_ document: UserSchemaDocument) throws {
        guard document.formatVersion == currentFormatVersion else {
            throw APSError.schemaInvalid(
                reason: "unsupported formatVersion \(document.formatVersion)"
            )
        }
        var seen = Set<String>()
        var storagePaths: [SchemaStoragePath] = []
        let nameRegex = try? NSRegularExpression(pattern: namePattern)
        for entry in document.keys {
            if seen.contains(entry.name) {
                throw APSError.schemaInvalid(reason: "duplicate key '\(entry.name)'")
            }
            seen.insert(entry.name)
            let range = NSRange(entry.name.startIndex..., in: entry.name)
            guard
                let nameRegex,
                nameRegex.firstMatch(in: entry.name, range: range) != nil
            else {
                throw APSError.schemaInvalid(reason: "invalid key name '\(entry.name)'")
            }
            guard allowedTypes.contains(entry.type) else {
                throw APSError.schemaInvalid(reason: "unsupported type '\(entry.type)' for \(entry.name)")
            }
            guard allowedStorage.contains(entry.storage) else {
                throw APSError.schemaInvalid(
                    reason: "unsupported storage '\(entry.storage)' for \(entry.name)"
                )
            }
            guard let initial = entry.initial else {
                throw APSError.schemaInvalid(reason: "\(entry.name) requires initial")
            }
            try validateObjectShape(entry.objectShape, for: entry)
            try validate(
                initial,
                declaredType: entry.type,
                objectShape: entry.objectShape,
                key: entry.name
            )
            if entry.storage == "Slice", entry.path != nil {
                throw APSError.schemaInvalid(
                    reason: "\(entry.name) Slice cannot declare path"
                )
            }
            if entry.storage != "Slice", entry.sliceOf != nil || entry.sliceField != nil {
                throw APSError.schemaInvalid(
                    reason: "\(entry.name) sliceOf and sliceField require Slice storage"
                )
            }
            if entry.storage == "FileState" || entry.storage == "EncryptedFile" {
                guard let path = entry.path else {
                    throw APSError.schemaInvalid(
                        reason: "\(entry.name) requires a safe relative path"
                    )
                }
                let storagePath = try SchemaStoragePath(path)
                guard !storagePaths.contains(where: { $0.collides(with: storagePath) }) else {
                    throw APSError.schemaInvalid(
                        reason: "\(entry.name) path '\(path)' collides with another key"
                    )
                }
                storagePaths.append(storagePath)
            }
        }

        for entry in document.keys where entry.storage == "Slice" {
            try validateSlice(entry, in: document)
        }
    }

    /// Validates a JSON value against a declared aps type and an optional open object shape.
    ///
    /// Shape fields are required and type-checked. Additional object fields are preserved.
    public static func validate(
        _ value: SchemaJSON,
        declaredType: String,
        objectShape: [String: String]? = nil,
        key: String
    ) throws {
        guard value.matches(type: declaredType) else {
            throw APSError.schemaInvalid(
                reason: "\(key) value must match declared type '\(declaredType)'"
            )
        }
        guard case .object(let object) = value, let objectShape else {
            return
        }
        for field in objectShape.keys.sorted() {
            guard let fieldType = objectShape[field], let fieldValue = object[field] else {
                throw APSError.schemaInvalid(
                    reason: "\(key) object initial requires field '\(field)'"
                )
            }
            try validate(
                fieldValue,
                declaredType: fieldType,
                key: "\(key).\(field)"
            )
        }
    }

    private static func validateObjectShape(
        _ objectShape: [String: String]?,
        for entry: SchemaKeyEntry
    ) throws {
        if entry.type == "object" {
            guard let objectShape else {
                throw APSError.schemaInvalid(
                    reason: "\(entry.name) object type requires objectShape"
                )
            }
            let fieldRegex = try? NSRegularExpression(pattern: namePattern)
            for (field, fieldType) in objectShape {
                let range = NSRange(field.startIndex..., in: field)
                guard
                    let fieldRegex,
                    fieldRegex.firstMatch(in: field, range: range) != nil
                else {
                    throw APSError.schemaInvalid(
                        reason: "\(entry.name) objectShape contains invalid field '\(field)'"
                    )
                }
                guard allowedTypes.contains(fieldType) else {
                    throw APSError.schemaInvalid(
                        reason: "\(entry.name).\(field) has unsupported type '\(fieldType)'"
                    )
                }
            }
        } else if objectShape != nil {
            throw APSError.schemaInvalid(
                reason: "\(entry.name) objectShape requires object type"
            )
        }
    }

    private static func validateSlice(
        _ entry: SchemaKeyEntry,
        in document: UserSchemaDocument
    ) throws {
        guard let parentName = entry.sliceOf, let field = entry.sliceField, !field.isEmpty else {
            throw APSError.schemaInvalid(
                reason: "\(entry.name) Slice requires sliceOf and sliceField"
            )
        }
        guard
            let parent = Self.entry(named: parentName, in: document),
            parent.type == "object",
            parent.storage == "FileState"
        else {
            throw APSError.schemaInvalid(
                reason: "\(entry.name) sliceOf '\(parentName)' must be a FileState object"
            )
        }
        guard let fieldType = parent.objectShape?[field] else {
            throw APSError.schemaInvalid(
                reason: "\(entry.name) sliceField '\(field)' must be declared by \(parentName).objectShape"
            )
        }
        guard fieldType == entry.type else {
            throw APSError.schemaInvalid(
                reason: "\(entry.name) type '\(entry.type)' must match \(parentName).\(field) type '\(fieldType)'"
            )
        }
        guard let initial = entry.initial else {
            throw APSError.schemaInvalid(reason: "\(entry.name) requires initial")
        }
        try validate(
            initial,
            declaredType: fieldType,
            objectShape: entry.objectShape,
            key: entry.name
        )
    }

    public static func isSafeRelativePath(_ path: String) -> Bool {
        (try? SchemaStoragePath(path)) != nil
    }

    /// Validate the complete schema plus current filesystem path shapes.
    public static func validate(_ document: UserSchemaDocument, stateRoot: String) throws {
        try validate(document)
        for entry in document.keys
            where entry.storage == "FileState" || entry.storage == "EncryptedFile" {
            guard let rawPath = entry.path else {
                throw APSError.schemaInvalid(
                    reason: "\(entry.name) requires a safe relative path"
                )
            }
            _ = try SchemaStoragePath(rawPath).resolve(stateRoot: stateRoot)
        }
    }

    /// Stable hash of canonicalized schema.json bytes for `aps schema` drift detection.
    public static func hash(_ document: UserSchemaDocument) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func entry(named name: String, in document: UserSchemaDocument) -> SchemaKeyEntry? {
        document.keys.first { $0.name == name }
    }
}
