import ArgumentParser
import Foundation

/// Shared machine-readable / human CLI output helpers.
enum CLIOutput {
    struct KeyValuePayload: Encodable {
        let key: String
        let type: String
        let storage: String
        let value: JSONValue
    }

    struct KeysPayload: Encodable {
        let keys: [KeyInfo]
    }

    struct KeyInfo: Encodable {
        let key: String
        let type: String
        let storage: String
        let detail: String
    }

    struct ResetPayload: Encodable {
        let reset: String
        let key: String?
        let value: JSONValue?
    }

    struct WatchEvent: Encodable {
        let key: String
        let type: String
        let storage: String
        let value: JSONValue
        let timestamp: Date
    }

    /// Typed JSON leaf used so dump/get preserve Int/Bool instead of stringifying.
    enum JSONValue: Encodable, Equatable {
        case string(String)
        case int(Int)
        case bool(Bool)
        case object(ProfileDocument)

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .int(let value):
                try container.encode(value)
            case .bool(let value):
                try container.encode(value)
            case .object(let value):
                try container.encode(value)
            }
        }
    }

    static func encodePretty<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw APSError.encodingFailed
        }
        return string
    }

    static func encodeLine<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw APSError.encodingFailed
        }
        return string
    }

    static func writeLine(_ line: String) {
        if let data = (line + "\n").data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }

    @MainActor
    static func typedValue(for key: DemoKey, store: StateStore) throws -> JSONValue {
        switch key {
        case .counter:
            return .int(Int(store.get(key)) ?? 0)
        case .message, .note:
            return .string(store.get(key))
        case .flag:
            return .bool(store.get(key) == "true")
        case .profile:
            return .object(try store.profileDocument())
        }
    }
}

/// Options shared by subcommands that touch AppState.
struct StateOptions: ParsableArguments {
    @Option(name: .long, help: "Override state directory (takes precedence over APS_HOME).")
    var stateDir: String?

    @Flag(name: .long, help: "Emit machine-readable JSON.")
    var json: Bool = false
}
