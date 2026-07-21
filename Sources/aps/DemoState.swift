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
/// 1. Explicit subcommand `--state-dir`
/// 2. Peeled root `--state-dir` (see `peelRootStateDir`)
/// 3. `APS_HOME` environment variable
/// 4. `~/.aps`
///
/// Called from CLI `boot()` only. Tests inject their own
/// `FileManager.defaultFileStatePath` before constructing `StateStore`.
public enum APSPaths {
    /// Subcommand names that end root-flag peeling (issue #87).
    private static let subcommandTokens: Set<String> = [
        "get", "set", "watch", "dump", "keys", "key", "stats", "reset", "schema", "help"
    ]

    /// Root `--state-dir` peeled before ArgumentParser runs.
    nonisolated(unsafe) private static var _rootStateDirOverride: String?

    public nonisolated static func setRootStateDirOverride(_ value: String?) {
        _rootStateDirOverride = value
    }

    @MainActor
    public static var rootStateDirOverride: String? {
        _rootStateDirOverride
    }

    /// Remove leading `--state-dir PATH` / `--state-dir=PATH` before the first
    /// subcommand token. Returns the last peeled path (if any).
    public nonisolated static func peelRootStateDir(from args: inout [String]) -> String? {
        var found: String?
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "--" { break }
            if subcommandTokens.contains(token) { break }
            if token == "--state-dir" {
                guard index + 1 < args.count else { break }
                found = args[index + 1]
                args.remove(at: index + 1)
                args.remove(at: index)
                continue
            }
            if token.hasPrefix("--state-dir=") {
                found = String(token.dropFirst("--state-dir=".count))
                args.remove(at: index)
                continue
            }
            index += 1
        }
        return found
    }

    @MainActor
    public static var defaultFileStateDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".aps", isDirectory: true).path
    }

    @MainActor
    public static func resolve(stateDir: String?) -> String {
        if let stateDir, !stateDir.isEmpty {
            return (stateDir as NSString).expandingTildeInPath
        }
        if let root = rootStateDirOverride, !root.isEmpty {
            return (root as NSString).expandingTildeInPath
        }
        if let home = ProcessInfo.processInfo.environment["APS_HOME"], !home.isEmpty {
            return (home as NSString).expandingTildeInPath
        }
        return defaultFileStateDirectory
    }

    @MainActor
    public static func configure(stateDir: String? = nil) {
        FileManager.defaultFileStatePath = resolve(stateDir: stateDir)
    }
}
