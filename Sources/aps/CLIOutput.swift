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

    struct StatsPayload: Encodable {
        let mutationCount: Int
        let lastMutatedKey: String
        let storage: String

        init(snapshot: DemoStatsSnapshot) {
            self.mutationCount = snapshot.mutationCount
            self.lastMutatedKey = snapshot.lastMutatedKey
            self.storage = "ObservedDependency"
        }
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
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
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

    // MARK: - Error contract

    /// Structured error envelope emitted on stderr in machine modes.
    /// Stable shape: codes are snake_case APSError cases, never removed.
    struct ErrorEnvelope: Encodable {
        struct Body: Encodable {
            let code: String
            let message: String
            let hint: String
        }
        let error: Body
    }

    /// True when structured errors should accompany the human line: machine
    /// mode was requested, or APS_ERROR_JSON=1 opts in unconditionally.
    static func structuredErrorsEnabled(json: Bool) -> Bool {
        json || ProcessInfo.processInfo.environment["APS_ERROR_JSON"] == "1"
    }

    static func writeError(_ line: String) {
        if let data = (line + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    /// Single failure path for domain errors: human line on stderr, optional
    /// JSON envelope, then the taxonomy exit code. Usage/shape errors from
    /// ArgumentParser itself still exit 64 on their own.
    static func fail(_ error: APSError, json: Bool) throws -> Never {
        writeError("Error: \(error.description)")
        if structuredErrorsEnabled(json: json),
           let envelope = try? encodeLine(
               ErrorEnvelope(
                   error: .init(
                       code: error.code,
                       message: error.description,
                       hint: error.hint
                   )
               )
           ) {
            writeError(envelope)
        }
        throw ExitCode(error.exitCode)
    }

    @MainActor
    static func typedValue(for key: DemoKey, store: StateStore) throws -> JSONValue {
        try typedValue(for: key, from: store.get(key))
    }

    /// Build a typed value from a fresh rendered string (e.g. watch `onChange`).
    ///
    /// Prefer this over re-querying `StateStore` for disk-backed keys: AppState's
    /// FileState cache can lag cross-process writes that `watchBlocking` already
    /// surfaced via direct disk reads.
    static func typedValue(for key: DemoKey, from raw: String) throws -> JSONValue {
        switch key {
        case .counter:
            guard let intValue = Int(raw) else {
                throw APSError.invalidValue(key: key, value: raw)
            }
            return .int(intValue)
        case .message, .note, .secret, .profileName:
            return .string(raw)
        case .flag:
            guard let boolValue = StateStore.parseBool(raw) else {
                throw APSError.invalidValue(key: key, value: raw)
            }
            return .bool(boolValue)
        case .profile:
            guard let data = raw.data(using: .utf8) else {
                throw APSError.decodingFailed
            }
            do {
                return .object(try JSONDecoder().decode(ProfileDocument.self, from: data))
            } catch {
                throw APSError.invalidValue(key: key, value: raw)
            }
        }
    }

    static func watchEvent(
        key: DemoKey,
        rawValue: String,
        timestamp: Date
    ) throws -> WatchEvent {
        WatchEvent(
            key: key.rawValue,
            type: key.valueType,
            storage: key.storage,
            value: try typedValue(for: key, from: rawValue),
            timestamp: timestamp
        )
    }
}

/// Options shared by subcommands that touch AppState.
struct StateOptions: ParsableArguments {
    @Option(name: .long, help: "Override state directory (takes precedence over APS_HOME).")
    var stateDir: String?

    @Flag(name: .long, help: "Emit machine-readable JSON.")
    var json: Bool = false
}
