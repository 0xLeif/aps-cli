import AppState
#if canImport(Combine)
import Combine
#endif
import Foundation
import XCTest
@testable import aps

#if os(Windows)
import WinSDK
#endif

#if !os(Linux) && !os(Windows)
/// Local consumer that dogfoods `@ObservedDependency` the same way AppState's own tests do.
@MainActor
private struct ObservedStatsConsumer {
    @ObservedDependency(\.stats) var stats: DemoStats
}
#endif

/// Portable process-env mutation for tests (`setenv` is POSIX-only).
private func setProcessEnv(_ key: String, _ value: String?) {
    #if os(Windows)
    key.withCString { keyPointer in
        if let value {
            value.withCString { valuePointer in
                _ = SetEnvironmentVariableA(keyPointer, valuePointer)
            }
        } else {
            _ = SetEnvironmentVariableA(keyPointer, nil)
        }
    }
    #else
    if let value {
        setenv(key, value, 1)
    } else {
        unsetenv(key)
    }
    #endif
}

final class APSTests: XCTestCase {
    /// Held between setUp and tearDown so `--parallel` cannot interleave cases.
    private var holdsIsolationGate = false
    private var fileStatePath: String?
    private var userDefaultsOverride: Application.DependencyOverride?
    private var hermeticDefaults: InMemoryUserDefaults?

    override func setUp() async throws {
        try await super.setUp()

        // Serialize Application singleton access across parallel workers.
        await TestIsolationGate.shared.acquire()
        holdsIsolationGate = true

        // Build scoped resources off the MainActor so we do not capture `self`
        // inside a main-actor closure (Swift 6 isolation).
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-tests-\(UUID().uuidString)", isDirectory: true)
            .path
        fileStatePath = path
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)

        let defaults = InMemoryUserDefaults()
        hermeticDefaults = defaults

        // Secret passphrase env is process-global; start each case clean.
        setProcessEnv("APS_SECRET_PASSPHRASE", nil)
        setProcessEnv("APS_SECRET_USE_PASSPHRASE", nil)

        // Drop any leftover standard-domain flag from prior non-hermetic runs so
        // hermetic assertions are meaningful on developer machines / CI caches.
        UserDefaults.standard.removeObject(forKey: "App/aps.flag")
        UserDefaults.standard.synchronize()

