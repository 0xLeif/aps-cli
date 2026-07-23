import ArgumentParser
import AppState
import Foundation

/// Peel root `--state-dir` before ArgumentParser (issue #87), then dispatch.
@main
enum APSEntrypoint {
    static func main() {
        var args = Array(CommandLine.arguments.dropFirst())
        let peeled = APSPaths.peelRootStateDir(from: &args)
        APSPaths.setRootStateDirOverride(peeled)
        Aps.main(args)
    }
}

struct Aps: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aps",
        abstract: "A tiny CLI that dogfoods AppState outside SwiftUI.",
        discussion: """
        Keys come from <state-root>/schema.json (demo defaults materialize on first use).
        Manage entries with: aps key add|remove|list

        Default seed keys:
          counter  Int     State
          message  String  State
          flag     Bool    StoredState
          note     String  FileState
          profile  object  FileState
          secret   String  EncryptedFile
          profileName String Slice (profile.name)

        State root: --state-dir (root or subcommand) > APS_HOME > ~/.aps
        Root form: aps --state-dir PATH <subcommand> ...

        Built on https://github.com/0xLeif/AppState
        """,
        version: "1.0.0",
        subcommands: [
            Get.self,
            Set.self,
            Watch.self,
            Dump.self,
            Keys.self,
            Key.self,
            Stats.self,
            Reset.self,
            SchemaCmd.self
        ],
        defaultSubcommand: nil
    )
}

extension Aps {
    struct SchemaCmd: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "schema",
            abstract: "Print the self-describing CLI contract (keys, commands, payloads, errors) as JSON."
        )

        @Flag(name: .long, help: "Emit machine-readable JSON (accepted for symmetry; schema is always JSON).")
        var json: Bool = false

        @Option(name: .long, help: "Override state directory (takes precedence over APS_HOME).")
        var stateDir: String?

        func run() throws {
            _ = json
            try onMainThread {
                do {
                    print(try CLIOutput.encodeJSON(Schema.document(stateDir: stateDir)))
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: true)
                }
            }
        }
    }
}

