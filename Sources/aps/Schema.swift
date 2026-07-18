import Foundation

/// `aps schema`: the self-describing contract endpoint (issue #32).
///
/// Static contract only: one cacheable JSON document describing the CLI
/// version, schema version, keys, commands, payload shapes, state-root
/// precedence, and the error table. Live state stays in `dump`.
/// `schemaVersion` is an integer bumped on any contract change; agents
/// compare equality and bail on mismatch.
enum Schema {

    static let cliVersion = "0.2.0"
    static let schemaVersion = 2

    // MARK: - Document model

    struct Document: Encodable {
        let cliVersion: String
        let schemaVersion: Int
        let stateRoot: StateRootDoc
        let keys: [KeyEntry]
        let commands: [CommandEntry]
        let payloads: [String: Node]
        let errors: [ErrorEntry]
    }

    struct StateRootDoc: Encodable {
        let precedence: [String]
        let env: String
        let flag: String
        let defaultPath: String
    }

    struct KeyEntry: Encodable {
        let name: String
        let type: String
        let storage: String
        let lifetime: String
        let path: String?
        let keychainAccount: String?
    }

    struct CommandEntry: Encodable {
        let name: String
        let summary: String
        let arguments: [String]
        let flags: [String]
        let payload: String?
        let streaming: Bool
    }

    struct ErrorEntry: Encodable {
        let code: String
        let exitCode: Int
        let meaning: String
        let hint: String
    }

    // MARK: - Minimal JSON Schema subset (type/object/properties/required/array/items)

    struct Property: Encodable {
        let name: String
        let node: Node
        let required: Bool
    }

