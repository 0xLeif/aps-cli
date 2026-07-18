import ArgumentParser
import AppState
import Foundation

@main
struct Aps: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aps",
        abstract: "A tiny CLI that dogfoods AppState outside SwiftUI.",
        discussion: """
        Demo keys (fixed schema for 0.x):
          counter  Int              State        (in-memory)
          message  String           State        (in-memory)
          flag     Bool             StoredState  (UserDefaults)
          note     String           FileState    (~/.aps/note.json)
          profile  ProfileDocument  FileState    (~/.aps/profile.json)
          secret   String           SecureState  (Keychain; macOS)
          profileName  String       Slice        (profile.name via AppState Slice)

        State root: --state-dir > APS_HOME > ~/.aps

        Built on https://github.com/0xLeif/AppState
        """,
        version: "0.2.0",
        subcommands: [
            Get.self,
            Set.self,
            Watch.self,
            Dump.self,
            Keys.self,
            Stats.self,
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

        @Argument(help: "Demo key: counter | message | flag | note | profile | secret | profileName")
        var key: DemoKey

        @OptionGroup
        var options: StateOptions

        func run() throws {
            try onMainThread {
                boot(stateDir: options.stateDir)
                let store = StateStore()
                do {
                    try StateStore.requireDecodableDiskState(for: key)
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: options.json)
                }
                if options.json {
                    let payload = CLIOutput.KeyValuePayload(
                        key: key.rawValue,
                        type: key.valueType,
                        storage: key.storage,
                        value: try CLIOutput.typedValue(for: key, store: store)
                    )
                    print(try CLIOutput.encodePretty(payload))
                } else {
                    print(store.get(key))
                }
            }
        }
    }

    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Set a demo key to a value."
        )

        @Argument(help: "Demo key: counter | message | flag | note | profile | secret | profileName")
        var key: DemoKey

        @Argument(help: "New value (Bool: true/false/1/0; Int for counter; JSON for profile; String for secret/profileName)")
        var value: String

        @OptionGroup
        var options: StateOptions

        func run() throws {
            try onMainThread {
                boot(stateDir: options.stateDir)
                let store = StateStore()
                do {
                    try store.set(key, value: value)
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: options.json)
                }
                if options.json {
                    let payload = CLIOutput.KeyValuePayload(
                        key: key.rawValue,
                        type: key.valueType,
                        storage: key.storage,
                        value: try CLIOutput.typedValue(for: key, store: store)
                    )
                    print(try CLIOutput.encodePretty(payload))
                } else {
                    print(store.get(key))
                }
            }
        }
    }

    struct Watch: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print the value whenever it changes (Observation + polling)."
        )

        @Argument(help: "Demo key: counter | message | flag | note | profile | secret | profileName")
        var key: DemoKey

        @Option(name: .long, help: "Poll interval in milliseconds (fallback for disk-backed keys).")
        var interval: UInt64 = 250

        @Option(name: .long, help: "Stop after printing this many values (includes the initial value).")
        var count: Int?

        @Option(name: .long, help: "Stop after this many seconds.")
        var timeout: Double?

        @Flag(name: .long, help: "Emit one JSON object per line.")
        var jsonl: Bool = false

        @Option(name: .long, help: "Override state directory (takes precedence over APS_HOME).")
        var stateDir: String?

        func run() throws {
            try onMainThread {
                boot(stateDir: stateDir)
                let store = StateStore()
                let deadline = timeout.map { Date().addingTimeInterval($0) }
                var emitted = 0

                do {
                    try store.watchBlocking(
                        key,
                        pollInterval: TimeInterval(interval) / 1000.0,
                        shouldContinue: {
                            if let count, emitted >= count { return false }
                            if let deadline, Date() >= deadline { return false }
                            return true
                        }
                    ) { value in
                        emitted += 1
                        if jsonl {
                            // Parse the fresh `value` from watchBlocking. Do not re-query
                            // the store: FileState cache can lag cross-process disk writes.
                            let event = try? CLIOutput.watchEvent(
                                key: key,
                                rawValue: value,
                                timestamp: store.now
                            )
                            if let event, let line = try? CLIOutput.encodeLine(event) {
                                CLIOutput.writeLine(line)
                            } else {
                                CLIOutput.writeLine(value)
                            }
                        } else {
                            CLIOutput.writeLine(value)
                        }
                    }
                } catch let error as APSError {
                    if jsonl, case .corruptState = error {
                        let event = CLIOutput.WatchErrorEvent(
                            key: key.rawValue,
                            error: "corruptState",
                            message: error.description,
                            timestamp: store.now
                        )
                        if let line = try? CLIOutput.encodeLine(event) {
                            CLIOutput.writeLine(line)
                        }
                    }
                    try CLIOutput.fail(error, json: jsonl)
                }
            }
        }
    }

    struct Dump: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print all known demo keys as pretty JSON."
        )

        @OptionGroup
        var options: StateOptions

        func run() throws {
            try onMainThread {
                boot(stateDir: options.stateDir)
                // dump is always JSON; --json is accepted for agent symmetry.
                _ = options.json
                do {
                    print(try StateStore().dump())
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: true)
                }
            }
        }
    }

    struct Keys: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List the fixed demo keys and how they are stored."
        )

        @Flag(name: .long, help: "Emit machine-readable JSON.")
        var json: Bool = false

        func run() throws {
            if json {
                let payload = CLIOutput.KeysPayload(
                    keys: DemoKey.allCases.map {
                        CLIOutput.KeyInfo(
                            key: $0.rawValue,
                            type: $0.valueType,
                            storage: $0.storage,
                            detail: $0.detail
                        )
                    }
                )
                print(try CLIOutput.encodePretty(payload))
            } else {
                print("KEY\tTYPE\tSTORAGE\tDESCRIPTION")
                for key in DemoKey.allCases {
                    print("\(key.helpSummary)\t\(key.detail)")
                }
            }
        }
    }

    struct Stats: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print process-local mutation stats from the ObservedDependency demo service."
        )

        @Flag(name: .long, help: "Watch for stats mutations (Combine objectWillChange + polling).")
        var watch: Bool = false

        @Option(name: .long, help: "Stop after printing this many values (includes the initial value).")
        var count: Int?

        @Option(name: .long, help: "Stop after this many seconds.")
        var timeout: Double?

        @Option(name: .long, help: "Poll interval in milliseconds when watching.")
        var interval: UInt64 = 250

        @Flag(name: .long, help: "Emit machine-readable JSON.")
        var json: Bool = false

        func run() throws {
            try onMainThread {
                boot()
                let store = StateStore()

                if watch {
                    let deadline = timeout.map { Date().addingTimeInterval($0) }
                    var emitted = 0

                    store.watchStatsBlocking(
                        pollInterval: TimeInterval(interval) / 1000.0,
                        shouldContinue: {
                            if let count, emitted >= count { return false }
                            if let deadline, Date() >= deadline { return false }
                            return true
                        }
                    ) { snapshot in
                        emitted += 1
                        Self.printSnapshot(snapshot, json: json, pretty: false)
                    }
                } else {
                    Self.printSnapshot(store.statsSnapshot(), json: json, pretty: true)
                }
            }
        }

        private static func printSnapshot(_ snapshot: DemoStatsSnapshot, json: Bool, pretty: Bool) {
            if json {
                let payload = CLIOutput.StatsPayload(snapshot: snapshot)
                if pretty, let text = try? CLIOutput.encodePretty(payload) {
                    print(text)
                } else if let line = try? CLIOutput.encodeLine(payload) {
                    CLIOutput.writeLine(line)
                }
            } else {
                let key = snapshot.lastMutatedKey.isEmpty ? "(none)" : snapshot.lastMutatedKey
                CLIOutput.writeLine("\(snapshot.mutationCount)\t\(key)")
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

        @OptionGroup
        var options: StateOptions

        func run() throws {
            guard all || key != nil else {
                throw ValidationError("Pass a key or --all. Example: aps reset counter")
            }
            if all && key != nil {
                throw ValidationError("Pass either a key or --all, not both.")
            }

            try onMainThread {
                boot(stateDir: options.stateDir)
                let store = StateStore()
                do {
                    if all {
                        store.resetAll()
                        if options.json {
                            let payload = CLIOutput.ResetPayload(reset: "all", key: nil, value: nil)
                            print(try CLIOutput.encodePretty(payload))
                        } else {
                            print("reset all keys")
                        }
                    } else if let key {
                        store.reset(key)
                        if options.json {
                            let payload = CLIOutput.ResetPayload(
                                reset: "key",
                                key: key.rawValue,
                                value: try CLIOutput.typedValue(for: key, store: store)
                            )
                            print(try CLIOutput.encodePretty(payload))
                        } else {
                            print(store.get(key))
                        }
                    }
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: options.json)
                }
            }
        }
    }
}

@MainActor
private func boot(stateDir: String? = nil) {
    Application.logging(isEnabled: false)
    APSPaths.configure(stateDir: stateDir)
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