        let override = await MainActor.run { () -> Application.DependencyOverride in
            Application.logging(isEnabled: false)
            FileManager.defaultFileStatePath = path

            let token = Application.override(\.userDefaults, with: defaults)

            DynamicKeyStorage.resetProcessMemory()

            Application.reset(\.counter)
            Application.reset(\.message)
            Application.reset(storedState: \.flag)
            Application.reset(fileState: \.note)
            Application.reset(fileState: \.profile)
            Application.dependency(\.stats).reset()
            return token
        }
        userDefaultsOverride = override
    }

    override func tearDown() async throws {
        let path = fileStatePath

        await MainActor.run {
            DynamicKeyStorage.resetProcessMemory()
            Application.reset(\.counter)
            Application.reset(\.message)
            Application.reset(storedState: \.flag)
            Application.reset(fileState: \.note)
            Application.reset(fileState: \.profile)
            Application.dependency(\.stats).reset()
        }

        if let path {
            try? FileManager.default.removeItem(atPath: path)
        }
        fileStatePath = nil
        hermeticDefaults = nil

        await userDefaultsOverride?.cancel()
        userDefaultsOverride = nil

        if holdsIsolationGate {
            await TestIsolationGate.shared.release()
            holdsIsolationGate = false
        }

        try await super.tearDown()
    }

    func testParseBool() {
        XCTAssertEqual(StateStore.parseBool("true"), true)
        XCTAssertEqual(StateStore.parseBool("YES"), true)
        XCTAssertEqual(StateStore.parseBool("1"), true)
        XCTAssertEqual(StateStore.parseBool("false"), false)
        XCTAssertEqual(StateStore.parseBool("off"), false)
        XCTAssertNil(StateStore.parseBool("maybe"))
    }

    func testDemoKeyMetadata() {
        XCTAssertEqual(DemoKey.counter.storage, "State")
        XCTAssertEqual(DemoKey.flag.storage, "StoredState")
        XCTAssertEqual(DemoKey.note.storage, "FileState")
        XCTAssertEqual(DemoKey.profile.storage, "FileState")
        XCTAssertEqual(DemoKey.secret.storage, "EncryptedFile")
        XCTAssertEqual(DemoKey.profileName.storage, "Slice")
        XCTAssertEqual(DemoKey.counter.valueType, "Int")
        XCTAssertEqual(DemoKey.profile.valueType, "object")
        XCTAssertEqual(DemoKey.secret.valueType, "String")
        XCTAssertEqual(DemoKey.profileName.valueType, "String")
        XCTAssertEqual(DemoKey.allCases.count, 7)
        XCTAssertTrue(DemoKey.note.detail.contains("FileState"))
        XCTAssertTrue(DemoKey.profile.detail.contains("profile.json"))
        XCTAssertTrue(DemoKey.secret.detail.contains("encrypted file"))
        XCTAssertTrue(DemoKey.profileName.detail.contains("Slice"))
    }

    @MainActor
    func testCounterRoundTrip() async throws {
        let store = StateStore()
        try store.set(.counter, value: "7")
        XCTAssertEqual(store.get(.counter), "7")
        try store.set(.counter, value: "42")
        XCTAssertEqual(store.get(.counter), "42")
    }

    @MainActor
    func testMessageAndFlagRoundTrip() async throws {
        let store = StateStore()
        try store.set(.message, value: "hello")
        XCTAssertEqual(store.get(.message), "hello")

        try store.set(.flag, value: "true")
        XCTAssertEqual(store.get(.flag), "true")
        try store.set(.flag, value: "0")
        XCTAssertEqual(store.get(.flag), "false")
    }

    @MainActor
    func testNoteFileStateRoundTrip() async throws {
        let store = StateStore()
        try store.set(.note, value: "persisted note")
        XCTAssertEqual(store.get(.note), "persisted note")
    }

    @MainActor
    func testProfileStructuredFileStateRoundTrip() async throws {
        let store = StateStore()
        try store.set(.profile, value: #"{"name":"agent","version":3}"#)
        let document = try store.profileDocument()
        XCTAssertEqual(document, ProfileDocument(name: "agent", version: 3))
        XCTAssertTrue(store.get(.profile).contains("\"name\""))
        XCTAssertTrue(store.get(.profile).contains("agent"))
        XCTAssertEqual(try StateStore.readProfileFromDisk(), document)
    }



    @MainActor
    func testProfileNameSliceWritesLandInParent() async throws {
        let store = StateStore()
        try store.set(.profile, value: "{\"name\":\"before\",\"version\":1}")
        try store.set(.profileName, value: "after")
        XCTAssertEqual(try store.profileDocument().name, "after")
        XCTAssertEqual(store.profileName(), "after")
        XCTAssertEqual(store.get(.profileName), "after")
        XCTAssertEqual(try store.profileDocument().version, 1)
        XCTAssertEqual(try StateStore.readProfileFromDisk().name, "after")
    }

    @MainActor
    func testProfileNameSliceReadsParentField() async throws {
        let store = StateStore()
        try store.set(.profile, value: "{\"name\":\"sliced\",\"version\":9}")
        XCTAssertEqual(store.get(.profileName), "sliced")
    }

    @MainActor
    func testProfileNameSlicePreservesOnDiskVersionAfterExternalWrite() async throws {
        let store = StateStore()
        try store.set(.profile, value: #"{"name":"before","version":1}"#)

        let url = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("profile.json")
        let external = ProfileDocument(name: "external", version: 99)
        try JSONEncoder().encode(external).write(to: url)

        try store.set(.profileName, value: "after")
        let onDisk = try StateStore.readProfileFromDisk()
        XCTAssertEqual(onDisk.name, "after")
        XCTAssertEqual(onDisk.version, 99)
    }

    @MainActor
    func testSecretEncryptedStoreRoundTrip() async throws {
        let store = StateStore()
        try store.set(.secret, value: "top-secret")
        XCTAssertEqual(store.get(.secret), "top-secret")

        try store.set(.secret, value: "rotated")
        XCTAssertEqual(store.get(.secret), "rotated")

        let path = FileManager.defaultFileStatePath
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: URL(fileURLWithPath: path).appendingPathComponent("secret.enc").path
        ))
    }

    @MainActor
    func testSecretResetDeletesStoreFile() async throws {
        let store = StateStore()
        try store.set(.secret, value: "ephemeral")
        let path = FileManager.defaultFileStatePath
        let fileURL = URL(fileURLWithPath: path).appendingPathComponent("secret.enc")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        store.reset(.secret)
        XCTAssertEqual(store.get(.secret), "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    #if !os(Windows)
    @MainActor
    func testSecretKeyFilePermissionsAre0600() async throws {
        let path = FileManager.defaultFileStatePath
        // Ensure a fresh key file is generated (passphrase mode would skip it).
        unsetenv("APS_SECRET_PASSPHRASE")
        unsetenv("APS_SECRET_USE_PASSPHRASE")
        let store = StateStore()
        try store.set(.secret, value: "file-key-secret")

        let keyURL = URL(fileURLWithPath: path).appendingPathComponent("secret.key")
        let attributes = try FileManager.default.attributesOfItem(atPath: keyURL.path)
        XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o600)
    }
    #endif

    @MainActor
    func testSecretStoreCorruptEnvelopeThrowsDecodingFailed() async throws {
        let store = StateStore()
        try store.set(.secret, value: "ok")
        let path = FileManager.defaultFileStatePath
        let fileURL = URL(fileURLWithPath: path).appendingPathComponent("secret.enc")
        try "garbage{{".write(to: fileURL, atomically: false, encoding: .utf8)

        XCTAssertThrowsError(try StateStore.requireDecodableDiskState(for: .secret)) { error in
            XCTAssertEqual(error as? APSError, .decodingFailed)
        }
    }

    @MainActor
    func testSecretPersistsAcrossStateStoreInstances() async throws {
        let writer = StateStore()
        try writer.set(.secret, value: "shared-secret")

        let reader = StateStore()
        XCTAssertEqual(reader.get(.secret), "shared-secret")

        reader.reset(.secret)
        XCTAssertEqual(StateStore().get(.secret), "")
    }

#if !os(Windows)
    @MainActor
    func testSecretPassphraseRoundTripAndWrongKey() async throws {
        setenv("APS_SECRET_PASSPHRASE", "correct-horse", 1)
        defer { unsetenv("APS_SECRET_PASSPHRASE") }

        let store = StateStore()
        try store.set(.secret, value: "battery-staple")
        XCTAssertEqual(store.get(.secret), "battery-staple")

        setenv("APS_SECRET_PASSPHRASE", "wrong", 1)
        XCTAssertThrowsError(try StateStore.requireDecodableDiskState(for: .secret)) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }
    }