extension Aps {
    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print the current value for a registered key."
        )

        @Argument(help: "Key name from schema.json (see aps keys).")
        var key: String

        @OptionGroup
        var options: StateOptions

        func run() throws {
            try onMainThread {
                boot(stateDir: options.stateDir)
                let store = StateStore()
                do {
                    try StateStore.requireDecodableDiskState(forName: key)
                    let entry = try store.resolve(key)
                    if options.json {
                        let payload = CLIOutput.KeyValuePayload(
                            key: entry.name,
                            type: entry.type,
                            storage: entry.storage,
                            value: try CLIOutput.typedValue(for: entry, store: store)
                        )
                        print(try CLIOutput.encodeJSON(payload))
                    } else {
                        print(try store.get(name: key))
                    }
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: options.json)
                }
            }
        }
    }

    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Set a registered key to a value."
        )

        @Argument(help: "Key name from schema.json (see aps keys).")
        var key: String

        @Argument(help: "New value (Bool: true/false/1/0; Int; JSON object; or String)")
        var value: String

        @OptionGroup
        var options: StateOptions

        func run() throws {
            try onMainThread {
                boot(stateDir: options.stateDir)
                let store = StateStore()
                do {
                    try store.set(name: key, value: value)
                    let entry = try store.resolve(key)
                    if options.json {
                        let payload = CLIOutput.KeyValuePayload(
                            key: entry.name,
                            type: entry.type,
                            storage: entry.storage,
                            value: try CLIOutput.typedValue(for: entry, store: store)
                        )
                        print(try CLIOutput.encodeJSON(payload))
                    } else {
                        print(try store.get(name: key))
                    }
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: options.json)
                }
            }
        }
    }

    struct Watch: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print the value whenever it changes (Observation + polling)."
        )

        @Argument(help: "Key name from schema.json (see aps keys).")
        var key: String

        @Option(name: .long, help: "Poll interval in milliseconds (fallback for disk-backed keys).")
        var interval: UInt64 = 250

        @Option(name: .long, help: "Stop after printing this many values (includes the initial value).")
        var count: Int?

        @Option(name: .long, help: "Stop after this many seconds.")
        var timeout: Double?

        @Flag(name: .long, help: "Emit one JSON object per line.")
        var jsonl: Bool = false

        @Flag(name: .long, help: "Alias for --jsonl (flag symmetry with other commands).")
        var json: Bool = false

        @Option(name: .long, help: "Override state directory (takes precedence over APS_HOME).")
        var stateDir: String?

        func run() throws {
            try onMainThread {
                boot(stateDir: stateDir)
                let store = StateStore()
                let jsonl = jsonl || json
                let deadline = timeout.map { Date().addingTimeInterval($0) }
                var emitted = 0
                var stopReason: StopReason?

                let signalBox = SignalBox()
                let signalSources = installWatchSignalHandlers(signalBox)

                if count == nil && timeout == nil {
                    CLIOutput.writeError("watch: unbounded stream; press Ctrl-C to stop, or use --count/--timeout for bounded runs")
                }

                do {
                    let entry = try store.resolve(key)
                    try store.watchBlocking(
                        name: key,
                        pollInterval: TimeInterval(interval) / 1000.0,
                        pollDeadline: deadline,
                        shouldContinue: {
                            if let count, emitted >= count {
                                stopReason = .count
                                return false
                            }
                            if let deadline, Date() >= deadline {
                                stopReason = .timeout
                                return false
                            }
                            if let sig = signalBox.first {
                                stopReason = .signal(sig)
                                return false
                            }
                            return true
                        }
                    ) { value in
                        emitted += 1
                        if jsonl {
                            // Parse the fresh `value` from watchBlocking. Do not re-query
                            // the store: FileState cache can lag cross-process disk writes.
                            if let event = try? CLIOutput.watchEvent(
                                entry: entry,
                                rawValue: value,
                                timestamp: store.now
                            ), let line = try? CLIOutput.encodeLine(event) {
                                CLIOutput.writeLine(line)
                            } else if let line = try? CLIOutput.encodeLine(
                                CLIOutput.WatchErrorEvent(
                                    key: key,
                                    error: "encoding_failed",
                                    message: "value could not be encoded as a watch event",
                                    timestamp: store.now
                                )
                            ) {
                                // The jsonl stream never carries non-JSON lines.
                                CLIOutput.writeLine(line)
                            }
                        } else {
                            CLIOutput.writeLine(value)
                        }
                    }
                } catch let error as APSError {
                    if jsonl, case .corruptState = error {
                        let event = CLIOutput.WatchErrorEvent(
                            key: key,
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

                if let stopReason {
                    if jsonl {
                        let event = CLIOutput.WatchEndEvent(
                            key: key,
                            reason: stopReason.token,
                            timestamp: store.now
                        )
                        if let line = try? CLIOutput.encodeLine(event) {
                            CLIOutput.writeLine(line)
                        }
                    } else {
                        CLIOutput.writeError("watch \(key): stopped (\(stopReason.summary))")
                    }
                    if stopReason.exitCode != 0 {
                        throw ExitCode(stopReason.exitCode)
                    }
                }

                // Actual use after the loop: guarantees the dispatch sources
                // outlive the watch (debug kept them incidentally; release
                // optimized them away and silently lost every signal).
                signalSources.forEach { $0.cancel() }
            }
        }
    }

    struct Dump: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print all registered keys as pretty JSON."
        )

        @OptionGroup
        var options: StateOptions

        func run() throws {
            try onMainThread {
                boot(stateDir: options.stateDir)
                // dump is always JSON; --json is accepted for agent symmetry.
                _ = options.json
                do {
                    print(try StateStore().dumpRegistered())
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: true)
                }
            }
        }
    }

    struct Keys: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List registered keys and how they are stored."
        )

        @Flag(name: .long, help: "Emit machine-readable JSON.")
        var json: Bool = false

        @Flag(name: .long, help: "Print only key names, one per line.")
        var quiet: Bool = false

        @Option(name: .long, help: "Override state directory (takes precedence over APS_HOME).")
        var stateDir: String?

        func run() throws {
            try onMainThread {
                boot(stateDir: stateDir)
                do {
                    let schema = try StateStore().loadSchema()
                    if quiet {
                        for entry in schema.keys {
                            print(entry.name)
                        }
                    } else if json {
                        let payload = CLIOutput.KeysPayload(
                            keys: schema.keys.map {
                                CLIOutput.KeyInfo(
                                    key: $0.name,
                                    type: $0.type,
                                    storage: $0.storage,
                                    detail: $0.detail
                                )
                            }
                        )
                        print(try CLIOutput.encodeJSON(payload))
                    } else if TTY.stdoutIsTTY {
                        print(TTY.table(
                            header: ["KEY", "TYPE", "STORAGE", "DESCRIPTION"],
                            rows: schema.keys.map {
                                [$0.name, $0.type, $0.storage, $0.detail]
                            }
                        ))
                    } else {
                        print("KEY\tTYPE\tSTORAGE\tDESCRIPTION")
                        for entry in schema.keys {
                            print("\(entry.name)\t\(entry.type)\t\(entry.storage)\t\(entry.detail)")
                        }
                    }
                } catch let error as APSError {
                    try CLIOutput.fail(error, json: json)
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

        @Option(name: .long, help: "Override state directory (takes precedence over APS_HOME).")
        var stateDir: String?

        func run() throws {
            try onMainThread {
                boot(stateDir: stateDir)
                let store = StateStore()

                if watch {
                    let deadline = timeout.map { Date().addingTimeInterval($0) }
                    var emitted = 0

                    store.watchStatsBlocking(
                        pollInterval: TimeInterval(interval) / 1000.0,
                        pollDeadline: deadline,
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
                if let text = try? CLIOutput.encodeJSON(payload), pretty {
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
            abstract: "Reset one key, all seed keys (--all), or every registered key (--registered)."
        )

        @Argument(help: "Key name to reset. Omit with --all or --registered.")
        var key: String?

        @Flag(name: .long, help: "Reset every DemoKey seed key. User-added keys are left alone.")
        var all: Bool = false

        @Flag(name: .long, help: "Reset every key in schema.json, including user-added keys.")
        var registered: Bool = false

        @OptionGroup
        var options: StateOptions

        func run() throws {
            guard all || registered || key != nil else {
                throw ValidationError(
                    "Pass a key, --all (seed keys), or --registered. Example: aps reset counter"
                )
            }
            if all && registered {
                throw ValidationError("Pass either --all or --registered, not both.")
            }
            if (all || registered) && key != nil {
                throw ValidationError("Pass either a key or a bulk reset flag, not both.")
            }

            try onMainThread {
                boot(stateDir: options.stateDir)
                let store = StateStore()
                do {
                    if all {
                        store.resetAll()
                        if options.json {
                            let payload = CLIOutput.ResetPayload(reset: "all", key: nil, value: nil)
                            print(try CLIOutput.encodeJSON(payload))
                        } else {
                            print("reset seed keys")
                        }
                    } else if registered {
                        try store.resetAllRegistered()
                        if options.json {
                            let payload = CLIOutput.ResetPayload(
                                reset: "registered",
                                key: nil,
                                value: nil
                            )
                            print(try CLIOutput.encodeJSON(payload))
                        } else {
                            print("reset all registered keys")
                        }
                    } else if let key {
                        try store.reset(name: key)
                        let entry = try store.resolve(key)
                        if options.json {
                            let payload = CLIOutput.ResetPayload(
                                reset: "key",
                                key: key,
                                value: try CLIOutput.typedValue(for: entry, store: store)
                            )
                            print(try CLIOutput.encodeJSON(payload))
                        } else {
                            print(try store.get(name: key))
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
func boot(stateDir: String? = nil) {
    Application.logging(isEnabled: false)
    // Subcommand --state-dir wins over peeled root --state-dir.
    APSPaths.configure(stateDir: stateDir)
}

/// Synchronous `@main` starts on the real main thread; treat that as MainActor for AppState.
func onMainThread<T: Sendable>(
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
