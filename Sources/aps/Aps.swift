import ArgumentParser
import AppState
import Foundation

@main
struct Aps: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aps",
        abstract: "A tiny CLI that dogfoods AppState outside SwiftUI.",
        discussion: """
        Demo keys (fixed schema for v1):
          counter  Int     State        (in-memory)
          message  String  State        (in-memory)
          flag     Bool    StoredState  (UserDefaults)
          note     String  FileState    (~/.aps/note.json)

        Built on https://github.com/0xLeif/AppState
        """,
        version: "0.1.0",
        subcommands: [Get.self, Set.self, Watch.self, Dump.self],
        defaultSubcommand: nil
    )
}

extension Aps {
    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print the current value for a demo key."
        )

        @Argument(help: "Demo key: counter | message | flag | note")
        var key: DemoKey

        func run() throws {
            try onMainThread {
                Application.logging(isEnabled: false)
                let store = StateStore()
                print(store.get(key))
            }
        }
    }

    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Set a demo key to a value."
        )

        @Argument(help: "Demo key: counter | message | flag | note")
        var key: DemoKey

        @Argument(help: "New value (Bool: true/false/1/0; Int for counter)")
        var value: String

        func run() throws {
            try onMainThread {
                Application.logging(isEnabled: false)
                let store = StateStore()
                try store.set(key, value: value)
                print(store.get(key))
            }
        }
    }

    struct Watch: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print the value whenever it changes (Observation + polling)."
        )

        @Argument(help: "Demo key: counter | message | flag | note")
        var key: DemoKey

        @Option(name: .long, help: "Poll interval in milliseconds (fallback for disk-backed keys).")
        var interval: UInt64 = 250

        func run() throws {
            try onMainThread {
                Application.logging(isEnabled: false)
                let store = StateStore()
                store.watchBlocking(key, pollInterval: TimeInterval(interval) / 1000.0) { value in
                    // Write via FileHandle so output appears immediately when stdout is not a TTY.
                    if let data = (value + "\n").data(using: .utf8) {
                        FileHandle.standardOutput.write(data)
                    }
                }
            }
        }
    }

    struct Dump: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print all known demo keys as pretty JSON."
        )

        func run() throws {
            try onMainThread {
                Application.logging(isEnabled: false)
                let store = StateStore()
                print(try store.dump())
            }
        }
    }
}

/// Synchronous `@main` starts on the real main thread; treat that as MainActor for AppState.
private func onMainThread<T: Sendable>(
    _ body: @MainActor () throws -> T
) throws -> T {
    precondition(
        Thread.isMainThread,
        "aps must run on the main thread so AppState can notify observers"
    )
    return try MainActor.assumeIsolated {
        try body()
    }
}
