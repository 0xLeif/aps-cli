import AppState
import Foundation

/// Demo keys registered on `Application`: a tiny fixed schema for the CLI.
///
/// Future idea: dynamic / user-declared keys without rebuilding.
extension Application {
    /// In-memory integer counter (process lifetime).
    var counter: State<Int> {
        state(initial: 0, id: "aps.counter")
    }

    /// In-memory string message (process lifetime).
    var message: State<String> {
        state(initial: "", id: "aps.message")
    }

    /// Persisted boolean flag via `UserDefaults` (`StoredState`).
    var flag: StoredState<Bool> {
        storedState(initial: false, id: "aps.flag")
    }

    /// Persisted note on disk via `FileState`.
    @MainActor
    var note: FileState<String> {
        fileState(
            initial: "",
            filename: "note.json",
            isBase64Encoded: false
        )
    }

    /// Structured profile document on disk via `FileState`.
    @MainActor
    var profile: FileState<ProfileDocument> {
        fileState(
            initial: ProfileDocument(),
            filename: "profile.json",
            isBase64Encoded: false
        )
    }

#if canImport(Security)
    /// Sensitive string via Keychain-backed `SecureState`.
    ///
    /// Keychain account: `APSKeychain.secretAccount` (`dev.leif.aps/secret`).
    /// Initial value is `nil` so `reset` deletes the Keychain item.
    var secret: SecureState {
        secureState(
            initial: nil,
            feature: APSKeychain.service,
            id: APSKeychain.account
        )
    }
#endif

    /// Wall-clock used when stamping watch/dump output.
    var clock: Dependency<any APSClock> {
        dependency(SystemAPSClock())
    }

    /// Shared JSON encoder for pretty CLI dumps.
    var jsonCoding: Dependency<JSONCoding> {
        dependency(JSONCoding())
    }

    /// Process-local mutation stats consumed via `@ObservedDependency`.
    @MainActor
    var stats: Dependency<DemoStats> {
        dependency(DemoStats())
    }
}

/// Stable paths for CLI-persisted `FileState` data.
///
/// Resolution order for `configure(stateDir:)`:
/// 1. Explicit `--state-dir`
/// 2. `APS_HOME` environment variable
/// 3. `~/.aps`
///
/// Called from CLI `boot()` only. Tests inject their own
/// `FileManager.defaultFileStatePath` before constructing `StateStore`.
enum APSPaths {
    @MainActor
    static var defaultFileStateDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".aps", isDirectory: true).path
    }

    @MainActor
    static func resolve(stateDir: String?) -> String {
        if let stateDir, !stateDir.isEmpty {
            return (stateDir as NSString).expandingTildeInPath
        }
        if let home = ProcessInfo.processInfo.environment["APS_HOME"], !home.isEmpty {
            return (home as NSString).expandingTildeInPath
        }
        return defaultFileStateDirectory
    }

    @MainActor
    static func configure(stateDir: String? = nil) {
        FileManager.defaultFileStatePath = resolve(stateDir: stateDir)
    }
}
