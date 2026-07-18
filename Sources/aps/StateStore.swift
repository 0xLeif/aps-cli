import AppState
import Foundation
import Observation

/// Reads and writes demo keys through AppState idioms (including `@AppDependency`).
///
/// Callers must be on the main thread: AppState asserts that in `notifyChange()`,
/// and ArgumentParser's synchronous `@main` entry point provides that.
///
/// FileState path configuration belongs to CLI `boot()` (or the test harness).
/// `StateStore` does not call `APSPaths.configure()`, so injected test paths stay put.
@MainActor
public final class StateStore {
    @AppDependency(\.clock) private var clock: any APSClock
    @AppDependency(\.jsonCoding) private var jsonCoding: JSONCoding

    public init() {
        Application.load(dependency: \.clock)
        Application.load(dependency: \.jsonCoding)
    }

    /// Wall clock from the injected `APSClock` dependency.
    public var now: Date { clock.now }

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
        case .profile:
            return (try? encodeProfile(Application.fileState(\.profile).value)) ?? "{\"name\":\"\",\"version\":0}"
        }
    }

    public func profileDocument() throws -> ProfileDocument {
        Application.fileState(\.profile).value
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
            // AppState FileState swallows save errors after updating its cache.
            // Confirm the value is actually on disk before claiming success.
            let onDisk = try Self.readNoteFromDisk()
            guard onDisk == value else {
                throw APSError.persistenceFailed(key: .note)
            }
        case .profile:
            let document: ProfileDocument
            do {
                guard let data = value.data(using: .utf8) else {
                    throw APSError.decodingFailed
                }
                document = try JSONDecoder().decode(ProfileDocument.self, from: data)
            } catch {
                throw APSError.invalidValue(key: key, value: value)
            }
            var state = Application.fileState(\.profile)
            state.value = document
            let onDisk = try Self.readProfileFromDisk()
            guard onDisk == document else {
                throw APSError.persistenceFailed(key: .profile)
            }
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
        case .profile:
            Application.reset(fileState: \.profile)
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
            keys: try DemoKey.allCases.map { key in
                DumpEntry(
                    key: key.rawValue,
                    storage: key.storage,
                    type: key.valueType,
                    value: try CLIOutput.typedValue(for: key, store: self)
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
    /// - For disk-backed keys, polling reads files directly so AppState's FileState cache
    ///   cannot hide cross-process writes.
    /// - `shouldContinue` lets tests (and CLI `--count` / `--timeout`) stop the loop cleanly.
    public func watchBlocking(
        _ key: DemoKey,
        pollInterval: TimeInterval = 0.25,
        shouldContinue: () -> Bool = { true },
        onChange: (String) -> Void
    ) {
        var last = freshValue(key)
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
                let current = freshValue(key)
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

    /// Value used by watch polling. Disk-backed keys bypass AppState's FileState cache.
    private func freshValue(_ key: DemoKey) -> String {
        switch key {
        case .note:
            return (try? Self.readNoteFromDisk()) ?? get(key)
        case .profile:
            if let document = try? Self.readProfileFromDisk() {
                return (try? encodeProfile(document)) ?? get(key)
            }
            return get(key)
        case .counter, .message, .flag:
            return get(key)
        }
    }

    /// Read `note.json` without touching AppState's in-memory FileState cache.
    ///
    /// Mirrors AppState's non-Base64 FileState encoding: UTF-8 JSON via `JSONEncoder`.
    public static func readNoteFromDisk() throws -> String {
        let fileURL = Self.fileStateURL(filename: "note.json")
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(String.self, from: data)
        } catch {
            throw APSError.persistenceFailed(key: .note)
        }
    }

    public static func readProfileFromDisk() throws -> ProfileDocument {
        let fileURL = Self.fileStateURL(filename: "profile.json")
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(ProfileDocument.self, from: data)
        } catch {
            throw APSError.persistenceFailed(key: .profile)
        }
    }

    private static func fileStateURL(filename: String) -> URL {
        URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent(filename)
    }

    private func encodeProfile(_ document: ProfileDocument) throws -> String {
        let data = try JSONEncoder().encode(document)
        guard let string = String(data: data, encoding: .utf8) else {
            throw APSError.encodingFailed
        }
        return string
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
        case .profile:
            _ = Application.fileState(\.profile).value
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
    let value: CLIOutput.JSONValue
}
