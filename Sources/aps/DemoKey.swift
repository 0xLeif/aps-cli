import ArgumentParser
import Foundation

/// Fixed demo keys the CLI understands.
public enum DemoKey: String, CaseIterable, ExpressibleByArgument, Sendable {
    case counter
    case message
    case flag
    case note

    public var storage: String {
        switch self {
        case .counter, .message: return "State"
        case .flag: return "StoredState"
        case .note: return "FileState"
        }
    }

    public var valueType: String {
        switch self {
        case .counter: return "Int"
        case .message, .note: return "String"
        case .flag: return "Bool"
        }
    }

    public var helpSummary: String {
        "\(rawValue)\t\(valueType)\t\(storage)"
    }

    /// Human-readable one-liner for `aps keys`.
    public var detail: String {
        switch self {
        case .counter:
            return "in-memory Int counter (process lifetime)"
        case .message:
            return "in-memory String (process lifetime)"
        case .flag:
            return "Bool via StoredState / UserDefaults"
        case .note:
            return "String via FileState (~/.aps/note.json)"
        }
    }
}

public enum APSError: Error, CustomStringConvertible, Equatable {
    case unknownKey(String)
    case invalidValue(key: DemoKey, value: String)
    case encodingFailed
    case decodingFailed

    public var description: String {
        switch self {
        case .unknownKey(let key):
            return "Unknown key '\(key)'. Known keys: \(DemoKey.allCases.map(\.rawValue).joined(separator: ", "))"
        case .invalidValue(let key, let value):
            return "Invalid value '\(value)' for \(key.rawValue) (\(key.valueType))"
        case .encodingFailed:
            return "Failed to encode value as UTF-8 JSON"
        case .decodingFailed:
            return "Failed to decode value from UTF-8 JSON"
        }
    }
}
