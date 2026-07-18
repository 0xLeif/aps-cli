import AppState
#if canImport(Combine)
import Combine
#endif
import Foundation
import XCTest
@testable import aps

#if !os(Linux) && !os(Windows)
/// Local consumer that dogfoods `@ObservedDependency` the same way AppState's own tests do.
@MainActor
private struct ObservedStatsConsumer {
    @ObservedDependency(\.stats) var stats: DemoStats
}
#endif

final class APSTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()

        await MainActor.run {
            Application.logging(isEnabled: false)

            // Isolate FileState under a unique temp directory for this test run.
            let path = FileManager.default.temporaryDirectory
                .appendingPathComponent("aps-tests-\(UUID().uuidString)", isDirectory: true)
                .path
            FileManager.defaultFileStatePath = path
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)

            Application.reset(\.counter)
            Application.reset(\.message)
            Application.reset(storedState: \.flag)
            Application.reset(fileState: \.note)
            Application.reset(fileState: \.profile)
            Application.dependency(\.stats).reset()
        }
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
        XCTAssertEqual(DemoKey.secret.storage, "SecureState")
        XCTAssertEqual(DemoKey.counter.valueType, "Int")
        XCTAssertEqual(DemoKey.profile.valueType, "ProfileDocument")
        XCTAssertEqual(DemoKey.secret.valueType, "String")
        XCTAssertEqual(DemoKey.allCases.count, 6)
        XCTAssertTrue(DemoKey.note.detail.contains("FileState"))
        XCTAssertTrue(DemoKey.profile.detail.contains("profile.json"))
        XCTAssertTrue(DemoKey.secret.detail.contains("Keychain"))
        XCTAssertEqual(APSKeychain.secretAccount, "dev.leif.aps/secret")
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


#if canImport(Security)
    @MainActor
    func testSecretSecureStateRoundTrip() async throws {
        let store = StateStore()
        try store.set(.secret, value: "top-secret")
        XCTAssertEqual(store.get(.secret), "top-secret")

        let keychain = Application.dependency(\.keychain)
        XCTAssertEqual(keychain.get(APSKeychain.secretAccount), "top-secret")

        try store.set(.secret, value: "rotated")
        XCTAssertEqual(store.get(.secret), "rotated")
        XCTAssertEqual(keychain.get(APSKeychain.secretAccount), "rotated")
    }

    @MainActor
    func testSecretResetDeletesKeychainItem() async throws {
        let store = StateStore()
        try store.set(.secret, value: "ephemeral")
        XCTAssertEqual(
            Application.dependency(\.keychain).get(APSKeychain.secretAccount),
            "ephemeral"
        )

        store.reset(.secret)
        XCTAssertEqual(store.get(.secret), "")
        XCTAssertNil(Application.dependency(\.keychain).get(APSKeychain.secretAccount))
    }

    @MainActor
    func testSecretPersistsAcrossStateStoreInstances() async throws {
        let writer = StateStore()
        try writer.set(.secret, value: "shared-secret")

        let reader = StateStore()
        XCTAssertEqual(reader.get(.secret), "shared-secret")

        reader.reset(.secret)
        XCTAssertEqual(StateStore().get(.secret), "")
        XCTAssertNil(Application.dependency(\.keychain).get(APSKeychain.secretAccount))
    }
#else
    @MainActor
    func testSecretSetFailsWithoutKeychain() async {
        let store = StateStore()
        do {
            try store.set(.secret, value: "nope")
            XCTFail("Expected keychainUnavailable on platforms without Security")
        } catch let error as APSError {
            XCTAssertEqual(error, .keychainUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(store.get(.secret), "")
    }
#endif

    @MainActor
    func testInvalidProfileJSON() async {
        let store = StateStore()
        do {
            try store.set(.profile, value: "not-json")
            XCTFail("Expected invalid value error")
        } catch let error as APSError {
            XCTAssertEqual(error, .invalidValue(key: .profile, value: "not-json"))
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
            XCTAssertEqual(error, .invalidValue(key: .counter, value: "nope"))
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
        XCTAssertTrue(json.contains("\"key\" : \"counter\""))
        XCTAssertTrue(json.contains("\"value\" : 3"))
        XCTAssertTrue(json.contains("\"key\" : \"message\""))
        XCTAssertTrue(json.contains("\"key\" : \"profile\""))
        XCTAssertTrue(json.contains("\"storage\" : \"FileState\""))
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
            if let previous {
                setenv("APS_HOME", previous, 1)
            } else {
                unsetenv("APS_HOME")
            }
        }

        setenv("APS_HOME", "/tmp/aps-from-env", 1)
        XCTAssertEqual(APSPaths.resolve(stateDir: nil), "/tmp/aps-from-env")
        XCTAssertEqual(APSPaths.resolve(stateDir: "/tmp/aps-flag"), "/tmp/aps-flag")
        unsetenv("APS_HOME")
        XCTAssertTrue(APSPaths.resolve(stateDir: nil).hasSuffix("/.aps"))
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
        store.watchBlocking(
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
        store.watchBlocking(
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
        store.watchBlocking(
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
        store.watchBlocking(
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
        store.watchBlocking(
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
            XCTAssertEqual(error, .invalidValue(key: .flag, value: "maybe"))
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
        let invalid = APSError.invalidValue(key: .counter, value: "nope")
        XCTAssertTrue(invalid.description.contains("counter"))
        XCTAssertTrue(invalid.description.contains("Int"))

        let unknown = APSError.unknownKey("wat")
        XCTAssertTrue(unknown.description.contains("wat"))
        XCTAssertTrue(unknown.description.contains("counter"))

        let persistence = APSError.persistenceFailed(key: .note)
        XCTAssertTrue(persistence.description.contains("note"))
        XCTAssertTrue(persistence.description.contains("persist"))
    }
}
