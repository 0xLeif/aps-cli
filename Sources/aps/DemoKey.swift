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
    /// `ProfileDocument.name` projected through AppState `Slice` over `profile`.
    case profileName

    public var storage: String {
        switch self {
        case .counter, .message: return "State"
        case .flag: return "StoredState"
        case .note, .profile: return "FileState"
        case .secret: return "EncryptedFile"
        case .profileName: return "Slice"
        }
    }

    public var valueType: String {
        switch self {
        case .counter: return "Int"
        case .message, .note, .secret, .profileName: return "String"
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
            return "String via encrypted file store (<state-root>/secret.enc)"
        case .profileName:
            return "profile.name via AppState Slice over FileState ProfileDocument"
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

public enum APSError: Error, CustomStringConvertible, Equatable {
    case invalidValue(key: DemoKey, value: String)
    case encodingFailed
    case decodingFailed
    case persistenceFailed(key: DemoKey)
    case secretUnlockFailed
    /// On-disk FileState exists but cannot be decoded (torn concurrent write).
    case corruptState(key: DemoKey)

    /// sysexits `EX_DATAERR` (65): input/state data was present but unusable.
    public static let corruptStateExitCode: Int32 = 65

    public var description: String {
        switch self {
        case .invalidValue(let key, let value):
            return "Invalid value '\(value)' for \(key.rawValue) (\(key.valueType))"
        case .encodingFailed:
            return "Failed to encode value as UTF-8 JSON"
        case .decodingFailed:
            return "Failed to decode value from UTF-8 JSON"
        case .persistenceFailed(let key):
            return "Failed to persist \(key.rawValue)"
        case .secretUnlockFailed:
            return "Failed to unlock the secret store (wrong passphrase or key)"
        case .corruptState(let key):
            return "Corrupt or torn \(key.rawValue) state file (undecodable). Concurrent writers may have torn the file; reset the key or repair the file."
        }
    }

    /// Stable machine code for the JSON error envelope. Never removed or renamed.
    public var code: String {
        switch self {
        case .invalidValue: return "invalid_value"
        case .encodingFailed: return "encoding_failed"
        case .decodingFailed: return "decoding_failed"
        case .persistenceFailed: return "persistence_failed"
        case .secretUnlockFailed: return "secret_unlock_failed"
        case .corruptState: return "corrupt_state"
        }
    }

    /// sysexits-aligned exit code. 64 means the caller can fix the invocation;
    /// 65+ means environment or data, 70 means an aps bug.
    public var exitCode: Int32 {
        switch self {
        case .invalidValue: return 64 // EX_USAGE
        case .decodingFailed, .corruptState: return APSError.corruptStateExitCode // EX_DATAERR
        case .secretUnlockFailed: return 69 // EX_UNAVAILABLE
        case .encodingFailed: return 70 // EX_SOFTWARE
        case .persistenceFailed: return 73 // EX_CANTCREAT
        }
    }

    /// Actionable next step for humans and agents.
    public var hint: String {
        switch self {
        case .invalidValue:
            return "Run `aps keys` to see expected types per key."
        case .encodingFailed:
            return "The value could not be JSON-encoded; please report this if it reproduces."
        case .decodingFailed:
            return "A value or file is not valid JSON for its key; check the input or the state root (--state-dir / APS_HOME)."
        case .persistenceFailed:
            return "Check that the state root exists and is writable (--state-dir / APS_HOME)."
        case .secretUnlockFailed:
            return "Check APS_SECRET_PASSPHRASE or the secret.key file under the state root."
        case .corruptState(let key):
            return "Reset the key (`aps reset \(key.rawValue)`) or repair the file under the state root."
        }
    }
}
