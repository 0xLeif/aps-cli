import ArgumentParser
import Foundation

extension Aps {
    internal struct Key: ParsableCommand {
        internal static let configuration = CommandConfiguration(
            commandName: "key",
            abstract: "Edit the state-root schema.json registry (add/remove/list).",
            subcommands: [Add.self, Remove.self, List.self]
        )
    }
}

extension Aps.Key {
    internal struct Add: ParsableCommand {
        internal static let configuration = CommandConfiguration(
            abstract: "Add or replace a key in schema.json."
        )

        @Argument(help: "Key name ([A-Za-z][A-Za-z0-9_]*).")
        internal var name: String

        @Option(name: .long, help: "Value type: Int | String | Bool | object")
        internal var type: String

        @Option(name: .long, help: "Storage: State | StoredState | FileState | EncryptedFile | Slice")
        internal var storage: String

        @Option(name: .long, help: "Initial value (string/bool/int wire form, or JSON object).")
        internal var initial: String?

        @Option(name: .long, help: "Relative file path for FileState / EncryptedFile.")
        internal var path: String?

        @Option(name: .long, help: "Short documentation string.")
        internal var doc: String?

        @Option(
            name: .long,
            help: "Object field declaration NAME=TYPE; repeat for additional fields."
        )
        internal var field: [String] = []

        @Option(name: .long, help: "Parent object key for Slice storage.")
        internal var sliceOf: String?

        @Option(name: .long, help: "Field name on the parent object for Slice storage.")
        internal var sliceField: String?

        @Flag(name: .long, help: "Replace an existing schema entry with the same name.")
        internal var force: Bool = false

        @OptionGroup
        internal var options: StateOptions

        internal func run() throws {
            try onMainThread {
                boot(stateDir: options.stateDir)
                let store = StateStore()
                do {
                    let objectShape = try Self.parseObjectShape(field, type: type)
                    let initialJSON = try Self.parseInitial(
                        initial,
                        type: type,
                        objectShape: objectShape
                    )
                    let entry = SchemaKeyEntry(
                        name: name,
                        type: type,
                        storage: storage,
                        initial: initialJSON,
                        path: path,
                        doc: doc,
                        objectShape: objectShape,
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
            objectShape: [String: String]?
        ) throws -> SchemaJSON? {
            let parsed: SchemaJSON
            if let raw {
                guard let value = SchemaJSON.parse(raw, as: type) else {
                    throw APSError.invalidValue(key: "initial", value: raw)
                }
                parsed = value
            } else {
                guard type != "object" || objectShape?.isEmpty != false else {
                    throw APSError.invalidValue(key: "initial", value: "(missing)")
                }
                guard let value = SchemaJSON.defaultValue(for: type) else {
                    throw APSError.invalidValue(key: "type", value: type)
                }
                parsed = value
            }

            guard parsed.matches(type: type, objectShape: objectShape) else {
                throw APSError.invalidValue(key: "initial", value: raw ?? "(default)")
            }
            return parsed
        }

        private static func parseObjectShape(
            _ declarations: [String],
            type: String
        ) throws -> [String: String]? {
            guard type == "object" else {
                guard declarations.isEmpty else {
                    throw APSError.invalidValue(
                        key: "field",
                        value: declarations.joined(separator: ",")
                    )
                }
                return nil
            }

            var shape: [String: String] = [:]
            let nameExpression = try? NSRegularExpression(pattern: UserSchema.namePattern)
            for declaration in declarations {
                let parts = declaration.split(
                    separator: "=",
                    maxSplits: 1,
                    omittingEmptySubsequences: false
                )
                guard parts.count == 2 else {
                    throw APSError.invalidValue(key: "field", value: declaration)
                }
                let name = String(parts[0])
                let fieldType = String(parts[1])
                let range = NSRange(name.startIndex..., in: name)
                guard
                    let nameExpression,
                    nameExpression.firstMatch(in: name, range: range) != nil,
                    UserSchema.allowedTypes.contains(fieldType),
                    shape[name] == nil
                else {
                    throw APSError.invalidValue(key: "field", value: declaration)
                }
                shape[name] = fieldType
            }
            return shape
        }
    }

    internal struct Remove: ParsableCommand {
        internal static let configuration = CommandConfiguration(
            abstract: "Remove a key from schema.json."
        )

        @Argument(help: "Key name to remove.")
        internal var name: String

        @Flag(name: .long, help: "Also delete FileState / EncryptedFile / StoredState data.")
        internal var purge: Bool = false

        @OptionGroup
        internal var options: StateOptions

        internal func run() throws {
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

    internal struct List: ParsableCommand {
        internal static let configuration = CommandConfiguration(
            abstract: "List keys from schema.json (same inventory as aps keys)."
        )

        @OptionGroup
        internal var options: StateOptions

        internal func run() throws {
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