#endif

    @MainActor
    func testInvalidProfileJSON() async {
        let store = StateStore()
        do {
            try store.set(.profile, value: "not-json")
            XCTFail("Expected invalid value error")
        } catch let error as APSError {
            XCTAssertEqual(error, .invalidValue(key: "profile", value: "not-json"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testInvalidCounterValue() async {
        let store = StateStore()
        do {
            try store.set(.counter, value: "nope")
            XCTFail("Expected invalid value error")
        } catch let error as APSError {
            XCTAssertEqual(error, .invalidValue(key: "counter", value: "nope"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testDumpIncludesKeysAndUsesDependency() async throws {
        let store = StateStore()
        try store.set(.counter, value: "3")
        try store.set(.message, value: "hi")
        try store.set(.profile, value: #"{"name":"x","version":1}"#)

        let json = try store.dump()
        XCTAssertTrue(json.contains("\"key\":\"counter\""))
        XCTAssertTrue(json.contains("\"value\":3"))
        XCTAssertTrue(json.contains("\"key\":\"message\""))
        XCTAssertTrue(json.contains("\"key\":\"profile\""))
        XCTAssertTrue(json.contains("\"storage\":\"FileState\""))
        XCTAssertTrue(json.contains("timestamp"))
    }

    @MainActor
    func testJSONCodingDependency() async throws {
        let coding = Application.dependency(\.jsonCoding)
        let encoded = try coding.encodePretty(["ok": true])
        XCTAssertTrue(encoded.contains("true"))
    }

    @MainActor
    func testCLIOutputTypedValues() async throws {
        let store = StateStore()
        try store.set(.counter, value: "9")
        try store.set(.flag, value: "true")
        try store.set(.profile, value: #"{"name":"n","version":2}"#)

        XCTAssertEqual(try CLIOutput.typedValue(for: .counter, store: store), .int(9))
        XCTAssertEqual(try CLIOutput.typedValue(for: .flag, store: store), .bool(true))
        XCTAssertEqual(
            try CLIOutput.typedValue(for: .profile, store: store),
            .object(ProfileDocument(name: "n", version: 2))
        )

        let payload = CLIOutput.KeyValuePayload(
            key: "counter",
            type: "Int",
            storage: "State",
            value: .int(9)
        )
        let encoded = try CLIOutput.encodePretty(payload)
        XCTAssertTrue(encoded.contains("\"value\" : 9"))
    }

    @MainActor
    func testAPSPathsResolveOrder() async {
        let previous = ProcessInfo.processInfo.environment["APS_HOME"]
        defer {
            setProcessEnv("APS_HOME", previous)
        }

        setProcessEnv("APS_HOME", "/tmp/aps-from-env")
        XCTAssertEqual(APSPaths.resolve(stateDir: nil), "/tmp/aps-from-env")
        XCTAssertEqual(APSPaths.resolve(stateDir: "/tmp/aps-flag"), "/tmp/aps-flag")
        setProcessEnv("APS_HOME", nil)
        // Path-component check: Windows uses `\` separators, not a `/.aps` suffix.
        let defaultHome = APSPaths.resolve(stateDir: nil)
        XCTAssertEqual(URL(fileURLWithPath: defaultHome).lastPathComponent, ".aps")
    }

    @MainActor
    func testResetRestoresInitialValues() async throws {
        let store = StateStore()
        try store.set(.counter, value: "9")
        try store.set(.message, value: "x")
        try store.set(.flag, value: "true")
        try store.set(.note, value: "n")
        try store.set(.profile, value: #"{"name":"z","version":9}"#)

        store.reset(.counter)
        store.reset(.message)
        store.reset(.flag)
        store.reset(.note)
        store.reset(.profile)

        XCTAssertEqual(store.get(.counter), "0")
        XCTAssertEqual(store.get(.message), "")
        XCTAssertEqual(store.get(.flag), "false")
        XCTAssertEqual(store.get(.note), "")
        XCTAssertEqual(try store.profileDocument(), ProfileDocument())
    }

    @MainActor
    func testResetAll() async throws {
        let store = StateStore()
        try store.set(.counter, value: "5")
        try store.set(.note, value: "keep?")
        try store.set(.profile, value: #"{"name":"p","version":1}"#)
        store.resetAll()
        XCTAssertEqual(store.get(.counter), "0")
        XCTAssertEqual(store.get(.note), "")
        XCTAssertEqual(try store.profileDocument(), ProfileDocument())
    }

    @MainActor
    func testWatchDetectsInProcessStateChange() async throws {
        let store = StateStore()
        try store.set(.counter, value: "1")

        var seen: [String] = []
        try store.watchBlocking(
            .counter,
            pollInterval: 0.05,
            shouldContinue: { seen.count < 2 }
        ) { value in
            seen.append(value)
            if value == "1" {
                try? store.set(.counter, value: "2")
            }
        }

        XCTAssertEqual(seen, ["1", "2"])
    }

    @MainActor
    func testWatchDetectsFileStateChange() async throws {
        let store = StateStore()
        try store.set(.note, value: "before")

        var seen: [String] = []
        try store.watchBlocking(
            .note,
            pollInterval: 0.05,
            shouldContinue: { seen.count < 2 }
        ) { value in
            seen.append(value)
            if value == "before" {
                try? store.set(.note, value: "after")
            }
        }

        XCTAssertEqual(seen, ["before", "after"])
    }

    @MainActor
    func testWatchDetectsExternalFileStateWrite() async throws {
        // Simulate another process: write note.json without updating AppState's cache.
        let store = StateStore()
        try store.set(.note, value: "before")
        let path = FileManager.defaultFileStatePath

        var seen: [String] = []
        try store.watchBlocking(
            .note,
            pollInterval: 0.05,
            shouldContinue: { seen.count < 2 }
        ) { value in
            seen.append(value)
            if value == "before" {
                // Same on-disk format AppState uses for non-Base64 FileState.
                let data = try? JSONEncoder().encode("changed")
                let url = URL(fileURLWithPath: path).appendingPathComponent("note.json")
                try? data?.write(to: url)
            }
        }

        XCTAssertEqual(seen, ["before", "changed"])
    }

    @MainActor
    func testWatchJSONLEventUsesFreshDiskValue() async throws {
        // Mirrors the CLI --jsonl path: build events from the onChange string,
        // not from store.get (which can hit a stale FileState cache).
        let store = StateStore()
        try store.set(.profile, value: #"{"name":"before","version":3}"#)
        let path = FileManager.defaultFileStatePath

        var events: [CLIOutput.WatchEvent] = []
        try store.watchBlocking(
            .profile,
            pollInterval: 0.05,
            shouldContinue: { events.count < 2 }
        ) { value in
            let event = try! CLIOutput.watchEvent(
                key: .profile,
                rawValue: value,
                timestamp: store.now
            )
            events.append(event)
            if events.count == 1 {
                let changed = ProfileDocument(name: "leif", version: 4)
                let data = try? JSONEncoder().encode(changed)
                let url = URL(fileURLWithPath: path).appendingPathComponent("profile.json")
                try? data?.write(to: url)
            }
        }

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].value, .object(ProfileDocument(name: "before", version: 3)))
        XCTAssertEqual(events[1].value, .object(ProfileDocument(name: "leif", version: 4)))
    }

    @MainActor
    func testReadNoteFromDiskIfPresentMissingIsNil() async throws {
        // setUp resets FileState, which may write the initial value to disk.
        let url = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("note.json")
        try? FileManager.default.removeItem(at: url)
        XCTAssertNil(try StateStore.readNoteFromDiskIfPresent())
    }

    @MainActor
    func testReadNoteFromDiskRejectsTornFile() async throws {
        let store = StateStore()
        try store.set(.note, value: "ok")
        let url = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("note.json")
        try Data("{not-json".utf8).write(to: url)

        XCTAssertThrowsError(try StateStore.readNoteFromDiskIfPresent()) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: "note"))
        }
        // Must not silently fall back to AppState initial via get().
        XCTAssertEqual(store.get(.note), "ok")
        XCTAssertThrowsError(try StateStore.requireDecodableDiskState(for: .note)) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: "note"))
        }
    }

    @MainActor
    func testWatchSurfacesTornNoteFileAsCorruptState() async throws {
        let store = StateStore()
        try store.set(.note, value: "before")
        let path = FileManager.defaultFileStatePath

        var seen: [String] = []
        XCTAssertThrowsError(
            try store.watchBlocking(
                .note,
                pollInterval: 0.05,
                shouldContinue: { seen.count < 3 }
            ) { value in
                seen.append(value)
                if value == "before" {
                    let url = URL(fileURLWithPath: path).appendingPathComponent("note.json")
                    try? Data("<<<torn>>>".utf8).write(to: url)
                }
            }
        ) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: "note"))
        }
        XCTAssertEqual(seen, ["before"])
    }

    @MainActor
    func testReadProfileFromDiskRejectsTornFile() async throws {
        let store = StateStore()
        try store.set(.profile, value: #"{"name":"ok","version":1}"#)
        let url = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("profile.json")
        try Data("{".utf8).write(to: url)

        XCTAssertThrowsError(try StateStore.readProfileFromDiskIfPresent()) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: "profile"))
        }
        XCTAssertEqual(APSError.corruptStateExitCode, 65)
    }

    func testTypedValueFromRawStringDoesNotNeedStore() throws {
        XCTAssertEqual(try CLIOutput.typedValue(for: .counter, from: "42"), .int(42))
        XCTAssertEqual(try CLIOutput.typedValue(for: .flag, from: "true"), .bool(true))
        XCTAssertEqual(try CLIOutput.typedValue(for: .note, from: "hi"), .string("hi"))
        XCTAssertEqual(
            try CLIOutput.typedValue(for: .profile, from: #"{"name":"a","version":2}"#),
            .object(ProfileDocument(name: "a", version: 2))
        )
    }

    @MainActor
    func testWatchCountBoundStopsLoop() async throws {
        let store = StateStore()
        try store.set(.counter, value: "1")
        var seen: [String] = []
        let limit = 1
        try store.watchBlocking(
            .counter,
            pollInterval: 0.05,
            shouldContinue: { seen.count < limit }
        ) { value in
            seen.append(value)
            try? store.set(.counter, value: "99")
        }
        XCTAssertEqual(seen.count, 1)
        XCTAssertEqual(seen.first, "1")
    }

    @MainActor
    internal func testWatchCancellationStopsPollingWithoutRunLoopTimeout() async throws {
        let store = StateStore()
        var shouldPoll = true
        var seen: [String] = []

        try store.watchBlocking(
            .counter,
            pollInterval: 0.05,
            shouldContinue: { shouldPoll }
        ) { value in
            seen.append(value)
            shouldPoll = false
        }

        XCTAssertEqual(seen, ["0"])
    }

    @MainActor
    internal func testWatchTimeoutStopsAfterDeadline() async throws {
        let store = StateStore()
        let deadline = Date().addingTimeInterval(0.1)
        var seen: [String] = []

        try store.watchBlocking(
            .counter,
            pollInterval: 0.05,
            shouldContinue: { Date() < deadline }
        ) { value in
            seen.append(value)
        }

        XCTAssertEqual(seen, ["0"])
        XCTAssertGreaterThanOrEqual(Date(), deadline)
    }

    internal func testWatchPollingCapsLargeIntervals() {
        let startedAt = Date()
        waitForWatchPoll(interval: 1.0)

        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 0.5)
    }

    @MainActor
    func testNoteUsesInjectedFileStatePath() async throws {
        let path = FileManager.defaultFileStatePath
        XCTAssertTrue(path.contains("aps-tests-"), "setUp must inject a temp FileState path")

        let store = StateStore()
        try store.set(.note, value: "isolated")

        let fileURL = URL(fileURLWithPath: path).appendingPathComponent("note.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let homeNote = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aps/note.json")
        // Do not require ~/.aps to be absent globally; just ensure this write landed in temp.
        XCTAssertNotEqual(fileURL.path, homeNote.path)
        XCTAssertEqual(try StateStore.readNoteFromDisk(), "isolated")
    }

    @MainActor
    func testClockDependencyIsInjectable() async throws {
        let clock = Application.dependency(\.clock)
        let before = clock.now
        XCTAssertLessThanOrEqual(before.timeIntervalSinceNow, 0)
    }

    @MainActor
    // REQ-state-store-012
    func testStatsObservedDependencyRecordsMutations() async throws {
        let store = StateStore()
        XCTAssertEqual(store.statsSnapshot().mutationCount, 0)
        XCTAssertEqual(store.statsSnapshot().lastMutatedKey, "")

        try store.set(.counter, value: "1")
        XCTAssertEqual(store.statsSnapshot().mutationCount, 1)
        XCTAssertEqual(store.statsSnapshot().lastMutatedKey, "counter")

        try store.set(.message, value: "hi")
        XCTAssertEqual(store.statsSnapshot().mutationCount, 2)
        XCTAssertEqual(store.statsSnapshot().lastMutatedKey, "message")
    }

    #if !os(Linux) && !os(Windows)
    @MainActor
    func testObservedDependencyFiresOnMutation() async throws {
        Application.load(dependency: \.stats)
        Application.dependency(\.stats).reset()

        let consumer = ObservedStatsConsumer()
        XCTAssertEqual(consumer.stats.mutationCount, 0)

        var observedCounts: [Int] = []
        let cancellable = consumer.stats.$mutationCount.sink { value in
            observedCounts.append(value)
        }
        defer { _ = cancellable }

        let store = StateStore()
        try store.set(.flag, value: "true")

        XCTAssertEqual(consumer.stats.mutationCount, 1)
        XCTAssertEqual(consumer.stats.lastMutatedKey, "flag")
        // Combine publishes the initial value plus the mutation.
        XCTAssertTrue(observedCounts.contains(1), "Expected $mutationCount to publish 1, got \(observedCounts)")
    }
    #endif

    @MainActor
    // REQ-aps-cli-014
    func testWatchStatsDetectsDependencyMutation() async throws {
        let store = StateStore()
        store.resetStats()

        var seen: [DemoStatsSnapshot] = []
        store.watchStatsBlocking(
            pollInterval: 0.05,
            shouldContinue: { seen.count < 2 }
        ) { snapshot in
            seen.append(snapshot)
            if snapshot.mutationCount == 0 {
                try? store.set(.counter, value: "9")
            }
        }

        XCTAssertEqual(seen.count, 2)
        XCTAssertEqual(seen[0].mutationCount, 0)
        XCTAssertEqual(seen[1].mutationCount, 1)
        XCTAssertEqual(seen[1].lastMutatedKey, "counter")
    }

    @MainActor
    func testInvalidFlagValue() async {
        let store = StateStore()
        do {
            try store.set(.flag, value: "maybe")
            XCTFail("Expected invalid value error")
        } catch let error as APSError {
            XCTAssertEqual(error, .invalidValue(key: "flag", value: "maybe"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testFlagPersistsAcrossStateStoreInstances() async throws {
        let writer = StateStore()
        try writer.set(.flag, value: "true")
        XCTAssertEqual(writer.get(.flag), "true")

        let reader = StateStore()
        XCTAssertEqual(reader.get(.flag), "true")

        reader.reset(.flag)
        XCTAssertEqual(StateStore().get(.flag), "false")
    }

    @MainActor
    func testUserDefaultsStandardIsHermetic() async throws {
        // StoredState must use the per-test InMemoryUserDefaults override, not
        // UserDefaults.standard (App/aps.flag is the AppState StoredState key).
        let store = StateStore()
        try store.set(.flag, value: "true")
        XCTAssertEqual(store.get(.flag), "true")

        XCTAssertNil(
            UserDefaults.standard.object(forKey: "App/aps.flag"),
            "flag round-trip must not pollute UserDefaults.standard"
        )
        XCTAssertTrue(
            hermeticDefaults?.keys.contains("App/aps.flag") == true,
            "expected App/aps.flag in the hermetic suite, got \(hermeticDefaults?.keys ?? [])"
        )

        store.reset(.flag)
        XCTAssertEqual(store.get(.flag), "false")
        XCTAssertNil(UserDefaults.standard.object(forKey: "App/aps.flag"))
    }

    @MainActor
    func testIsolationStartsWithCleanDemoState() async throws {
        let store = StateStore()
        XCTAssertEqual(store.get(.counter), "0")
        XCTAssertEqual(store.get(.message), "")
        XCTAssertEqual(store.get(.flag), "false")
        XCTAssertEqual(store.statsSnapshot().mutationCount, 0)
        XCTAssertTrue(
            FileManager.defaultFileStatePath.contains("aps-tests-"),
            "setUp must inject a temp FileState path"
        )
    }

    @MainActor
    func testProcessLocalStateKeysDoNotClaimCrossProcessPersistence() async throws {
        // Document the contract: State keys are process-local. A fresh Application
        // reset (as in setUp) restores initials; this test locks that expectation.
        let store = StateStore()
        try store.set(.counter, value: "99")
        try store.set(.message, value: "ephemeral")
        XCTAssertEqual(store.get(.counter), "99")
        XCTAssertEqual(store.get(.message), "ephemeral")

        Application.reset(\.counter)
        Application.reset(\.message)
        XCTAssertEqual(store.get(.counter), "0")
        XCTAssertEqual(store.get(.message), "")
    }

    func testDemoKeyHelpSummaryFormat() {
        for key in DemoKey.allCases {
            let parts = key.helpSummary.split(separator: "\t")
            XCTAssertEqual(parts.count, 3, "Expected key/type/storage columns for \(key)")
            XCTAssertEqual(String(parts[0]), key.rawValue)
            XCTAssertFalse(key.detail.isEmpty)
        }
    }

    func testAPSErrorDescriptionsAreActionable() {
        let invalid = APSError.invalidValue(key: "counter", value: "nope")
        XCTAssertTrue(invalid.description.contains("counter"))
        XCTAssertTrue(invalid.description.contains("nope"))

        let persistence = APSError.persistenceFailed(key: "note")
        XCTAssertTrue(persistence.description.contains("note"))
        XCTAssertTrue(persistence.description.contains("persist"))

        let corrupt = APSError.corruptState(key: "note")
        XCTAssertTrue(corrupt.description.contains("note"))
        XCTAssertTrue(corrupt.description.contains("torn") || corrupt.description.contains("Corrupt"))
        XCTAssertEqual(APSError.corruptStateExitCode, 65)
    }

    func testAPSErrorContractCodesAndExitCodes() {
        XCTAssertEqual(APSError.invalidValue(key: "counter", value: "x").code, "invalid_value")
        XCTAssertEqual(APSError.encodingFailed.code, "encoding_failed")
        XCTAssertEqual(APSError.decodingFailed.code, "decoding_failed")
        XCTAssertEqual(APSError.persistenceFailed(key: "note").code, "persistence_failed")
        XCTAssertEqual(APSError.secretUnlockFailed.code, "secret_unlock_failed")
        XCTAssertEqual(APSError.corruptState(key: "note").code, "corrupt_state")

        XCTAssertEqual(APSError.invalidValue(key: "counter", value: "x").exitCode, 64)
        XCTAssertEqual(APSError.decodingFailed.exitCode, 65)
        XCTAssertEqual(APSError.corruptState(key: "note").exitCode, 65)
        XCTAssertEqual(APSError.secretUnlockFailed.exitCode, 69)
        XCTAssertEqual(APSError.encodingFailed.exitCode, 70)
        XCTAssertEqual(APSError.persistenceFailed(key: "note").exitCode, 73)

        for error in [APSError.invalidValue(key: "flag", value: "x"), .encodingFailed, .decodingFailed, .persistenceFailed(key: "flag"), .secretUnlockFailed, .corruptState(key: "profile")] as [APSError] {
            XCTAssertFalse(error.hint.isEmpty, "hint required for \(error.code)")
        }
    }

    func testErrorEnvelopeEncodesStableShape() throws {
        let envelope = CLIOutput.ErrorEnvelope(
            error: .init(
                code: APSError.corruptState(key: "note").code,
                message: APSError.corruptState(key: "note").description,
                hint: APSError.corruptState(key: "note").hint
            )
        )
        let line = try CLIOutput.encodeLine(envelope)
        XCTAssertTrue(line.contains(#""code":"corrupt_state""#))
        XCTAssertTrue(line.contains(#""message":"#))
        XCTAssertTrue(line.contains(#""hint":"#))
        XCTAssertTrue(line.hasPrefix(#"{"error":{"#))
    }

    func testStructuredErrorsEnabledModes() {
        XCTAssertTrue(CLIOutput.structuredErrorsEnabled(json: true))
        let env = ProcessInfo.processInfo.environment["APS_ERROR_JSON"]
        XCTAssertEqual(CLIOutput.structuredErrorsEnabled(json: false), env == "1")
    }

    @MainActor
    func testRequireDecodableDiskStateCorruptThrows() async throws {
        let store = StateStore()
        try store.set(.note, value: "ok")

        let path = FileManager.defaultFileStatePath
        let url = URL(fileURLWithPath: path).appendingPathComponent("note.json")
        try "garbage{{".write(to: url, atomically: false, encoding: .utf8)

        XCTAssertThrowsError(try StateStore.requireDecodableDiskState(for: .note)) { error in
            guard case .corruptState = (error as? APSError) else {
                return XCTFail("expected corruptState, got \(error)")
            }
            XCTAssertEqual((error as? APSError)?.exitCode, 65)
        }
    }

    func testTTYTableAlignsColumnsAndBoldsHeader() {
        let table = TTY.table(
            header: ["KEY", "TYPE", "STORAGE"],
            rows: [
                ["counter", "Int", "State"],
                ["profileName", "String", "Slice"],
            ]
        )
        let lines = table.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 3)
        // Column 2 starts at the same offset on every line (widest KEY + 2).
        let columnTwoOffset = max("KEY".count, "counter".count, "profileName".count) + 2
        let expected = [
            "TYPE",
            "Int",
            "String",
        ]
        for (line, word) in zip(lines, expected) {
            let index = line.range(of: word)?.lowerBound
            XCTAssertEqual(index.map { line.distance(from: line.startIndex, to: $0) }, columnTwoOffset)
        }
        // Piped test environment: no ANSI escapes are emitted.
        XCTAssertFalse(table.contains("\u{1B}"), "no ANSI when color is disabled")
    }

    func testStyleIsIdentityWhenColorDisabled() {
        XCTAssertEqual(TTY.Style.red("err"), "err")
        XCTAssertEqual(TTY.Style.bold("h"), "h")
    }

    func testEncodeJSONIsCompactOffTTY() throws {
        let payload = CLIOutput.KeyInfo(key: "counter", type: "Int", storage: "State", detail: "d")
        let json = try CLIOutput.encodeJSON(payload)
        XCTAssertFalse(json.contains("\n"), "piped JSON must be compact single-line")
        XCTAssertTrue(json.contains("\"key\":\"counter\""))
    }

    func testEncodeAutoIsCompactOffTTY() throws {
        let coding = JSONCoding()
        let json = try coding.encodeAuto(["ok": true])
        XCTAssertFalse(json.contains("\n"))
        XCTAssertTrue(json.contains("\"ok\":true"))
    }

    func testStopReasonTokensAndExitCodes() {
        XCTAssertEqual(StopReason.count.token, "count")
        XCTAssertEqual(StopReason.timeout.token, "timeout")
        XCTAssertEqual(StopReason.signal(SIGINT).token, "sigint")
        XCTAssertEqual(StopReason.signal(SIGTERM).token, "sigterm")
        XCTAssertEqual(StopReason.signal(20).token, "signal")

        XCTAssertEqual(StopReason.count.exitCode, 0)
        XCTAssertEqual(StopReason.timeout.exitCode, 124)
        XCTAssertEqual(StopReason.signal(SIGINT).exitCode, 130)
        XCTAssertEqual(StopReason.signal(SIGTERM).exitCode, 143)

        XCTAssertEqual(StopReason.count.summary, "count reached")
        XCTAssertEqual(StopReason.signal(SIGINT).summary, "interrupted (SIGINT)")
        XCTAssertEqual(StopReason.signal(SIGTERM).summary, "terminated (SIGTERM)")
    }

    func testWatchEndEventEncodesTerminalMarker() throws {
        let event = CLIOutput.WatchEndEvent(
            key: "counter",
            reason: StopReason.timeout.token,
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let line = try CLIOutput.encodeLine(event)
        XCTAssertTrue(line.contains(#""type":"end""#))
        XCTAssertTrue(line.contains(#""reason":"timeout""#))
        XCTAssertTrue(line.contains(#""key":"counter""#))
    }

    func testSchemaDocumentCoversAllKeysAndCommands() throws {
        let document = Schema.staticDocument()

        XCTAssertEqual(document.schemaVersion, 4)
        XCTAssertEqual(document.cliVersion, "1.0.0")
        XCTAssertEqual(document.keys.map(\.name), DemoKey.allCases.map(\.rawValue))
        XCTAssertEqual(document.stateRoot.precedence, ["--state-dir", "APS_HOME", "~/.aps"])

        let commandNames = document.commands.map(\.name)
        for expected in ["get", "set", "watch", "dump", "keys", "key", "reset", "stats", "schema"] {
            XCTAssertTrue(commandNames.contains(expected), "missing command \(expected)")
        }
        let reset = document.commands.first { $0.name == "reset" }
        XCTAssertTrue(reset?.flags.contains("--registered") == true)

        let secret = document.keys.first { $0.name == "secret" }
        XCTAssertEqual(secret?.path, "<state-root>/secret.enc")
        XCTAssertNil(secret?.keychainAccount)
        let note = document.keys.first { $0.name == "note" }
        XCTAssertEqual(note?.path, "<state-root>/note.json")
    }

    func testSchemaErrorTableIsStable() {
        let table = Schema.staticDocument().errors
        XCTAssertEqual(table.count, 9)
        let byCode = Dictionary(uniqueKeysWithValues: table.map { ($0.code, $0.exitCode) })
        XCTAssertEqual(byCode["invalid_value"], 64)
        XCTAssertEqual(byCode["decoding_failed"], 65)
        XCTAssertEqual(byCode["corrupt_state"], 65)
        XCTAssertEqual(byCode["secret_unlock_failed"], 69)
        XCTAssertEqual(byCode["encoding_failed"], 70)
        XCTAssertEqual(byCode["persistence_failed"], 73)
        XCTAssertEqual(byCode["unknown_key"], 64)
        XCTAssertEqual(byCode["schema_conflict"], 64)
        XCTAssertEqual(byCode["schema_invalid"], 65)
        for entry in table {
            XCTAssertFalse(entry.hint.isEmpty, "hint required for \(entry.code)")
            XCTAssertFalse(entry.meaning.isEmpty, "meaning required for \(entry.code)")
        }
    }

    func testSchemaDocumentEncodesValidContractJSON() throws {
        let json = try CLIOutput.encodePretty(Schema.staticDocument())
        let data = try XCTUnwrap(json.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["schemaVersion"] as? Int, 4)
        let payloads = try XCTUnwrap(object?["payloads"] as? [String: Any])
        for name in ["KeyValuePayload", "KeysPayload", "WatchEvent", "WatchErrorEvent", "WatchEndEvent", "ResetPayload", "StatsPayload", "ErrorEnvelope"] {
            XCTAssertNotNil(payloads[name], "missing payload schema \(name)")
        }
        let event = try XCTUnwrap(payloads["WatchEvent"] as? [String: Any])
        XCTAssertEqual(event["type"] as? String, "object")
        XCTAssertNotNil(event["properties"])
        XCTAssertNotNil(event["required"])
    }

    func testUserSchemaMaterializeAndKeyAdd() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("aps-schema-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            FileManager.defaultFileStatePath = root.path
            let store = StateStore()
            let schema = try store.loadSchema()
            XCTAssertEqual(schema.keys.count, 7)
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("schema.json").path))
            try store.addKey(
                SchemaKeyEntry(
                    name: "agentNote",
                    type: "String",
                    storage: "FileState",
                    initial: .string(""),
                    path: "agent-note.json",
                    doc: "user file key"
                ),
                force: false
            )
            try store.set(name: "agentNote", value: "hello-agent")
            XCTAssertEqual(try store.get(name: "agentNote"), "hello-agent")
            let doc = try Schema.document(stateDir: root.path)
            XCTAssertTrue(doc.keys.map(\.name).contains("agentNote"))
            XCTAssertFalse(doc.userSchema.hash.isEmpty)
        }
    }

    func testUnknownKeyError() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("aps-unknown-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            FileManager.defaultFileStatePath = root.path
            let store = StateStore()
            _ = try store.loadSchema()
            XCTAssertThrowsError(try store.get(name: "nope")) { error in
                XCTAssertEqual(error as? APSError, .unknownKey(name: "nope"))
            }
        }
    }

    func testPeelRootStateDirBeforeSubcommand() {
        var args = ["--state-dir", "/tmp/aps-root", "get", "note"]
        let peeled = APSPaths.peelRootStateDir(from: &args)
        XCTAssertEqual(peeled, "/tmp/aps-root")
        XCTAssertEqual(args, ["get", "note"])

        var equals = ["--state-dir=/tmp/eq", "dump"]
        XCTAssertEqual(APSPaths.peelRootStateDir(from: &equals), "/tmp/eq")
        XCTAssertEqual(equals, ["dump"])

        var after = ["get", "note", "--state-dir", "/tmp/late"]
        XCTAssertNil(APSPaths.peelRootStateDir(from: &after))
        XCTAssertEqual(after, ["get", "note", "--state-dir", "/tmp/late"])
    }

#if !os(Windows)
    @MainActor
    func testSecretSetRequiresUnlockBeforeRewrite() async throws {
        setenv("APS_SECRET_PASSPHRASE", "alpha", 1)
        defer {
            unsetenv("APS_SECRET_PASSPHRASE")
        }

        let path = FileManager.defaultFileStatePath
        let store = SecretStore(directory: path)
        try store.set("owned-by-alpha")
        let url = URL(fileURLWithPath: path).appendingPathComponent("secret.enc")
        let before = try Data(contentsOf: url)

        setenv("APS_SECRET_PASSPHRASE", "beta", 1)
        XCTAssertThrowsError(try store.set("stolen-by-beta")) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }
        let after = try Data(contentsOf: url)
        XCTAssertEqual(before, after)

        setenv("APS_SECRET_PASSPHRASE", "alpha", 1)
        XCTAssertEqual(try store.get(), "owned-by-alpha")
        store.reset()
    }
#endif

    @MainActor
    func testResetAllLeavesUserKeysResetRegisteredClearsThem() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-reset-scope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        FileManager.defaultFileStatePath = root.path

        let store = StateStore()
        try store.addKey(
            SchemaKeyEntry(
                name: "agentStatus",
                type: "String",
                storage: "FileState",
                initial: .string(""),
                path: "agent-status.json",
                doc: "agent key"
            ),
            force: false
        )
        try store.set(name: "agentStatus", value: "exploring")
        try store.set(.flag, value: "true")

        store.resetAll()
        XCTAssertEqual(store.get(.flag), "false")
        XCTAssertEqual(try store.get(name: "agentStatus"), "exploring")

        try store.resetAllRegistered()
        XCTAssertEqual(try store.get(name: "agentStatus"), "")
    }

    func testParallelSchemaAddsUnderLockRetainAllKeys() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-schema-lock-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let schemaURL = UserSchema.schemaURL(stateRoot: root.path)
        try UserSchema.write(UserSchema.defaultDocument(), to: schemaURL)

        final class FailureBox: @unchecked Sendable {
            private let lock = NSLock()
            private var values: [String] = []
            func append(_ value: String) {
                lock.lock()
                values.append(value)
                lock.unlock()
            }
            var snapshot: [String] {
                lock.lock()
                defer { lock.unlock() }
                return values
            }
        }

        let group = DispatchGroup()
        let failures = FailureBox()
        let count = 16
        for index in 0..<count {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                defer { group.leave() }
                do {
                    try SchemaFileLock.withExclusiveLock(stateRoot: root.path) {
                        var document = try UserSchema.loadUnlocked(stateRoot: root.path)
                        document.keys.append(
                            SchemaKeyEntry(
                                name: "race\(index)",
                                type: "String",
                                storage: "FileState",
                                initial: .string(""),
                                path: "race-\(index).json",
                                doc: "race"
                            )
                        )
                        try UserSchema.write(document, to: schemaURL)
                    }
                } catch {
                    failures.append("\(error)")
                }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 30), .success)
        let failureList = failures.snapshot
        XCTAssertTrue(failureList.isEmpty, failureList.joined(separator: "; "))

        let final = try UserSchema.load(from: schemaURL)
        let raceNames = Set(final.keys.map(\.name).filter { $0.hasPrefix("race") })
        XCTAssertEqual(raceNames.count, count)
    }

    private final class MockUserDefaults: UserDefaultsManaging, @unchecked Sendable {
        var storage: [String: Any] = [:]
        func object(forKey key: String) -> Any? { storage[key] }
        func removeObject(forKey key: String) { storage.removeValue(forKey: key) }
        func set(_ value: Any?, forKey key: String) { storage[key] = value }
    }

    @MainActor
    func testDynamicKeyStorageStoredStateUsesUserDefaultsDependency() async throws {
        let mockDefaults = MockUserDefaults()
        let overrideToken = Application.override(\Application.userDefaults, with: mockDefaults)
        defer { _ = overrideToken }

        let entry = SchemaKeyEntry(
            name: "testStoredStateKey",
            type: "String",
            storage: "StoredState",
            initial: .string("initial_val"),
            path: nil,
            doc: "test stored state"
        )
        let schema = UserSchemaDocument(keys: [entry])

        let initialVal = try DynamicKeyStorage.get(entry: entry, stateRoot: "/tmp", schema: schema)
        XCTAssertEqual(initialVal, "initial_val")

        try DynamicKeyStorage.set(entry: entry, value: "new_val", stateRoot: "/tmp", schema: schema)
        let currentVal = try DynamicKeyStorage.get(entry: entry, stateRoot: "/tmp", schema: schema)
        XCTAssertEqual(currentVal, "new_val")

        XCTAssertEqual(mockDefaults.object(forKey: "aps.user.testStoredStateKey") as? String, "new_val")
        XCTAssertNil(UserDefaults.standard.object(forKey: "aps.user.testStoredStateKey"))

        try DynamicKeyStorage.reset(entry: entry, stateRoot: "/tmp", schema: schema)
        XCTAssertEqual(mockDefaults.object(forKey: "aps.user.testStoredStateKey") as? String, "initial_val")
    }

}
