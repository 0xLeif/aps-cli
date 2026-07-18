import ArgumentParser
import Foundation

/// Fixed demo keys the CLI understands.
public enum DemoKey: String, CaseIterable, ExpressibleByArgument, Sendable {
    case counter
    case message
    case flag
    case note
    case profile
    case secret

    public var storage: String {
        switch self {
        case .counter, .message: return "State"
        case .flag: return "StoredState"
        case .note, .profile: return "FileState"
        case .secret: return "SecureState"
        }
    }

    public var valueType: String {
        switch self {
        case .counter: return "Int"
        case .message, .note, .secret: return "String"
        case .flag: return "Bool"
        case .profile: return "ProfileDocument"
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
        case .profile:
            return "Codable {name,version} via FileState (~/.aps/profile.json)"
        case .secret:
            return "String via SecureState / Keychain (\(APSKeychain.secretAccount))"
        }
    }
}

/// Structured FileState document dogfooded by the `profile` key.
public struct ProfileDocument: Codable, Equatable, Sendable {
    public var name: String
    public var version: Int

    public init(name: String = "", version: Int = 0) {
        self.name = name
        self.version = version
    }
}

/// Well-known Keychain identity for the `secret` SecureState demo key.
///
/// AppState stores SecureState under `Scope.key` (`feature/id`) as the Keychain
/// account (`kSecAttrAccount`). The feature string is the service-style namespace.
public enum APSKeychain: Sendable {
    /// Reverse-DNS style service / feature namespace.
    public static let service = "dev.leif.aps"

    /// Account id within the service namespace.
    public static let account = "secret"

    /// Full Keychain account key used by AppState (`service/account`).
    public static var secretAccount: String {
        "\(service)/\(account)"
    }
}

public enum APSError: Error, CustomStringConvertible, Equatable {
    case unknownKey(String)
    case invalidValue(key: DemoKey, value: String)
    case encodingFailed
    case decodingFailed
    case persistenceFailed(key: DemoKey)
    case keychainUnavailable

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
        case .persistenceFailed(let key):
            return "Failed to persist \(key.rawValue)"
        case .keychainUnavailable:
            return "SecureState (Keychain) is unavailable on this platform. The secret key requires macOS Keychain."
        }
    }
}
