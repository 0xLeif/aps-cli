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

/// JSON value used inside `schema.json` (`initial` and nested object fields).
public enum SchemaJSON: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case object([String: SchemaJSON])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
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
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// Wire string used by CLI set/reset for primitive initials.
    public var wireString: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        case .object(let value):
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            if let data = try? encoder.encode(value),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
            return "{}"
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
        try validate(document)
        return document
    }

    public static func write(_ document: UserSchemaDocument, to url: URL) throws {
        try validate(document)
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
            if entry.storage == "FileState" || entry.storage == "EncryptedFile" {
                guard let path = entry.path, isSafeRelativePath(path) else {
                    throw APSError.schemaInvalid(
                        reason: "\(entry.name) requires a safe relative path"
                    )
                }
            }
            if entry.storage == "Slice" {
                guard let parent = entry.sliceOf, let field = entry.sliceField else {
                    throw APSError.schemaInvalid(
                        reason: "\(entry.name) Slice requires sliceOf and sliceField"
                    )
                }
                guard document.keys.contains(where: {
                    $0.name == parent && $0.type == "object" && $0.storage == "FileState"
                }) else {
                    throw APSError.schemaInvalid(
                        reason: "\(entry.name) sliceOf '\(parent)' must be a FileState object"
                    )
                }
                _ = field
            }
            if entry.type == "object" {
                guard entry.objectShape != nil else {
                    throw APSError.schemaInvalid(
                        reason: "\(entry.name) object type requires objectShape"
                    )
                }
            }
            if entry.storage != "Slice", entry.initial == nil {
                throw APSError.schemaInvalid(reason: "\(entry.name) requires initial")
            }
        }
    }

    public static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("..") else {
            return false
        }
        return true
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
