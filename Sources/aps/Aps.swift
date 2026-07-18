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
        subcommands: [
            Get.self,
            Set.self,
            Watch.self,
            Dump.self,
            Keys.self,
            Reset.self
        ],
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
                boot()
                print(StateStore().get(key))
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
                boot()
                let store = StateStore()
                do {
                    try store.set(key, value: value)
                } catch let error as APSError {
                    throw ValidationError(error.description)
                }
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
                boot()
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
                boot()
                print(try StateStore().dump())
            }
        }
    }

    struct Keys: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List the fixed demo keys and how they are stored."
        )

        func run() throws {
            print("KEY\tTYPE\tSTORAGE\tDESCRIPTION")
            for key in DemoKey.allCases {
                print("\(key.helpSummary)\t\(key.detail)")
            }
        }
    }

    struct Reset: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Reset one demo key (or all keys) back to its initial value."
        )

        @Argument(help: "Demo key to reset. Omit with --all.")
        var key: DemoKey?

        @Flag(name: .long, help: "Reset every demo key.")
        var all: Bool = false

        func run() throws {
            guard all || key != nil else {
                throw ValidationError("Pass a key or --all. Example: aps reset counter")
            }
            if all && key != nil {
                throw ValidationError("Pass either a key or --all, not both.")
            }

            try onMainThread {
                boot()
                let store = StateStore()
                if all {
                    store.resetAll()
                    print("reset all keys")
                } else if let key {
                    store.reset(key)
                    print(store.get(key))
                }
            }
        }
    }
}

@MainActor
private func boot() {
    Application.logging(isEnabled: false)
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
