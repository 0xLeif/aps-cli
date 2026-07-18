import AppState
import Foundation
import Observation

/// Reads and writes demo keys through AppState idioms (including `@AppDependency`).
///
/// Callers must be on the main thread — AppState asserts that in `notifyChange()`,
/// and ArgumentParser's synchronous `@main` entry point provides that.
@MainActor
public final class StateStore {
    @AppDependency(\.clock) private var clock: any APSClock
    @AppDependency(\.jsonCoding) private var jsonCoding: JSONCoding

    public init() {
        APSPaths.configure()
        Application.load(dependency: \.clock)
        Application.load(dependency: \.jsonCoding)
    }

    public func get(_ key: DemoKey) -> String {
        switch key {
        case .counter:
            return String(Application.state(\.counter).value)
        case .message:
            return Application.state(\.message).value
        case .flag:
            return String(Application.state(\.flag).value)
        case .note:
            return Application.fileState(\.note).value
        }
    }

    public func set(_ key: DemoKey, value: String) throws {
        switch key {
        case .counter:
            guard let intValue = Int(value) else {
                throw APSError.invalidValue(key: key, value: value)
            }
            var state = Application.state(\.counter)
            state.value = intValue
        case .message:
            var state = Application.state(\.message)
            state.value = value
        case .flag:
            guard let boolValue = Self.parseBool(value) else {
                throw APSError.invalidValue(key: key, value: value)
            }
            var state = Application.state(\.flag)
            state.value = boolValue
            // Linux Foundation does not always flush UserDefaults on process exit.
            UserDefaults.standard.synchronize()
        case .note:
            var state = Application.fileState(\.note)
            state.value = value
        }
    }

    public func reset(_ key: DemoKey) {
        switch key {
        case .counter:
            Application.reset(\.counter)
        case .message:
            Application.reset(\.message)
        case .flag:
            Application.reset(storedState: \.flag)
            UserDefaults.standard.synchronize()
        case .note:
            Application.reset(fileState: \.note)
        }
    }

    public func resetAll() {
        for key in DemoKey.allCases {
            reset(key)
        }
    }

    public func dump() throws -> String {
        let snapshot = DumpSnapshot(
            timestamp: clock.now,
            keys: DemoKey.allCases.map { key in
                DumpEntry(
                    key: key.rawValue,
                    storage: key.storage,
                    type: key.valueType,
                    value: get(key)
                )
            }
        )
        return try jsonCoding.encodePretty(snapshot)
    }

    /// Blocking watch for the synchronous CLI: Observation + RunLoop polling.
    ///
    /// - Observation covers in-process mutations (`State`).
    /// - Polling re-reads values so `FileState` / `StoredState` updates can surface when
    ///   Observation alone would not (e.g. another process wrote the file).
    /// - `shouldContinue` lets tests (and future tooling) stop the loop cleanly.
    public func watchBlocking(
        _ key: DemoKey,
        pollInterval: TimeInterval = 0.25,
        shouldContinue: () -> Bool = { true },
        onChange: (String) -> Void
    ) {
        var last = get(key)
        onChange(last)

        let slice = max(pollInterval / 5.0, 0.05)

        while shouldContinue() {
            let flag = ChangeFlag()

            withObservationTracking {
                self.readForObservation(key)
            } onChange: {
                flag.mark()
            }

            while shouldContinue() {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: slice))
                let current = get(key)
                if flag.isSet || current != last {
                    if current != last {
                        last = current
                        onChange(current)
                    }
                    break
                }
            }
        }
    }

    private func readForObservation(_ key: DemoKey) {
        switch key {
        case .counter:
            _ = Application.state(\.counter).value
        case .message:
            _ = Application.state(\.message).value
        case .flag:
            _ = Application.state(\.flag).value
        case .note:
            _ = Application.fileState(\.note).value
        }
    }

    public nonisolated static func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "1", "yes", "y", "on": return true
        case "false", "0", "no", "n", "off": return false
        default: return nil
        }
    }
}

/// `@Sendable` flag for Observation `onChange` closures.
private final class ChangeFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func mark() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private struct DumpSnapshot: Encodable {
    let timestamp: Date
    let keys: [DumpEntry]
}

private struct DumpEntry: Encodable {
    let key: String
    let storage: String
    let type: String
    let value: String
}