    indirect enum Node: Encodable {
        case prim(String)
        case obj([Property])
        case arr(Node)

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .prim(let type):
                try container.encode(type, forKey: .type)
            case .obj(let properties):
                try container.encode("object", forKey: .type)
                var props: [String: Node] = [:]
                var required: [String] = []
                for property in properties {
                    props[property.name] = property.node
                    if property.required { required.append(property.name) }
                }
                try container.encode(props, forKey: .properties)
                try container.encode(required, forKey: .required)
            case .arr(let item):
                try container.encode("array", forKey: .type)
                try container.encode(item, forKey: .items)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type, properties, required, items
        }
    }

    // MARK: - Builders

    private static func prop(_ name: String, _ node: Node, required: Bool = true) -> Property {
        Property(name: name, node: node, required: required)
    }

    static func document() -> Document {
        Document(
            cliVersion: cliVersion,
            schemaVersion: schemaVersion,
            stateRoot: StateRootDoc(
                precedence: ["--state-dir", "APS_HOME", "~/.aps"],
                env: "APS_HOME",
                flag: "--state-dir",
                defaultPath: "~/.aps"
            ),
            keys: keyEntries(),
            commands: commandEntries(),
            payloads: payloadNodes(),
            errors: errorEntries()
        )
    }

    private static func keyEntries() -> [KeyEntry] {
        DemoKey.allCases.map { key in
            let lifetime: String
            let path: String?
            let account: String?
            switch key {
            case .counter, .message:
                lifetime = "process"
                path = nil
                account = nil
            case .flag:
                lifetime = "persisted"
                path = "UserDefaults (aps.flag)"
                account = nil
            case .note:
                lifetime = "persisted"
                path = "<state-root>/note.json"
                account = nil
            case .profile:
                lifetime = "persisted"
                path = "<state-root>/profile.json"
                account = nil
            case .secret:
                lifetime = "persisted"
                path = "macOS encrypted-file secret store"
                account = APSencrypted-file secret store.secretAccount
            case .profileName:
                lifetime = "persisted (slice of profile)"
                path = "<state-root>/profile.json"
                account = nil
            }
            return KeyEntry(
                name: key.rawValue,
                type: key.valueType,
                storage: key.storage,
                lifetime: lifetime,
                path: path,
                keychainAccount: account
            )
        }
    }

    private static func commandEntries() -> [CommandEntry] {
        [
            CommandEntry(
                name: "get",
                summary: "Print the current value for a key.",
                arguments: ["<key>"],
                flags: ["--json", "--state-dir"],
                payload: "KeyValuePayload",
                streaming: false
            ),
            CommandEntry(
                name: "set",
                summary: "Set a key to a value.",
                arguments: ["<key>", "<value>"],
                flags: ["--json", "--state-dir"],
                payload: "KeyValuePayload",
                streaming: false
            ),
            CommandEntry(
                name: "watch",
                summary: "Print the value whenever it changes.",
                arguments: ["<key>"],
                flags: ["--interval", "--count", "--timeout", "--jsonl", "--state-dir"],
                payload: "WatchEvent",
                streaming: true
            ),
            CommandEntry(
                name: "dump",
                summary: "Print all known keys as pretty JSON.",
                arguments: [],
                flags: ["--json", "--state-dir"],
                payload: "DumpSnapshot",
                streaming: false
            ),
            CommandEntry(
                name: "keys",
                summary: "List the fixed keys and how they are stored.",
                arguments: [],
                flags: ["--json"],
                payload: "KeysPayload",
                streaming: false
            ),
            CommandEntry(
                name: "reset",
                summary: "Reset one key (or --all) back to its initial value.",
                arguments: ["[<key>]"],
                flags: ["--all", "--json", "--state-dir"],
                payload: "ResetPayload",
                streaming: false
            ),
            CommandEntry(
                name: "stats",
                summary: "Print process-local mutation stats.",
                arguments: [],
                flags: ["--watch", "--count", "--timeout", "--interval", "--json"],
                payload: "StatsPayload",
                streaming: true
            ),
            CommandEntry(
                name: "schema",
                summary: "Print this self-describing contract document.",
                arguments: [],
                flags: ["--json"],
                payload: "SchemaDocument",
                streaming: false
            ),
        ]
    }

    private static func payloadNodes() -> [String: Node] {
        let jsonValue = Node.prim("string | integer | boolean | object")
        return [
            "KeyValuePayload": .obj([
                prop("key", .prim("string")),
                prop("type", .prim("string")),
                prop("storage", .prim("string")),
                prop("value", jsonValue),
            ]),
            "KeysPayload": .obj([
                prop("keys", .arr(.obj([
                    prop("key", .prim("string")),
                    prop("type", .prim("string")),
                    prop("storage", .prim("string")),
                    prop("detail", .prim("string")),
                ]))),
            ]),
            "WatchEvent": .obj([
                prop("key", .prim("string")),
                prop("type", .prim("string")),
                prop("storage", .prim("string")),
                prop("value", jsonValue),
                prop("timestamp", .prim("string (ISO-8601)")),
            ]),
            "WatchErrorEvent": .obj([
                prop("type", .prim("string (\"error\")")),
                prop("key", .prim("string")),
                prop("error", .prim("string")),
                prop("message", .prim("string")),
                prop("timestamp", .prim("string (ISO-8601)")),
            ]),
            "WatchEndEvent": .obj([
                prop("type", .prim("string (\"end\")")),
                prop("key", .prim("string")),
                prop("reason", .prim("string (\"count\" | \"timeout\" | \"sigint\" | \"sigterm\" | \"signal\")")),
                prop("timestamp", .prim("string (ISO-8601)")),
            ]),
            "ResetPayload": .obj([
                prop("reset", .prim("string (\"all\" | \"key\")")),
                prop("key", .prim("string?"), required: false),
                prop("value", jsonValue, required: false),
            ]),
            "StatsPayload": .obj([
                prop("mutationCount", .prim("integer")),
                prop("lastMutatedKey", .prim("string")),
                prop("storage", .prim("string")),
            ]),
            "ErrorEnvelope": .obj([
                prop("error", .obj([
                    prop("code", .prim("string")),
                    prop("message", .prim("string")),
                    prop("hint", .prim("string")),
                ])),
            ]),
        ]
    }

    private static func errorEntries() -> [ErrorEntry] {
        [
            ErrorEntry(
                code: "invalid_value",
                exitCode: 64,
                meaning: "caller-fixable input: value does not parse for the key type",
                hint: "Run `aps keys` to see expected types per key."
            ),
            ErrorEntry(
                code: "decoding_failed",
                exitCode: 65,
                meaning: "a value or file is not valid JSON for its key",
                hint: "Check the input or the state root (--state-dir / APS_HOME)."
            ),
            ErrorEntry(
                code: "corrupt_state",
                exitCode: 65,
                meaning: "a state file exists but is undecodable (torn write)",
                hint: "Reset the key or repair the file under the state root."
            ),
            ErrorEntry(
                code: "secret_unlock_failed",
                exitCode: 69,
                meaning: "encrypted secret could not be unlocked (wrong passphrase or key)",
                hint: "Check APS_SECRET_PASSPHRASE or the secret.key file under the state root."
            ),
            ErrorEntry(
                code: "encoding_failed",
                exitCode: 70,
                meaning: "internal bug: value could not be JSON-encoded",
                hint: "Please report this if it reproduces."
            ),
            ErrorEntry(
                code: "persistence_failed",
                exitCode: 73,
                meaning: "write did not persist (unwritable state root)",
                hint: "Check that the state root exists and is writable."
            ),
        ]
    }
}
