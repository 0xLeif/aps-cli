import ArgumentParser
import Foundation

extension Aps {
    struct Key: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "key",
            abstract: "Edit the state-root schema.json registry (add/remove/list).",
            subcommands: [Add.self, Remove.self, List.self]
        )
    }
}

extension Aps.Key {
    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add or replace a key in schema.json."
        )

        @Argument(help: "Key name ([A-Za-z][A-Za-z0-9_]*).")
        var name: String

        @Option(name: .long, help: "Value type: Int | String | Bool | object")
        var type: String

        @Option(name: .long, help: "Storage: State | StoredState | FileState | EncryptedFile | Slice")
        var storage: String

        @Option(name: .long, help: "Initial value (string/bool/int wire form, or JSON object).")
        var initial: String?

        @Option(name: .long, help: "Relative file path for FileState / EncryptedFile.")
        var path: String?

        @Option(name: .long, help: "Short documentation string.")
        var doc: String?

        @Option(name: .long, help: "Parent object key for Slice storage.")
        var sliceOf: String?

        @Option(name: .long, help: "Field name on the parent object for Slice storage.")
        var sliceField: String?

        @Flag(name: .long, help: "Replace an existing schema entry with the same name.")
        var force: Bool = false

        @OptionGroup
        var options: StateOptions

        func run() throws {
            try onMainThread {
                boot(stateDir: options.stateDir)
                let store = StateStore()
                do {
                    let initialJSON = try Self.parseInitial(initial, type: type, storage: storage)
                    let entry = SchemaKeyEntry(
                        name: name,
                        type: type,
                        storage: storage,
                        initial: initialJSON,
                        path: path,
                        doc: doc,
                        objectShape: type == "object" ? [:] : nil,
                        sliceOf: sliceOf,
                        sliceField: sliceField
                    )
                    try store.addKey(entry, force: force)
                    if options.json {
                        let schema = try store.loadSchema()
                        let payload = CLIOutput.KeysPayload(
                            keys: schema.keys.map {
                                CLIOutput.KeyInfo(
                                    key: $0.name,
                                    type: $0.type,
                                    storage: $0.storage,
                                    detail: $0.detail
                                )
                            }
                        )
                        print(try CLIOutput.encodeJSON(payload))
                    } else {
                        print("added \(name)")
                    }
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: options.json)
                }
            }
        }

        private static func parseInitial(
            _ raw: String?,
            type: String,
            storage: String
        ) throws -> SchemaJSON? {
            if storage == "Slice" {
                return raw.map { .string($0) } ?? .string("")
            }
            guard let raw else {
                switch type {
                case "Int": return .int(0)
                case "Bool": return .bool(false)
                case "object": return .object([:])
                default: return .string("")
                }
            }
            switch type {
            case "Int":
                guard let value = Int(raw) else {
                    throw APSError.invalidValue(key: "initial", value: raw)
                }
                return .int(value)
            case "Bool":
                guard let value = StateStore.parseBool(raw) else {
                    throw APSError.invalidValue(key: "initial", value: raw)
                }
                return .bool(value)
            case "object":
                guard let data = raw.data(using: .utf8),
                      let object = try? JSONDecoder().decode([String: SchemaJSON].self, from: data)
                else {
                    throw APSError.invalidValue(key: "initial", value: raw)
                }
                return .object(object)
            default:
                return .string(raw)
            }
        }
    }

    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove a key from schema.json."
        )

        @Argument(help: "Key name to remove.")
        var name: String

        @Flag(name: .long, help: "Also delete FileState / EncryptedFile / StoredState data.")
        var purge: Bool = false

        @OptionGroup
        var options: StateOptions

        func run() throws {
            try onMainThread {
                boot(stateDir: options.stateDir)
                let store = StateStore()
                do {
                    try store.removeKey(name: name, purge: purge)
                    if options.json {
                        print(try CLIOutput.encodeJSON(["removed": name]))
                    } else {
                        print("removed \(name)")
                    }
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: options.json)
                }
            }
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List keys from schema.json (same inventory as aps keys)."
        )

        @OptionGroup
        var options: StateOptions

        func run() throws {
            try onMainThread {
                boot(stateDir: options.stateDir)
                let store = StateStore()
                do {
                    let schema = try store.loadSchema()
                    if options.json {
                        let payload = CLIOutput.KeysPayload(
                            keys: schema.keys.map {
                                CLIOutput.KeyInfo(
                                    key: $0.name,
                                    type: $0.type,
                                    storage: $0.storage,
                                    detail: $0.detail
                                )
                            }
                        )
                        print(try CLIOutput.encodeJSON(payload))
                    } else {
                        for entry in schema.keys {
                            print("\(entry.name)\t\(entry.type)\t\(entry.storage)\t\(entry.detail)")
                        }
                    }
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: options.json)
                }
            }
        }
    }
}
