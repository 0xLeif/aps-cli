import AppState
import Foundation

/// Demo keys registered on `Application` — a tiny fixed schema for the CLI.
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

    /// Wall-clock used when stamping watch/dump output.
    var clock: Dependency<any APSClock> {
        dependency(SystemAPSClock())
    }

    /// Shared JSON encoder for pretty CLI dumps.
    var jsonCoding: Dependency<JSONCoding> {
        dependency(JSONCoding())
    }
}

/// Stable paths for CLI-persisted `FileState` data.
enum APSPaths {
    @MainActor
    static var fileStateDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".aps", isDirectory: true).path
    }

    @MainActor
    static func configure() {
        FileManager.defaultFileStatePath = fileStateDirectory
    }
}
