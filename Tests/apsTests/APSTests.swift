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

        _ = try store.reset(.secret)
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

    @MainActor
    func testSecretStoreParallelFreshWritesShareKeyFile() async throws {
        let path = FileManager.defaultFileStatePath
        let values = (0..<12).map { "parallel-secret-\($0)" }
        let failures = await withTaskGroup(of: String?.self, returning: [String].self) { group in
            values.forEach { value in
                group.addTask {
                    do {
                        try SecretStore(directory: path).set(value)
                        return nil
                    } catch {
                        return String(describing: error)
                    }
                }
            }

            var failures: [String] = []
            for await failure in group {
                if let failure {
                    failures.append(failure)
                }
            }
            return failures
        }

        XCTAssertTrue(failures.isEmpty, "Parallel fresh writes failed: \(failures)")
        let finalValue = try SecretStore(directory: path).get()
        XCTAssertTrue(values.contains(finalValue))
    }

    @MainActor
    func testSecretStoreFreshSetPreservesInvalidKeyWithoutEnvelope() async throws {
        let path = FileManager.defaultFileStatePath
        let keyURL = URL(fileURLWithPath: path).appendingPathComponent("secret.key")
        try Data("partial-key".utf8).write(to: keyURL)

        let store = SecretStore(directory: path)
        XCTAssertThrowsError(try store.set("recovered-secret")) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "secret"))
        }
        XCTAssertEqual(try Data(contentsOf: keyURL), Data("partial-key".utf8))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: URL(fileURLWithPath: path).appendingPathComponent("secret.enc").path
            )
        )
    }

    @MainActor
    func testSecretStoreExistingEnvelopeWithInvalidKeyThrowsUnlockFailed() async throws {
        let path = FileManager.defaultFileStatePath
        let keyURL = URL(fileURLWithPath: path).appendingPathComponent("secret.key")
        let envelopeURL = URL(fileURLWithPath: path).appendingPathComponent("secret.enc")
        let store = SecretStore(directory: path)
        try store.set("existing-secret")
        let originalEnvelope = try Data(contentsOf: envelopeURL)
        try Data("partial-key".utf8).write(to: keyURL)

        XCTAssertThrowsError(try store.get()) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }
        XCTAssertThrowsError(try store.set("replacement-secret")) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }
        XCTAssertEqual(try Data(contentsOf: envelopeURL), originalEnvelope)
        // Unlock must not truncate/replace the corrupt key path.
        XCTAssertEqual(try Data(contentsOf: keyURL), Data("partial-key".utf8))
    }

    @MainActor
    func testSecretStoreExistingEnvelopeWithMissingKeyDoesNotCreateReplacement() async throws {
        let path = FileManager.defaultFileStatePath
        let keyURL = URL(fileURLWithPath: path).appendingPathComponent("secret.key")
        let envelopeURL = URL(fileURLWithPath: path).appendingPathComponent("secret.enc")
        let store = SecretStore(directory: path)
        try store.set("existing-secret")
        let originalEnvelope = try Data(contentsOf: envelopeURL)
        try FileManager.default.removeItem(at: keyURL)

        XCTAssertThrowsError(try store.get()) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }
        XCTAssertThrowsError(try store.set("replacement-secret")) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }
        XCTAssertEqual(try Data(contentsOf: envelopeURL), originalEnvelope)
        XCTAssertFalse(FileManager.default.fileExists(atPath: keyURL.path))
    }

    @MainActor
    func testSecretStoreFreshKeyCreationRejectsNonRegularPath() async throws {
        let path = FileManager.defaultFileStatePath
        let keyURL = URL(fileURLWithPath: path).appendingPathComponent("secret.key")
        // Non-regular paths are security-policy failures and must remain unchanged.
        try FileManager.default.createDirectory(at: keyURL, withIntermediateDirectories: false)

        XCTAssertThrowsError(try SecretStore(directory: path).set("blocked-key-create")) { error in
            XCTAssertEqual(
                error as? APSError,
                .insecureSecretKeyFile(reason: "path is not a regular file")
            )
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: URL(fileURLWithPath: path).appendingPathComponent("secret.enc").path
            )
        )
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: keyURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    @MainActor
    func testSecretStoreEmptyPassphrasePromptFallbackPreservesStaleKey() async throws {
        let path = FileManager.defaultFileStatePath
        let keyURL = URL(fileURLWithPath: path).appendingPathComponent("secret.key")
        try Data("partial-key".utf8).write(to: keyURL)
        // Simulate APS_SECRET_USE_PASSPHRASE without a successful prompt by leaving
        // stdin closed: promptPassphrase returns nil and falls back to key-file mode.
        setProcessEnv("APS_SECRET_USE_PASSPHRASE", "1")
        defer { setProcessEnv("APS_SECRET_USE_PASSPHRASE", nil) }

        // When stderr is not a TTY, key-file mode is selected. Invalid key
        // bytes remain available for explicit user recovery.
        let store = SecretStore(directory: path)
        XCTAssertThrowsError(try store.set("fallback-recovered")) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "secret"))
        }
        XCTAssertEqual(try Data(contentsOf: keyURL), Data("partial-key".utf8))
    }

    @MainActor
    func testSecretStoreFreshSetDoesNotRemoveSecretKeyDirectory() async throws {
        let path = FileManager.defaultFileStatePath
        let keyURL = URL(fileURLWithPath: path).appendingPathComponent("secret.key")
        try FileManager.default.createDirectory(at: keyURL, withIntermediateDirectories: false)

        XCTAssertThrowsError(try SecretStore(directory: path).set("directory-key")) { error in
            XCTAssertEqual(
                error as? APSError,
                .insecureSecretKeyFile(reason: "path is not a regular file")
            )
        }
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: keyURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    @MainActor
    func testSecretStorePassphraseSetIgnoresStaleSecretKeyDirectory() async throws {
        let path = FileManager.defaultFileStatePath
        let keyURL = URL(fileURLWithPath: path).appendingPathComponent("secret.key")
        try FileManager.default.createDirectory(at: keyURL, withIntermediateDirectories: false)
        setProcessEnv("APS_SECRET_PASSPHRASE", "passphrase-secret")
        defer { setProcessEnv("APS_SECRET_PASSPHRASE", nil) }

        let store = SecretStore(directory: path)
        try store.set("passphrase-value")

        XCTAssertEqual(try store.get(), "passphrase-value")
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: keyURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    @MainActor
    func testSecretStoreExistingEnvelopePersistenceFailureRemainsPersistenceFailed() async throws {
        let path = FileManager.defaultFileStatePath
        let envelopeURL = URL(fileURLWithPath: path).appendingPathComponent("secret.enc")
        try FileManager.default.createDirectory(at: envelopeURL, withIntermediateDirectories: false)

        XCTAssertThrowsError(try SecretStore(directory: path).set("unreadable-envelope")) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "secret"))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: envelopeURL.path))
    }

    @MainActor
    internal func testSecretStoreReadExistingKeyUsesStoreLock() async throws {
        let path = FileManager.defaultFileStatePath
        let store = SecretStore(directory: path)
        try store.set("read-only-secret")

        let storeLockURL = URL(fileURLWithPath: path).appendingPathComponent("secret.store.lock")
        let keyLockURL = URL(fileURLWithPath: path).appendingPathComponent("secret.key.lock")
        try? FileManager.default.removeItem(at: storeLockURL)
        try? FileManager.default.removeItem(at: keyLockURL)

        XCTAssertEqual(try store.get(), "read-only-secret")
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeLockURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: keyLockURL.path))
    }
    #endif

    @MainActor
    func testSecretStoreConcurrentSetAndResetEndsCompleteOrAbsent() async throws {
        let path = FileManager.defaultFileStatePath
        let values = (0..<8).map { "set-reset-\($0)" }
        let store = SecretStore(directory: path)
        try store.set("initial")
        let keyURL = URL(fileURLWithPath: path).appendingPathComponent("secret.key")
        let originalKey = try Data(contentsOf: keyURL)

        let failures = await withTaskGroup(of: String?.self, returning: [String].self) { group in
            values.forEach { value in
                group.addTask {
                    do {
                        try SecretStore(directory: path).set(value)
                        return nil
                    } catch {
                        return String(describing: error)
                    }
                }
                group.addTask {
                    do {
                        _ = try SecretStore(directory: path).reset()
                        return nil
                    } catch {
                        return String(describing: error)
                    }
                }
            }

            var failures: [String] = []
            for await failure in group {
                if let failure {
                    failures.append(failure)
                }
            }
            return failures
        }

        XCTAssertTrue(failures.isEmpty, "Concurrent set/reset failed: \(failures)")
        XCTAssertEqual(try Data(contentsOf: keyURL), originalKey)
        if store.hasSecret {
            XCTAssertTrue(values.contains(try store.get()))
        }
    }

    @MainActor
    func testSecretStoreRejectsUnsafeFilenameBeforeWrite() async throws {
        let path = FileManager.defaultFileStatePath
        let store = SecretStore(
            directory: path,
            storeFileName: "./custom.enc",
            keyName: "custom"
        )

        XCTAssertThrowsError(try store.set("must-not-persist")) { error in
            guard case .schemaInvalid = error as? APSError else {
                return XCTFail("expected schemaInvalid, got \(error)")
            }
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: URL(fileURLWithPath: path).appendingPathComponent("custom.enc").path
            )
        )
    }

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

        _ = try reader.reset(.secret)
        XCTAssertEqual(StateStore().get(.secret), "")
    }

    @MainActor
    func testEncryptedDiskPreflightRejectsSchemaIncompatiblePlaintext() async throws {
        let store = StateStore()
        let stringEntry = SchemaKeyEntry(
            name: "shapedSecret",
            type: "String",
            storage: "EncryptedFile",
            initial: .string(""),
            path: "shaped-secret.enc",
            doc: "encrypted schema preflight regression"
        )
        try store.addKey(stringEntry, force: false)
        try store.set(name: stringEntry.name, value: "plaintext")

        let objectEntry = SchemaKeyEntry(
            name: stringEntry.name,
            type: "object",
            storage: stringEntry.storage,
            initial: .object(["name": .string("initial")]),
            path: stringEntry.path,
            doc: stringEntry.doc,
            objectShape: ["name": "String"]
        )
        try store.addKey(objectEntry, force: true)

        XCTAssertThrowsError(try StateStore.requireDecodableDiskState(forName: objectEntry.name)) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: objectEntry.name))
        }
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
        try store.set(name: "counter", value: "3")
        try store.set(name: "message", value: "hi")
        try store.set(name: "profile", value: #"{"name":"x","version":1}"#)

        let json = try store.dumpRegistered()
        XCTAssertTrue(json.contains("\"key\":\"counter\""))
        XCTAssertTrue(json.contains("\"value\":3"))
        XCTAssertTrue(json.contains("\"key\":\"message\""))
        XCTAssertTrue(json.contains("\"key\":\"profile\""))
        XCTAssertTrue(json.contains("\"storage\":\"FileState\""))
        XCTAssertTrue(json.contains("timestamp"))
    }

    @MainActor
    internal func testSeedDumpUsesLiveDefaultStateAdapterValues() async throws {
        let store = StateStore()
        try store.set(.counter, value: "41")
        try store.set(.message, value: "adapter-message")

        let dumpData = Data(try store.dump().utf8)
        let dump = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: dumpData) as? [String: Any]
        )
        let entries = try XCTUnwrap(dump["keys"] as? [[String: Any]])
        XCTAssertEqual(entries.compactMap { $0["key"] as? String }, DemoKey.allCases.map(\.rawValue))
        let counter = try XCTUnwrap(entries.first { $0["key"] as? String == "counter" })
        let message = try XCTUnwrap(entries.first { $0["key"] as? String == "message" })
        XCTAssertEqual(counter["storage"] as? String, "State")
        XCTAssertEqual(counter["type"] as? String, "Int")
        XCTAssertEqual(counter["value"] as? Int, 41)
        XCTAssertEqual(message["storage"] as? String, "State")
        XCTAssertEqual(message["type"] as? String, "String")
        XCTAssertEqual(message["value"] as? String, "adapter-message")
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
            .object([
                "name": .string("n"),
                "version": .int(2),
            ])
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

        _ = try store.reset(.counter)
        _ = try store.reset(.message)
        _ = try store.reset(.flag)
        _ = try store.reset(.note)
        _ = try store.reset(.profile)

        XCTAssertEqual(store.get(.counter), "0")
        XCTAssertEqual(store.get(.message), "")
        XCTAssertEqual(store.get(.flag), "false")
        XCTAssertEqual(store.get(.note), "")
        XCTAssertEqual(try store.profileDocument(), ProfileDocument())
    }

    @MainActor
    func testResetAll() async throws {
        let store = StateStore()
        try store.set(name: "counter", value: "5")
        try store.set(name: "note", value: "keep?")
        try store.set(name: "profile", value: #"{"name":"p","version":1}"#)
        try store.resetAllSeedKeys()
        XCTAssertEqual(try store.get(name: "counter"), "0")
        XCTAssertEqual(try store.get(name: "note"), "")
        let profileData = try XCTUnwrap(
            try store.get(name: "profile").data(using: .utf8)
        )
        let profile = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: profileData) as? [String: Any]
        )
        XCTAssertEqual(profile["name"] as? String, "")
        XCTAssertEqual(profile["version"] as? Int, 0)
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
            guard
                let event = try? CLIOutput.watchEvent(
                    key: .profile,
                    rawValue: value,
                    timestamp: store.now
                )
            else {
                XCTFail("Expected profile watch event to encode")
                return
            }
            events.append(event)
            if events.count == 1 {
                let changed = ProfileDocument(name: "leif", version: 4)
                let data = try? JSONEncoder().encode(changed)
                let url = URL(fileURLWithPath: path).appendingPathComponent("profile.json")
                try? data?.write(to: url)
            }
        }

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(
            events[0].value,
            .object([
                "name": .string("before"),
                "version": .int(3),
            ])
        )
        XCTAssertEqual(
            events[1].value,
            .object([
                "name": .string("leif"),
                "version": .int(4),
            ])
        )
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
            .object([
                "name": .string("a"),
                "version": .int(2),
            ])
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

    @MainActor
    internal func testWatchTimeoutBoundsLargePollingInterval() async throws {
        let store = StateStore()
        let deadline = Date().addingTimeInterval(0.1)
        let startedAt = Date()
        var seen: [String] = []

        try store.watchBlocking(
            .counter,
            pollInterval: 60.0,
            pollDeadline: deadline,
            shouldContinue: { Date() < deadline }
        ) { value in
            seen.append(value)
        }

        XCTAssertEqual(seen, ["0"])
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 0.5)
    }

    internal func testWatchPollingCanInterruptLargeIntervals() {
        let startedAt = Date()
        WatchPollingWakeup.shared.signal()
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

        _ = try reader.reset(.flag)
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

        _ = try store.reset(.flag)
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

        let storedRollback = APSError.rollbackFailed(
            context: .storedState(key: "profile"),
            originalErrorCode: "persistence_failed",
            originalErrorDescription: "Failed to persist profile"
        )
        XCTAssertTrue(storedRollback.description.contains("StoredState"))
        XCTAssertTrue(storedRollback.description.contains("profile"))
        XCTAssertTrue(storedRollback.description.contains("after reset failed"))
        XCTAssertFalse(storedRollback.description.contains("schema.json"))
        XCTAssertTrue(storedRollback.hint.contains("profile"))

        let adapterRollback = APSError.rollbackFailed(
            context: .adapter(key: "counter"),
            originalErrorCode: "persistence_failed",
            originalErrorDescription: "Failed to persist counter-adapter"
        )
        XCTAssertEqual(
            adapterRollback.description,
            "Failed to restore AppState adapter 'counter' after reset synchronization failed; "
                + "the compiled adapter may no longer match its backing storage. "
                + "Original failure [persistence_failed]: Failed to persist counter-adapter"
        )
        XCTAssertTrue(adapterRollback.hint.contains("adapter"))
        XCTAssertTrue(adapterRollback.hint.contains("counter"))

        let stagedRollback = APSError.rollbackFailed(
            context: .stagedFile(path: "nested/value.json"),
            originalErrorCode: "persistence_failed",
            originalErrorDescription: "Failed to persist nested/value.json"
        )
        XCTAssertTrue(stagedRollback.description.contains("nested/value.json"))
        XCTAssertTrue(stagedRollback.description.contains("staged deletion file"))
        XCTAssertFalse(stagedRollback.description.contains("schema.json"))
        XCTAssertTrue(stagedRollback.hint.contains(".aps-delete"))

        let schemaRollback = APSError.rollbackFailed(
            context: .schema(key: "note"),
            originalErrorCode: "persistence_failed",
            originalErrorDescription: "Failed to persist note"
        )
        XCTAssertEqual(
            schemaRollback.description,
            "Failed to restore schema.json after purging 'note' failed; "
                + "the retained data may no longer match the registry. "
                + "Original failure [persistence_failed]: Failed to persist note"
        )
        XCTAssertTrue(schemaRollback.hint.contains("retained data"))

        let candidateRollback = APSError.rollbackFailed(
            context: .schemaCandidate(key: "note"),
            originalErrorCode: "persistence_failed",
            originalErrorDescription: "Failed to persist schema.json"
        )
        XCTAssertEqual(
            candidateRollback.description,
            "The candidate registry update for removing 'note' failed, "
                + "and schema.json could not be restored; no data purge was attempted. "
                + "Original failure [persistence_failed]: Failed to persist schema.json"
        )
        XCTAssertEqual(
            candidateRollback.hint,
            "Inspect schema.json before retrying; retained key data was not purged."
        )
        XCTAssertFalse(candidateRollback.description.contains("after purging"))

        let envelopeRollback = APSError.rollbackFailed(
            context: .secretEnvelope(path: "secret.enc"),
            originalErrorCode: "persistence_failed",
            originalErrorDescription: "Failed to persist secret"
        )
        XCTAssertTrue(envelopeRollback.description.contains("encrypted envelope 'secret.enc'"))
        XCTAssertTrue(envelopeRollback.hint.contains("state-root backup"))
    }

    func testAPSErrorContractCodesAndExitCodes() {
        XCTAssertEqual(APSError.invalidValue(key: "counter", value: "x").code, "invalid_value")
        XCTAssertEqual(APSError.encodingFailed.code, "encoding_failed")
        XCTAssertEqual(APSError.decodingFailed.code, "decoding_failed")
        XCTAssertEqual(APSError.persistenceFailed(key: "note").code, "persistence_failed")
        XCTAssertEqual(APSError.secretUnlockFailed.code, "secret_unlock_failed")
        XCTAssertEqual(APSError.unsupportedSecretEnvelope.code, "unsupported_secret_envelope")
        XCTAssertEqual(
            APSError.insecureSecretKeyFile(reason: "test").code,
            "insecure_secret_key_file"
        )
        XCTAssertEqual(APSError.corruptState(key: "note").code, "corrupt_state")

        XCTAssertEqual(APSError.invalidValue(key: "counter", value: "x").exitCode, 64)
        XCTAssertEqual(APSError.decodingFailed.exitCode, 65)
        XCTAssertEqual(APSError.corruptState(key: "note").exitCode, 65)
        XCTAssertEqual(APSError.secretUnlockFailed.exitCode, 69)
        XCTAssertEqual(APSError.unsupportedSecretEnvelope.exitCode, 65)
        XCTAssertEqual(APSError.encodingFailed.exitCode, 70)
        XCTAssertEqual(APSError.persistenceFailed(key: "note").exitCode, 73)
        XCTAssertEqual(APSError.insecureSecretKeyFile(reason: "test").exitCode, 77)

        let errors: [APSError] = [
            .invalidValue(key: "flag", value: "x"),
            .encodingFailed,
            .decodingFailed,
            .persistenceFailed(key: "flag"),
            .secretUnlockFailed,
            .unsupportedSecretEnvelope,
            .insecureSecretKeyFile(reason: "test"),
            .corruptState(key: "profile"),
            .rollbackFailed(
                context: .schema(key: "note"),
                originalErrorCode: "persistence_failed",
                originalErrorDescription: "Failed to persist note"
            ),
        ]
        for error in errors {
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

        XCTAssertEqual(document.schemaVersion, 6)
        XCTAssertEqual(document.cliVersion, "1.1.0")
        XCTAssertEqual(document.keys.map(\.name), DemoKey.allCases.map(\.rawValue))
        XCTAssertEqual(document.userSchema.keyCount, document.keys.count)
        XCTAssertEqual(document.stateRoot.precedence, ["--state-dir", "APS_HOME", "~/.aps"])

        let commandNames = document.commands.map(\.name)
        for expected in ["get", "set", "watch", "dump", "keys", "key", "reset", "stats", "schema"] {
            XCTAssertTrue(commandNames.contains(expected), "missing command \(expected)")
        }
        let reset = document.commands.first { $0.name == "reset" }
        XCTAssertTrue(reset?.flags.contains("--registered") == true)
        let key = document.commands.first { $0.name == "key" }
        XCTAssertTrue(key?.flags.contains("--field") == true)

        let secret = document.keys.first { $0.name == "secret" }
        XCTAssertEqual(secret?.path, "<state-root>/secret.enc")
        XCTAssertNil(secret?.keychainAccount)
        let note = document.keys.first { $0.name == "note" }
        XCTAssertEqual(note?.path, "<state-root>/note.json")
    }

    func testSchemaErrorTableIsStable() {
        let table = Schema.staticDocument().errors
        XCTAssertEqual(table.count, 12)
        let byCode = Dictionary(uniqueKeysWithValues: table.map { ($0.code, $0.exitCode) })
        XCTAssertEqual(byCode["invalid_value"], 64)
        XCTAssertEqual(byCode["decoding_failed"], 65)
        XCTAssertEqual(byCode["corrupt_state"], 65)
        XCTAssertEqual(byCode["secret_unlock_failed"], 69)
        XCTAssertEqual(byCode["unsupported_secret_envelope"], 65)
        XCTAssertEqual(byCode["insecure_secret_key_file"], 77)
        XCTAssertEqual(byCode["encoding_failed"], 70)
        XCTAssertEqual(byCode["persistence_failed"], 73)
        XCTAssertEqual(byCode["unknown_key"], 64)
        XCTAssertEqual(byCode["schema_conflict"], 64)
        XCTAssertEqual(byCode["schema_invalid"], 65)
        XCTAssertEqual(byCode["rollback_failed"], 73)
        for entry in table {
            XCTAssertFalse(entry.hint.isEmpty, "hint required for \(entry.code)")
            XCTAssertFalse(entry.meaning.isEmpty, "meaning required for \(entry.code)")
        }
    }

    func testSchemaDocumentEncodesValidContractJSON() throws {
        let json = try CLIOutput.encodePretty(Schema.staticDocument())
        let data = try XCTUnwrap(json.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["schemaVersion"] as? Int, 6)
        let userSchema = try XCTUnwrap(object?["userSchema"] as? [String: Any])
        let keys = try XCTUnwrap(object?["keys"] as? [[String: Any]])
        XCTAssertEqual(userSchema["keyCount"] as? Int, keys.count)
        let payloads = try XCTUnwrap(object?["payloads"] as? [String: Any])
        for name in [
            "KeyValuePayload",
            "KeysPayload",
            "WatchEvent",
            "WatchErrorEvent",
            "WatchEndEvent",
            "ResetPayload",
            "BulkResetReport",
            "ResetFailure",
            "StatsPayload",
            "ErrorEnvelope",
        ] {
            XCTAssertNotNil(payloads[name], "missing payload schema \(name)")
        }
        let event = try XCTUnwrap(payloads["WatchEvent"] as? [String: Any])
        XCTAssertEqual(event["type"] as? String, "object")
        XCTAssertNotNil(event["properties"])
        XCTAssertNotNil(event["required"])

        let recursiveType = "null | boolean | integer | finite number | string | array | object (recursive)"
        for payloadName in ["KeyValuePayload", "WatchEvent", "ResetPayload"] {
            let payload = try XCTUnwrap(payloads[payloadName] as? [String: Any])
            let properties = try XCTUnwrap(payload["properties"] as? [String: Any])
            let value = try XCTUnwrap(properties["value"] as? [String: Any])
            XCTAssertEqual(value["type"] as? String, recursiveType)
        }
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

    @MainActor
    internal func testForcedSeedUsesRegistryTypeStoragePathInitialOutputAndWatch() async throws {
        let store = StateStore()
        let forced = SchemaKeyEntry(
            name: "counter",
            type: "String",
            storage: "FileState",
            initial: .string("forced-initial"),
            path: "forced-counter.json",
            doc: "forced seed"
        )
        try store.addKey(forced, force: true)

        XCTAssertEqual(try store.get(name: "counter"), "forced-initial")
        XCTAssertEqual(try store.resolve("counter").doc, "forced seed")
        let root = FileManager.defaultFileStatePath
        let projected = try XCTUnwrap(
            try Schema.document(stateDir: root).keys.first { $0.name == "counter" }
        )
        XCTAssertEqual(projected.type, "String")
        XCTAssertEqual(projected.storage, "FileState")
        XCTAssertEqual(projected.path, "<state-root>/forced-counter.json")
        try store.set(name: "counter", value: "hello")
        XCTAssertEqual(try StateStore().get(name: "counter"), "hello")
        XCTAssertEqual(
            try CLIOutput.typedValue(for: forced, from: try store.get(name: "counter")),
            .string("hello")
        )
        let seedDumpData = Data(try store.dump().utf8)
        let seedDump = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: seedDumpData) as? [String: Any]
        )
        let seedEntries = try XCTUnwrap(seedDump["keys"] as? [[String: Any]])
        XCTAssertEqual(seedEntries.compactMap { $0["key"] as? String }, DemoKey.allCases.map(\.rawValue))
        let counterEntry = try XCTUnwrap(seedEntries.first { $0["key"] as? String == "counter" })
        XCTAssertEqual(counterEntry["storage"] as? String, "FileState")
        XCTAssertEqual(counterEntry["type"] as? String, "String")
        XCTAssertEqual(counterEntry["value"] as? String, "hello")

        let dump = try store.dumpRegistered()
        XCTAssertTrue(dump.contains(#""key":"counter""#))
        XCTAssertTrue(dump.contains(#""storage":"FileState""#))
        XCTAssertTrue(dump.contains(#""value":"hello""#))

        let fileURL = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("forced-counter.json")
        var seen: [String] = []
        try store.watchBlocking(
            name: "counter",
            pollInterval: 0.05,
            shouldContinue: { seen.count < 2 }
        ) { value in
            seen.append(value)
            if seen.count == 1, let data = try? JSONEncoder().encode("changed") {
                try? data.write(to: fileURL)
            }
        }
        XCTAssertEqual(seen, ["hello", "changed"])

        try store.reset(name: "counter")
        XCTAssertEqual(try store.get(name: "counter"), "forced-initial")
    }

    @MainActor
    internal func testForcedStringSeedUsesRegistryBoolStoredState() async throws {
        let store = StateStore()
        let forced = SchemaKeyEntry(
            name: "message",
            type: "Bool",
            storage: "StoredState",
            initial: .bool(true),
            doc: "forced bool"
        )
        try store.addKey(forced, force: true)

        XCTAssertEqual(try store.get(name: "message"), "true")
        try store.set(name: "message", value: "false")
        XCTAssertEqual(
            try CLIOutput.typedValue(for: forced, from: try store.get(name: "message")),
            .bool(false)
        )
        XCTAssertEqual(
            hermeticDefaults?.object(forKey: "aps.user.message") as? Bool,
            false
        )
        XCTAssertThrowsError(try store.set(name: "message", value: "not-bool"))

        try store.reset(name: "message")
        XCTAssertEqual(try store.get(name: "message"), "true")
    }

    @MainActor
    internal func testForcedSeedPathIgnoresAndPreservesFormerData() async throws {
        let store = StateStore()
        try store.set(name: "note", value: "legacy-note")
        let oldURL = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("note.json")
        let forced = SchemaKeyEntry(
            name: "note",
            type: "String",
            storage: "FileState",
            initial: .string("new-initial"),
            path: "moved-note.json",
            doc: "moved seed"
        )
        try store.addKey(forced, force: true)

        XCTAssertEqual(try store.get(name: "note"), "new-initial")
        try store.set(name: "note", value: "moved-note")
        XCTAssertEqual(try store.get(name: "note"), "moved-note")
        XCTAssertEqual(
            try JSONDecoder().decode(String.self, from: Data(contentsOf: oldURL)),
            "legacy-note"
        )

        try store.reset(name: "note")
        XCTAssertEqual(try store.get(name: "note"), "new-initial")
        XCTAssertEqual(
            try JSONDecoder().decode(String.self, from: Data(contentsOf: oldURL)),
            "legacy-note"
        )
    }

    @MainActor
    internal func testForcedSeedSliceUsesRegistryParentAndField() async throws {
        let store = StateStore()
        let parent = SchemaKeyEntry(
            name: "alternateProfile",
            type: "object",
            storage: "FileState",
            initial: .object(["alias": .string("seed"), "version": .int(7)]),
            path: "alternate-profile.json",
            doc: "alternate slice parent",
            objectShape: ["alias": "String", "version": "Int"]
        )
        try store.addKey(parent, force: false)
        let forcedSlice = SchemaKeyEntry(
            name: "profileName",
            type: "String",
            storage: "Slice",
            initial: .string("reset-alias"),
            doc: "redirected slice",
            sliceOf: "alternateProfile",
            sliceField: "alias"
        )
        try store.addKey(forcedSlice, force: true)

        XCTAssertEqual(try store.get(name: "profileName"), "seed")
        try store.set(name: "profileName", value: "redirected")
        XCTAssertEqual(try store.get(name: "profileName"), "redirected")
        let profileData = try XCTUnwrap(
            try store.get(name: "profile").data(using: .utf8)
        )
        let profile = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: profileData) as? [String: Any]
        )
        XCTAssertEqual(profile["name"] as? String, "")
        XCTAssertEqual(profile["version"] as? Int, 0)

        try store.reset(name: "profileName")
        XCTAssertEqual(try store.get(name: "profileName"), "reset-alias")
    }

    @MainActor
    internal func testDefaultSliceUsesRegistryWhenItsDefaultParentIsReplaced() async throws {
        let store = StateStore()
        let replacedParent = SchemaKeyEntry(
            name: "profile",
            type: "object",
            storage: "FileState",
            initial: .object(["name": .string("replacement"), "version": .int(8)]),
            path: "replacement-profile.json",
            doc: "replaced default Slice parent",
            objectShape: ["name": "String", "version": "Int"]
        )
        try store.addKey(replacedParent, force: true)
        let compiledProfileBefore = try StateStore.readProfileFromDisk()

        try store.set(.profileName, value: "registry-value")

        XCTAssertEqual(store.get(.profileName), "registry-value")
        XCTAssertEqual(try store.get(name: "profileName"), "registry-value")
        XCTAssertEqual(try StateStore.readProfileFromDisk(), compiledProfileBefore)
        let replacementURL = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("replacement-profile.json")
        let replacementData = try Data(contentsOf: replacementURL)
        let replacementObject = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: replacementData) as? [String: Any]
        )
        XCTAssertEqual(replacementObject["name"] as? String, "registry-value")
        XCTAssertEqual(replacementObject["version"] as? Int, 8)
    }

    @MainActor
    internal func testSeedBulkResetSkipsRemovedSeedName() async throws {
        let store = StateStore()
        try store.set(name: "message", value: "must-survive")
        try store.removeKey(name: "message", purge: false)

        try store.resetAllSeedKeys()
        XCTAssertThrowsError(try store.get(name: "message")) { error in
            XCTAssertEqual(error as? APSError, .unknownKey(name: "message"))
        }

        let seed = try XCTUnwrap(
            UserSchema.defaultDocument().keys.first { $0.name == "message" }
        )
        try store.addKey(seed, force: false)
        XCTAssertEqual(try store.get(name: "message"), "must-survive")
    }

    @MainActor
    internal func testDefaultFlagReadsLegacyAppStateDataAndResetPreventsResurrection() async throws {
        let legacyData = try JSONEncoder().encode(true)
        hermeticDefaults?.set(legacyData, forKey: "App/aps.flag")
        hermeticDefaults?.removeObject(forKey: "aps.user.flag")
        let store = StateStore()

        XCTAssertEqual(try store.get(name: "flag"), "true")
        XCTAssertNil(hermeticDefaults?.object(forKey: "aps.user.flag"))

        try store.reset(name: "flag")
        XCTAssertNil(hermeticDefaults?.object(forKey: "App/aps.flag"))
        XCTAssertEqual(
            hermeticDefaults?.object(forKey: "aps.user.flag") as? Bool,
            false
        )
        XCTAssertEqual(try store.get(name: "flag"), "false")
    }

    @MainActor
    internal func testDefaultFlagSetRollsBackCanonicalAndLegacyObjectsWhenLegacyWriteDrops() async throws {
        let defaults = OneShotDroppingUserDefaults()
        let oldLegacy = try JSONEncoder().encode(false)
        defaults.seed(17, forKey: "aps.user.flag")
        defaults.seed(oldLegacy, forKey: "App/aps.flag")
        defaults.dropNextSet(forKey: "App/aps.flag")
        let overrideToken = Application.override(\Application.userDefaults, with: defaults)
        defer { _ = overrideToken }
        let store = StateStore()

        XCTAssertThrowsError(try store.set(.flag, value: "true")) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "flag"))
        }
        XCTAssertEqual(defaults.object(forKey: "aps.user.flag") as? Int, 17)
        XCTAssertEqual(defaults.object(forKey: "App/aps.flag") as? Data, oldLegacy)
    }

    @MainActor
    internal func testDefaultFlagNameSetRollsBackCanonicalAndLegacyObjectsWhenLegacyWriteDrops() async throws {
        let defaults = OneShotDroppingUserDefaults()
        let oldLegacy = try JSONEncoder().encode(false)
        defaults.seed(17, forKey: "aps.user.flag")
        defaults.seed(oldLegacy, forKey: "App/aps.flag")
        defaults.dropNextSet(forKey: "App/aps.flag")
        let overrideToken = Application.override(\Application.userDefaults, with: defaults)
        defer { _ = overrideToken }
        let store = StateStore()

        XCTAssertThrowsError(try store.set(name: "flag", value: "true")) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "flag"))
        }
        XCTAssertEqual(defaults.object(forKey: "aps.user.flag") as? Int, 17)
        XCTAssertEqual(defaults.object(forKey: "App/aps.flag") as? Data, oldLegacy)
    }

    @MainActor
    internal func testDefaultFileStateResetAdapterPreservesNewerDiskWrites() async throws {
        let store = StateStore()
        try store.set(.note, value: "before-reset")
        let noteURL = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("note.json")

        _ = try store.reset(name: "note", recordMutation: false) { entry in
            try JSONEncoder().encode("newer-note").write(to: noteURL)
            try store.synchronizeDefaultAdapter(
                afterResetting: try XCTUnwrap(DemoKey(rawValue: entry.name)),
                storageLockAlreadyHeld: true
            )
        }

        XCTAssertEqual(try StateStore.readNoteFromDisk(), "newer-note")
        XCTAssertEqual(store.get(.note), "newer-note")

        try store.set(.profile, value: #"{"name":"before-reset","version":1}"#)
        let profileURL = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("profile.json")
        let newerProfile = ProfileDocument(name: "newer-profile", version: 9)

        _ = try store.reset(name: "profile", recordMutation: false) { entry in
            try JSONEncoder().encode(newerProfile).write(to: profileURL)
            try store.synchronizeDefaultAdapter(
                afterResetting: try XCTUnwrap(DemoKey(rawValue: entry.name)),
                storageLockAlreadyHeld: true
            )
        }

        XCTAssertEqual(try StateStore.readProfileFromDisk(), newerProfile)
        XCTAssertEqual(try store.profileDocument(), newerProfile)
    }

    @MainActor
    internal func testDefaultNoteResetAdapterFailureRestoresStorageCacheAndStats() async throws {
        let store = StateStore()
        try store.set(.note, value: "before-reset")
        let noteURL = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("note.json")
        let originalBytes = try Data(contentsOf: noteURL)
        store.resetStats()

        XCTAssertThrowsError(
            try store.reset(
                .note,
                afterAcquiringProfileStorageLock: {},
                afterSynchronizingDefaultAdapter: {
                    throw APSError.persistenceFailed(key: "note-adapter")
                }
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "note-adapter"))
        }

        XCTAssertEqual(try Data(contentsOf: noteURL), originalBytes)
        XCTAssertEqual(store.get(.note), "before-reset")
        XCTAssertEqual(store.statsSnapshot().mutationCount, 0)
    }

    @MainActor
    internal func testDefaultStateAndStoredStateAdapterFailuresRestoreExactValues() async throws {
        let store = StateStore()
        try store.set(.counter, value: "41")
        store.resetStats()

        XCTAssertThrowsError(
            try store.reset(
                .counter,
                afterAcquiringProfileStorageLock: {},
                afterSynchronizingDefaultAdapter: {
                    throw APSError.persistenceFailed(key: "counter-adapter")
                }
            )
        )
        XCTAssertEqual(store.get(.counter), "41")
        XCTAssertEqual(store.statsSnapshot().mutationCount, 0)

        try store.set(.flag, value: "true")
        let originalCanonical = hermeticDefaults?.object(forKey: "aps.user.flag") as? Bool
        let originalLegacy = hermeticDefaults?.object(forKey: "App/aps.flag") as? Data
        store.resetStats()

        XCTAssertThrowsError(
            try store.reset(
                .flag,
                afterAcquiringProfileStorageLock: {},
                afterSynchronizingDefaultAdapter: {
                    throw APSError.persistenceFailed(key: "flag-adapter")
                }
            )
        )
        XCTAssertEqual(hermeticDefaults?.object(forKey: "aps.user.flag") as? Bool, originalCanonical)
        XCTAssertEqual(hermeticDefaults?.object(forKey: "App/aps.flag") as? Data, originalLegacy)
        XCTAssertEqual(store.get(.flag), "true")
        XCTAssertEqual(store.statsSnapshot().mutationCount, 0)
    }

    @MainActor
    internal func testBulkProfileNameAdapterFailureRollsBackOnlyFailedKey() async throws {
        let store = StateStore()
        try store.set(.profile, value: #"{"name":"before-reset","version":7}"#)
        store.resetStats()

        XCTAssertThrowsError(
            try store.resetAll(afterSynchronizingDefaultAdapter: { key in
                if key == .profileName {
                    throw APSError.persistenceFailed(key: "profileName-adapter")
                }
            })
        ) { error in
            guard let bulkError = error as? BulkResetError else {
                return XCTFail("Expected BulkResetError, got \(error)")
            }
            XCTAssertEqual(
                bulkError.report.reset,
                ["counter", "message", "flag", "note", "profile", "secret"]
            )
            XCTAssertEqual(bulkError.report.failed?.key, "profileName")
            XCTAssertTrue(bulkError.report.notAttempted.isEmpty)
        }

        XCTAssertEqual(try store.profileDocument(), ProfileDocument())
        XCTAssertEqual(store.profileName(), "")
        XCTAssertEqual(store.statsSnapshot().mutationCount, 6)
        XCTAssertEqual(store.statsSnapshot().lastMutatedKey, "secret")
    }

    @MainActor
    internal func testDefaultNoteAdapterFailureReportsUnprovableStorageRollback() async throws {
        let store = StateStore()
        try store.set(.note, value: "before-reset")
        let faults = ResetFileFaults(failingRead: 3)
        store.resetStats()

        XCTAssertThrowsError(
            try store.reset(
                .note,
                afterAcquiringProfileStorageLock: {},
                fileOperations: faults.operations,
                afterSynchronizingDefaultAdapter: {
                    throw APSError.persistenceFailed(key: "note-adapter")
                }
            )
        ) { error in
            XCTAssertEqual(
                error as? APSError,
                .rollbackFailed(
                    context: .fileState(path: "note.json"),
                    originalErrorCode: "persistence_failed",
                    originalErrorDescription: "Failed to persist note-adapter"
                )
            )
        }
        XCTAssertEqual(store.statsSnapshot().mutationCount, 0)
    }

    @MainActor
    internal func testDefaultSecretAdapterFailurePreservesEnvelopeAndStats() async throws {
        setProcessEnv("APS_SECRET_PASSPHRASE", "adapter-transaction-test")
        defer { setProcessEnv("APS_SECRET_PASSPHRASE", nil) }
        let store = StateStore()
        try store.set(.secret, value: "before-reset")
        let envelopeURL = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("secret.enc")
        let originalBytes = try Data(contentsOf: envelopeURL)
        store.resetStats()

        XCTAssertThrowsError(
            try store.reset(
                .secret,
                afterAcquiringProfileStorageLock: {},
                afterSynchronizingDefaultAdapter: {
                    throw APSError.persistenceFailed(key: "secret-adapter")
                }
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "secret-adapter"))
        }
        XCTAssertEqual(try Data(contentsOf: envelopeURL), originalBytes)
        XCTAssertEqual(store.get(.secret), "before-reset")
        XCTAssertEqual(store.statsSnapshot().mutationCount, 0)
    }

    @MainActor
    internal func testForcedFlagDefinitionDisablesLegacyCompatibility() async throws {
        let legacyData = try JSONEncoder().encode(true)
        hermeticDefaults?.set(legacyData, forKey: "App/aps.flag")
        hermeticDefaults?.removeObject(forKey: "aps.user.flag")
        let store = StateStore()
        let forced = SchemaKeyEntry(
            name: "flag",
            type: "String",
            storage: "StoredState",
            initial: .string("forced"),
            doc: "forced flag"
        )
        try store.addKey(forced, force: true)

        XCTAssertEqual(try store.get(name: "flag"), "forced")
        try store.set(name: "flag", value: "current")
        XCTAssertEqual(try store.get(name: "flag"), "current")
        XCTAssertNotNil(hermeticDefaults?.object(forKey: "App/aps.flag"))

        try store.reset(name: "flag")
        XCTAssertEqual(try store.get(name: "flag"), "forced")
        XCTAssertNotNil(hermeticDefaults?.object(forKey: "App/aps.flag"))
    }

    internal func testSchemaRejectsStateRootAndPreservesSentinel() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("aps-schema-root-escape-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            FileManager.defaultFileStatePath = root.path

            let sentinel = root.appendingPathComponent("must-survive.txt")
            try Data("sentinel".utf8).write(to: sentinel)
            let store = StateStore()

            XCTAssertThrowsError(
                try store.addKey(
                    SchemaKeyEntry(
                        name: "unsafeRoot",
                        type: "String",
                        storage: "EncryptedFile",
                        initial: .string(""),
                        path: ".",
                        doc: "must be rejected"
                    ),
                    force: false
                )
            )
            XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        }
    }

    internal func testSchemaRejectsPortableStoragePathCollision() throws {
        var document = UserSchema.defaultDocument()
        document.keys.append(
            SchemaKeyEntry(
                name: "caseCollision",
                type: "String",
                storage: "FileState",
                initial: .string(""),
                path: "NOTE.JSON",
                doc: "portable collision with note.json"
            )
        )

        XCTAssertThrowsError(try UserSchema.validate(document))
    }

    internal func testParallelSchemaPathCollisionAllowsOneWinner() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-schema-path-race-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try UserSchema.write(UserSchema.defaultDocument(), to: UserSchema.schemaURL(stateRoot: root.path))

        let successes = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for (name, path) in [("collisionA", "shared.json"), ("collisionB", "SHARED.JSON")] {
                group.addTask {
                    do {
                        try SchemaFileLock.withExclusiveLock(stateRoot: root.path) {
                            var document = try UserSchema.loadUnlocked(stateRoot: root.path)
                            document.keys.append(
                                SchemaKeyEntry(
                                    name: name,
                                    type: "String",
                                    storage: "FileState",
                                    initial: .string(""),
                                    path: path,
                                    doc: "portable collision contender"
                                )
                            )
                            try UserSchema.write(
                                document,
                                to: UserSchema.schemaURL(stateRoot: root.path)
                            )
                        }
                        return true
                    } catch {
                        return false
                    }
                }
            }

            var count = 0
            for await succeeded in group where succeeded {
                count += 1
            }
            return count
        }

        XCTAssertEqual(successes, 1)
        let document = try UserSchema.load(from: UserSchema.schemaURL(stateRoot: root.path))
        XCTAssertEqual(
            document.keys.filter { $0.name == "collisionA" || $0.name == "collisionB" }.count,
            1
        )
    }

    internal func testNestedStoragePathRoundTripsAndResets() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("aps-schema-nested-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            FileManager.defaultFileStatePath = root.path

            let store = StateStore()
            try store.addKey(
                SchemaKeyEntry(
                    name: "nestedNote",
                    type: "String",
                    storage: "FileState",
                    initial: .string(""),
                    path: "agents/codex/note.json",
                    doc: "valid nested state"
                ),
                force: false
            )
            try store.set(name: "nestedNote", value: "ready")
            XCTAssertEqual(try store.get(name: "nestedNote"), "ready")

            try store.reset(name: "nestedNote")
            XCTAssertEqual(try store.get(name: "nestedNote"), "")
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: root.appendingPathComponent("agents/codex/note.json").path
                )
            )
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
        _ = try store.reset()
    }
#endif

    func testStorageLockAcquisitionFailureNamesAffectedKey() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-storage-lock-root-\(UUID().uuidString)")
        XCTAssertTrue(FileManager.default.createFile(atPath: root.path, contents: Data()))
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(
            try SchemaFileLock.withExclusiveStorageLock(
                stateRoot: root.path,
                lockFileName: "profile.json.lock",
                resourceKey: "profileName"
            ) {
                XCTFail("Body must not run when storage lock acquisition fails")
            }
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "profileName"))
        }
    }

#if os(Windows)
    func testSchemaFileLockPropagatesBodyErrors() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-lock-error-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(
            try SchemaFileLock.withExclusiveStorageLock(
                stateRoot: root.path,
                lockFileName: "secret.store.lock",
                resourceKey: "secret"
            ) {
                throw APSError.secretUnlockFailed
            }
        ) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }
    }
#endif

    func testWindowsLockNeverReclaimsDemonstrablyLiveOwner() {
        let now: TimeInterval = 10_000

        XCTAssertFalse(
            SchemaFileLock.windowsHeldIsStale(
                ownerPID: 41,
                fileTimestamp: now - 3_600,
                now: now,
                currentPID: 99,
                ownerState: .alive
            )
        )
    }

    func testWindowsLockReclaimsDeadOwnerWithoutWaitingForLease() {
        let now: TimeInterval = 10_000

        XCTAssertTrue(
            SchemaFileLock.windowsHeldIsStale(
                ownerPID: 41,
                fileTimestamp: now,
                now: now,
                currentPID: 99,
                ownerState: .dead
            )
        )
    }

    func testWindowsLockNeverReclaimsIndeterminateValidOwner() {
        let now: TimeInterval = 10_000

        XCTAssertFalse(
            SchemaFileLock.windowsHeldIsStale(
                ownerPID: 41,
                fileTimestamp: now - 2,
                now: now,
                currentPID: 99,
                ownerState: .unknown
            )
        )
        XCTAssertFalse(
            SchemaFileLock.windowsHeldIsStale(
                ownerPID: 41,
                fileTimestamp: now - 3_600,
                now: now,
                currentPID: 99,
                ownerState: .unknown
            )
        )
    }

    func testWindowsLockUsesFileAgeGraceForCorruptPayload() {
        let now: TimeInterval = 10_000

        XCTAssertFalse(
            SchemaFileLock.windowsHeldIsStale(
                ownerPID: nil,
                fileTimestamp: now - 2,
                now: now,
                currentPID: 99,
                ownerState: .unknown
            )
        )
        XCTAssertTrue(
            SchemaFileLock.windowsHeldIsStale(
                ownerPID: nil,
                fileTimestamp: now - 3,
                now: now,
                currentPID: 99,
                ownerState: .unknown
            )
        )
        XCTAssertFalse(
            SchemaFileLock.windowsHeldIsStale(
                ownerPID: nil,
                fileTimestamp: now + 3_600,
                now: now,
                currentPID: 99,
                ownerState: .unknown
            )
        )
        XCTAssertFalse(
            SchemaFileLock.windowsHeldIsStale(
                ownerPID: nil,
                fileTimestamp: nil,
                now: now,
                currentPID: 99,
                ownerState: .unknown
            )
        )
    }

    func testWindowsLockReclaimsSameProcessOrphan() {
        XCTAssertTrue(
            SchemaFileLock.windowsHeldIsStale(
                ownerPID: 99,
                fileTimestamp: 10_000,
                now: 10_000,
                currentPID: 99,
                ownerState: .alive
            )
        )
    }

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
        try store.set(name: "flag", value: "true")

        try store.resetAllSeedKeys()
        XCTAssertEqual(try store.get(name: "flag"), "false")
        XCTAssertEqual(try store.get(name: "agentStatus"), "exploring")

        try store.resetAllRegistered()
        XCTAssertEqual(try store.get(name: "agentStatus"), "")
    }

    @MainActor
    func testRemoveKeyRestoresExactSchemaWhenPurgeFails() async throws {
        let store = StateStore()
        let original = try store.loadSchema()
        var schemaWriteCount = 0

        XCTAssertThrowsError(
            try store.removeKey(
                name: "note",
                purge: true,
                purgeOperation: { _, _ in
                    throw APSError.persistenceFailed(key: "note")
                },
                schemaWriter: { document, root in
                    schemaWriteCount += 1
                    try UserSchema.write(document, stateRoot: root)
                }
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "note"))
        }

        XCTAssertEqual(schemaWriteCount, 2)
        XCTAssertEqual(try store.loadSchema(), original)
        XCTAssertNotNil(try store.resolve("note"))
    }

    @MainActor
    internal func testRemoveKeyRejectsDroppedCandidateSchemaWriteBeforePurge() async throws {
        let store = StateStore()
        let original = try store.loadSchema()
        var purgeCalled = false

        XCTAssertThrowsError(
            try store.removeKey(
                name: "note",
                purge: true,
                purgeOperation: { _, _ in
                    purgeCalled = true
                },
                schemaWriter: { _, _ in }
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: UserSchema.fileName))
        }

        XCTAssertFalse(purgeCalled)
        XCTAssertEqual(try store.loadSchema(), original)
        XCTAssertNotNil(try store.resolve("note"))
    }

    @MainActor
    internal func testRemoveKeyRestoresOriginalAfterCandidateVerificationMismatch() async throws {
        let store = StateStore()
        let original = try store.loadSchema()
        var loadCount = 0
        var purgeCalled = false

        XCTAssertThrowsError(
            try store.removeKey(
                name: "note",
                purge: true,
                purgeOperation: { _, _ in
                    purgeCalled = true
                },
                schemaWriter: { document, root in
                    try UserSchema.write(document, stateRoot: root)
                },
                schemaLoader: { root in
                    loadCount += 1
                    if loadCount == 1 {
                        var divergent = try UserSchema.loadUnlocked(stateRoot: root)
                        divergent.namespace = "divergent"
                        try UserSchema.write(divergent, stateRoot: root)
                        return divergent
                    }
                    return try UserSchema.loadUnlocked(stateRoot: root)
                }
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: UserSchema.fileName))
        }

        XCTAssertEqual(loadCount, 2)
        XCTAssertFalse(purgeCalled)
        XCTAssertEqual(try store.loadSchema(), original)
        XCTAssertNotNil(try store.resolve("note"))
    }

    @MainActor
    internal func testRemoveKeyRestoresOriginalWhenCandidateWriterPersistsThenThrows() async throws {
        let store = StateStore()
        let original = try store.loadSchema()
        var schemaWriteCount = 0
        var purgeCalled = false

        XCTAssertThrowsError(
            try store.removeKey(
                name: "note",
                purge: true,
                purgeOperation: { _, _ in
                    purgeCalled = true
                },
                schemaWriter: { document, root in
                    schemaWriteCount += 1
                    try UserSchema.write(document, stateRoot: root)
                    if schemaWriteCount == 1 {
                        throw APSError.persistenceFailed(key: "candidate-write")
                    }
                }
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "candidate-write"))
        }

        XCTAssertEqual(schemaWriteCount, 2)
        XCTAssertFalse(purgeCalled)
        XCTAssertEqual(try store.loadSchema(), original)
        XCTAssertNotNil(try store.resolve("note"))
    }

    @MainActor
    internal func testRemoveKeyReportsRollbackFailureWhenCandidateVerificationReadFails() async throws {
        let store = StateStore()
        _ = try store.loadSchema()
        var schemaWriteCount = 0
        var loadCount = 0

        XCTAssertThrowsError(
            try store.removeKey(
                name: "note",
                purge: true,
                purgeOperation: { _, _ in
                    XCTFail("purge must not run before candidate verification")
                },
                schemaWriter: { document, root in
                    schemaWriteCount += 1
                    guard schemaWriteCount == 1 else { return }
                    try UserSchema.write(document, stateRoot: root)
                },
                schemaLoader: { root in
                    loadCount += 1
                    if loadCount == 1 {
                        throw APSError.schemaInvalid(reason: "injected candidate read failure")
                    }
                    return try UserSchema.loadUnlocked(stateRoot: root)
                }
            )
        ) { error in
            XCTAssertEqual(
                error as? APSError,
                .rollbackFailed(
                    context: .schemaCandidate(key: "note"),
                    originalErrorCode: "persistence_failed",
                    originalErrorDescription: "Failed to persist schema.json"
                )
            )
        }

        XCTAssertEqual(schemaWriteCount, 2)
        XCTAssertEqual(loadCount, 2)
        XCTAssertThrowsError(try store.resolve("note")) { error in
            XCTAssertEqual(error as? APSError, .unknownKey(name: "note"))
        }
    }

    @MainActor
    func testRemoveKeyReportsRollbackFailureWhenSchemaRestoreFails() async throws {
        let store = StateStore()
        _ = try store.loadSchema()
        var schemaWriteCount = 0

        XCTAssertThrowsError(
            try store.removeKey(
                name: "note",
                purge: true,
                purgeOperation: { _, _ in
                    throw APSError.persistenceFailed(key: "note")
                },
                schemaWriter: { document, root in
                    schemaWriteCount += 1
                    if schemaWriteCount == 2 {
                        throw APSError.persistenceFailed(key: UserSchema.fileName)
                    }
                    try UserSchema.write(document, stateRoot: root)
                }
            )
        ) { error in
            let domainError = error as? APSError
            guard case .rollbackFailed(let context, let purgeCode, let purgeDescription) = domainError else {
                return XCTFail("Expected rollbackFailed, got \(error)")
            }
            XCTAssertEqual(context, .schema(key: "note"))
            XCTAssertEqual(purgeCode, "persistence_failed")
            XCTAssertEqual(purgeDescription, "Failed to persist note")
            XCTAssertEqual(domainError?.code, "rollback_failed")
            XCTAssertEqual(domainError?.exitCode, 73)
            XCTAssertFalse(domainError?.hint.isEmpty == true)
        }

        XCTAssertEqual(schemaWriteCount, 2)
        XCTAssertThrowsError(try store.resolve("note")) { error in
            XCTAssertEqual(error as? APSError, .unknownKey(name: "note"))
        }
    }

    @MainActor
    internal func testRemoveKeyReportsRollbackFailureWhenSchemaRestoreWriteDrops() async throws {
        let store = StateStore()
        _ = try store.loadSchema()
        var schemaWriteCount = 0

        XCTAssertThrowsError(
            try store.removeKey(
                name: "note",
                purge: true,
                purgeOperation: { _, _ in
                    throw APSError.persistenceFailed(key: "note")
                },
                schemaWriter: { document, root in
                    schemaWriteCount += 1
                    guard schemaWriteCount == 1 else { return }
                    try UserSchema.write(document, stateRoot: root)
                }
            )
        ) { error in
            XCTAssertEqual(
                error as? APSError,
                .rollbackFailed(
                    context: .schema(key: "note"),
                    originalErrorCode: "persistence_failed",
                    originalErrorDescription: "Failed to persist note"
                )
            )
        }

        XCTAssertEqual(schemaWriteCount, 2)
        XCTAssertThrowsError(try store.resolve("note")) { error in
            XCTAssertEqual(error as? APSError, .unknownKey(name: "note"))
        }
    }

    @MainActor
    func testRemoveKeyHoldsSchemaLockThroughPurgeAndRollback() async throws {
        let store = StateStore()
        let root = FileManager.defaultFileStatePath
        _ = try store.loadSchema()
        let purgeStarted = DispatchSemaphore(value: 0)
        let lockAttempting = DispatchSemaphore(value: 0)
        let competingLockAcquired = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            purgeStarted.wait()
            lockAttempting.signal()
            if (try? SchemaFileLock.withExclusiveLock(stateRoot: root) {}) != nil {
                competingLockAcquired.signal()
            }
        }

        XCTAssertThrowsError(
            try store.removeKey(
                name: "note",
                purge: true,
                purgeOperation: { _, _ in
                    purgeStarted.signal()
                    XCTAssertEqual(lockAttempting.wait(timeout: .now() + 1), .success)
                    XCTAssertEqual(
                        competingLockAcquired.wait(timeout: .now() + 0.1),
                        .timedOut,
                        "a competing schema writer acquired the lock during purge"
                    )
                    throw APSError.persistenceFailed(key: "note")
                },
                schemaWriter: { document, stateRoot in
                    try UserSchema.write(document, stateRoot: stateRoot)
                }
            )
        )

        XCTAssertEqual(competingLockAcquired.wait(timeout: .now() + 1), .success)
        XCTAssertNotNil(try store.resolve("note"))
    }

    @MainActor
    func testRegistrySetHoldsSchemaLockFromResolutionThroughStorageWrite() async throws {
        let store = StateStore()
        let root = FileManager.defaultFileStatePath
        let entry = SchemaKeyEntry(
            name: "orphanCandidate",
            type: "String",
            storage: "FileState",
            initial: .string(""),
            path: "orphan-candidate.json",
            doc: "concurrent removal regression"
        )
        try store.addKey(entry, force: false)

        let writeResolved = DispatchSemaphore(value: 0)
        let removalAttempting = DispatchSemaphore(value: 0)
        let removalAcquired = DispatchSemaphore(value: 0)
        let removalFinished = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            writeResolved.wait()
            removalAttempting.signal()
            defer { removalFinished.signal() }
            try? SchemaFileLock.withExclusiveLock(stateRoot: root) {
                var schema = try UserSchema.loadOrMaterializeUnlocked(stateRoot: root)
                schema.keys.removeAll { $0.name == entry.name }
                let schemaData = try JSONEncoder().encode(schema)
                let schemaURL = URL(fileURLWithPath: root).appendingPathComponent(UserSchema.fileName)
                try schemaData.write(to: schemaURL, options: .atomic)
                let dataURL = URL(fileURLWithPath: root).appendingPathComponent("orphan-candidate.json")
                try? FileManager.default.removeItem(at: dataURL)
                removalAcquired.signal()
            }
        }

        let persistedEntry = try store.set(
            name: entry.name,
            value: "must-be-purged",
            storageOperation: { resolved, value, stateRoot, schema in
                writeResolved.signal()
                XCTAssertEqual(removalAttempting.wait(timeout: .now() + 1), .success)
                XCTAssertEqual(
                    removalAcquired.wait(timeout: .now() + 0.1),
                    .timedOut,
                    "schema removal acquired the lock between resolution and persistence"
                )
                try DynamicKeyStorage.set(
                    entry: resolved,
                    value: value,
                    stateRoot: stateRoot,
                    schema: schema
                )
            }
        )

        XCTAssertEqual(persistedEntry, entry)
        XCTAssertEqual(removalFinished.wait(timeout: .now() + 10), .success)
        XCTAssertEqual(removalAcquired.wait(timeout: .now() + 10), .success)
        XCTAssertThrowsError(try store.resolve(entry.name)) { error in
            XCTAssertEqual(error as? APSError, .unknownKey(name: entry.name))
        }
        let dataURL = URL(fileURLWithPath: root).appendingPathComponent("orphan-candidate.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dataURL.path))
    }

    @MainActor
    func testProfileNameAdapterResetHoldsStorageLockThroughRefreshAndRewrite() async throws {
        let store = StateStore()
        let root = FileManager.defaultFileStatePath
        try store.set(.profile, value: #"{"name":"before","version":7}"#)
        let adapterEntered = DispatchSemaphore(value: 0)
        let competingWriterAttempting = DispatchSemaphore(value: 0)
        let competingWriterAcquired = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            adapterEntered.wait()
            competingWriterAttempting.signal()
            if (try? SchemaFileLock.withExclusiveStorageLock(
                stateRoot: root,
                lockFileName: "profile.json.lock",
                resourceKey: "profileName"
            ) {}) != nil {
                competingWriterAcquired.signal()
            }
        }

        let outcome = try store.reset(
            .profileName,
            afterAcquiringProfileStorageLock: {
                adapterEntered.signal()
                XCTAssertEqual(competingWriterAttempting.wait(timeout: .now() + 1), .success)
                XCTAssertEqual(
                    competingWriterAcquired.wait(timeout: .now() + 0.1),
                    .timedOut,
                    "a competing profile writer acquired the lock during adapter synchronization"
                )
            }
        )

        XCTAssertEqual(competingWriterAcquired.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(outcome, ResetOutcome(key: DemoKey.profileName.rawValue))
        XCTAssertEqual(try store.profileDocument(), ProfileDocument(name: "", version: 7))
    }

    @MainActor
    func testResetAllRegisteredFailsFastWithDeterministicReportAndStats() async throws {
        let root = FileManager.defaultFileStatePath
        let entries = [
            SchemaKeyEntry(
                name: "alpha",
                type: "String",
                storage: "State",
                initial: .string("initial"),
                doc: "successful first reset"
            ),
            SchemaKeyEntry(
                name: "blocked",
                type: "String",
                storage: "Slice",
                initial: .string("initial"),
                doc: "corrupt-parent reset failure",
                sliceOf: "parent",
                sliceField: "name"
            ),
            SchemaKeyEntry(
                name: "parent",
                type: "object",
                storage: "FileState",
                initial: .object(["name": .string("initial")]),
                path: "parent.json",
                doc: "corrupt slice parent",
                objectShape: ["name": "String"]
            ),
            SchemaKeyEntry(
                name: "omega",
                type: "String",
                storage: "State",
                initial: .string("initial"),
                doc: "must not be attempted"
            ),
        ]
        try UserSchema.write(UserSchemaDocument(keys: entries), stateRoot: root)
        try Data("{".utf8).write(
            to: URL(fileURLWithPath: root).appendingPathComponent("parent.json")
        )
        let store = StateStore()

        #if canImport(Combine)
        var statsPublicationCount = 0
        var statsPublishedAfterSchemaUnlock = false
        let cancellable = Application.dependency(\.stats).$mutationCount
            .dropFirst()
            .sink { _ in
                statsPublicationCount += 1
                let lockAcquired = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    if (try? SchemaFileLock.withExclusiveLock(stateRoot: root) {}) != nil {
                        lockAcquired.signal()
                    }
                }
                statsPublishedAfterSchemaUnlock = lockAcquired.wait(timeout: .now() + 1) == .success
            }
        defer { cancellable.cancel() }
        #endif

        XCTAssertThrowsError(try store.resetAllRegistered()) { error in
            guard let bulkError = error as? BulkResetError else {
                return XCTFail("Expected BulkResetError, got \(error)")
            }
            XCTAssertEqual(bulkError.underlying, .corruptState(key: "parent"))
            XCTAssertEqual(bulkError.report.reset, ["alpha"])
            XCTAssertEqual(bulkError.report.failed?.key, "blocked")
            XCTAssertEqual(bulkError.report.failed?.code, "corrupt_state")
            XCTAssertEqual(bulkError.report.failed?.exitCode, 65)
            XCTAssertEqual(bulkError.report.notAttempted, ["parent", "omega"])
        }

        let stats = store.statsSnapshot()
        XCTAssertEqual(stats.mutationCount, 1)
        XCTAssertEqual(stats.lastMutatedKey, "alpha")
        #if canImport(Combine)
        XCTAssertEqual(statsPublicationCount, 1)
        XCTAssertTrue(statsPublishedAfterSchemaUnlock)
        #endif
    }

    func testSuccessfulBulkResetReportEncodesInResetPayload() throws {
        let report = BulkResetReport.success(reset: ["alpha", "omega"])
        let payload = CLIOutput.ResetPayload(
            reset: "registered",
            key: nil,
            value: nil,
            report: report
        )

        let line = try CLIOutput.encodeLine(payload)
        let data = try XCTUnwrap(line.data(using: .utf8))
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let encodedReport = try XCTUnwrap(object["report"] as? [String: Any])

        XCTAssertEqual(object["reset"] as? String, "registered")
        XCTAssertNil(object["key"])
        XCTAssertNil(object["value"])
        XCTAssertEqual(encodedReport["reset"] as? [String], ["alpha", "omega"])
        XCTAssertNil(encodedReport["failed"])
        XCTAssertEqual(encodedReport["notAttempted"] as? [String], [])
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

    @MainActor
    internal func testStoredStatePresentUndecodableCanonicalValueIsCorrupt() async throws {
        let defaults = try XCTUnwrap(hermeticDefaults)
        let entry = SchemaKeyEntry(
            name: "corruptCounter",
            type: "Int",
            storage: "StoredState",
            initial: .int(7)
        )
        let schema = UserSchemaDocument(keys: [entry])
        let corrupt = try JSONEncoder().encode("not-an-int")
        defaults.set(corrupt, forKey: "aps.user.corruptCounter")

        XCTAssertThrowsError(
            try DynamicKeyStorage.get(entry: entry, stateRoot: "/tmp", schema: schema)
        ) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: entry.name))
        }
        XCTAssertEqual(defaults.object(forKey: "aps.user.corruptCounter") as? Data, corrupt)
    }

    @MainActor
    internal func testStoredStatePresentUndecodableLegacyFlagIsCorrupt() async throws {
        let defaults = try XCTUnwrap(hermeticDefaults)
        let entry = try XCTUnwrap(UserSchema.defaultDocument().keys.first { $0.name == "flag" })
        let schema = UserSchemaDocument(keys: [entry])
        let corrupt = try JSONEncoder().encode("not-a-bool")
        defaults.set(corrupt, forKey: "App/aps.flag")

        XCTAssertThrowsError(
            try DynamicKeyStorage.get(entry: entry, stateRoot: "/tmp", schema: schema)
        ) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: entry.name))
        }
        XCTAssertNil(defaults.object(forKey: "aps.user.flag"))
        XCTAssertEqual(defaults.object(forKey: "App/aps.flag") as? Data, corrupt)
    }

    @MainActor
    internal func testStoredStateIntRejectsNSNumberBooleanKind() async throws {
        let defaults = try XCTUnwrap(hermeticDefaults)
        let entry = SchemaKeyEntry(
            name: "numberKindCounter",
            type: "Int",
            storage: "StoredState",
            initial: .int(7)
        )
        let schema = UserSchemaDocument(keys: [entry])
        defaults.set(NSNumber(value: true), forKey: "aps.user.\(entry.name)")

        XCTAssertThrowsError(
            try DynamicKeyStorage.get(entry: entry, stateRoot: "/tmp", schema: schema)
        ) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: entry.name))
        }
    }

    @MainActor
    internal func testStoredStateBoolRejectsNSNumberIntegerKind() async throws {
        let defaults = try XCTUnwrap(hermeticDefaults)
        let entry = SchemaKeyEntry(
            name: "numberKindFlag",
            type: "Bool",
            storage: "StoredState",
            initial: .bool(false)
        )
        let schema = UserSchemaDocument(keys: [entry])
        defaults.set(NSNumber(value: 1), forKey: "aps.user.\(entry.name)")

        XCTAssertThrowsError(
            try DynamicKeyStorage.get(entry: entry, stateRoot: "/tmp", schema: schema)
        ) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: entry.name))
        }
    }

}

extension APSTests {
    @MainActor
    internal func testPublicResetAllUsesSchemaOrderInFailureReport() async throws {
        let defaults = UserSchema.defaultDocument().keys
        let orderedNames = ["message", "counter", "profileName", "profile"]
        let entries = try orderedNames.map { name in
            try XCTUnwrap(defaults.first(where: { $0.name == name }))
        }
        let root = FileManager.defaultFileStatePath
        try UserSchema.write(UserSchemaDocument(keys: entries), stateRoot: root)
        try Data("{".utf8).write(
            to: URL(fileURLWithPath: root).appendingPathComponent("profile.json")
        )
        let store = StateStore()

        XCTAssertThrowsError(try store.resetAll()) { error in
            guard let bulkError = error as? BulkResetError else {
                return XCTFail("Expected BulkResetError, got \(error)")
            }
            XCTAssertEqual(bulkError.report.reset, ["message", "counter"])
            XCTAssertEqual(bulkError.report.failed?.key, "profileName")
            XCTAssertEqual(bulkError.report.notAttempted, ["profile"])
        }
    }

    @MainActor
    internal func testBulkResetRejectsSliceInvalidatedByLaterParentBeforeMutation() async throws {
        let slice = SchemaKeyEntry(
            name: "childName",
            type: "String",
            storage: "Slice",
            initial: .string("child-initial"),
            doc: "child",
            sliceOf: "parent",
            sliceField: "name"
        )
        let parent = SchemaKeyEntry(
            name: "parent",
            type: "object",
            storage: "FileState",
            initial: .object(["name": .string("parent-initial")]),
            path: "parent.json",
            doc: "parent",
            objectShape: ["name": "String"]
        )
        let root = FileManager.defaultFileStatePath
        try UserSchema.write(UserSchemaDocument(keys: [slice, parent]), stateRoot: root)
        let store = StateStore()
        try store.set(name: "parent", value: #"{"name":"current"}"#)

        XCTAssertThrowsError(try store.resetAllRegistered()) { error in
            guard let bulkError = error as? BulkResetError else {
                return XCTFail("Expected BulkResetError, got \(error)")
            }
            XCTAssertEqual(bulkError.report.reset, [])
            XCTAssertEqual(bulkError.report.failed?.key, "childName")
            XCTAssertEqual(bulkError.report.failed?.code, "schema_invalid")
            XCTAssertEqual(bulkError.report.notAttempted, ["parent"])
        }

        XCTAssertEqual(try store.get(name: "parent"), #"{"name":"current"}"#)
        XCTAssertEqual(store.statsSnapshot().mutationCount, 1)
    }

    @MainActor
    internal func testBulkResetRejectsParentInvalidatedByLaterSliceBeforeMutation() async throws {
        let parent = SchemaKeyEntry(
            name: "parent",
            type: "object",
            storage: "FileState",
            initial: .object(["name": .string("parent-initial")]),
            path: "parent.json",
            doc: "parent",
            objectShape: ["name": "String"]
        )
        let slice = SchemaKeyEntry(
            name: "childName",
            type: "String",
            storage: "Slice",
            initial: .string("child-initial"),
            doc: "child",
            sliceOf: "parent",
            sliceField: "name"
        )
        let root = FileManager.defaultFileStatePath
        try UserSchema.write(UserSchemaDocument(keys: [parent, slice]), stateRoot: root)
        let store = StateStore()
        try store.set(name: "parent", value: #"{"name":"current"}"#)

        XCTAssertThrowsError(try store.resetAllRegistered()) { error in
            guard let bulkError = error as? BulkResetError else {
                return XCTFail("Expected BulkResetError, got \(error)")
            }
            XCTAssertEqual(bulkError.report.reset, [])
            XCTAssertEqual(bulkError.report.failed?.key, "parent")
            XCTAssertEqual(bulkError.report.failed?.code, "schema_invalid")
            XCTAssertEqual(bulkError.report.notAttempted, ["childName"])
        }

        XCTAssertEqual(try store.get(name: "parent"), #"{"name":"current"}"#)
        XCTAssertEqual(store.statsSnapshot().mutationCount, 1)
    }

    @MainActor
    internal func testBulkResetRejectsConflictingSiblingSlicesBeforeMutation() async throws {
        let first = SchemaKeyEntry(
            name: "firstName",
            type: "String",
            storage: "Slice",
            initial: .string("first-initial"),
            doc: "first child",
            sliceOf: "parent",
            sliceField: "name"
        )
        let second = SchemaKeyEntry(
            name: "secondName",
            type: "String",
            storage: "Slice",
            initial: .string("second-initial"),
            doc: "second child",
            sliceOf: "parent",
            sliceField: "name"
        )
        let parent = SchemaKeyEntry(
            name: "parent",
            type: "object",
            storage: "FileState",
            initial: .object(["name": .string("first-initial")]),
            path: "parent.json",
            doc: "parent",
            objectShape: ["name": "String"]
        )
        let root = FileManager.defaultFileStatePath
        try UserSchema.write(UserSchemaDocument(keys: [first, second, parent]), stateRoot: root)
        let store = StateStore()
        try store.set(name: "parent", value: #"{"name":"current"}"#)

        XCTAssertThrowsError(try store.resetAllRegistered()) { error in
            guard let bulkError = error as? BulkResetError else {
                return XCTFail("Expected BulkResetError, got \(error)")
            }
            XCTAssertEqual(bulkError.report.reset, [])
            XCTAssertEqual(bulkError.report.failed?.key, "firstName")
            XCTAssertEqual(bulkError.report.failed?.code, "schema_invalid")
            XCTAssertEqual(bulkError.report.notAttempted, ["secondName", "parent"])
        }

        XCTAssertEqual(try store.get(name: "parent"), #"{"name":"current"}"#)
        XCTAssertEqual(store.statsSnapshot().mutationCount, 1)
    }

    @MainActor
    internal func testBulkResetRejectsTypeDistinctSiblingSliceInitials() async {
        let first = SchemaKeyEntry(
            name: "firstValue",
            type: "Int",
            storage: "Slice",
            initial: .int(1),
            doc: "first child",
            sliceOf: "parent",
            sliceField: "value"
        )
        let second = SchemaKeyEntry(
            name: "secondValue",
            type: "String",
            storage: "Slice",
            initial: .string("1"),
            doc: "second child",
            sliceOf: "parent",
            sliceField: "value"
        )
        let schema = UserSchemaDocument(keys: [first, second])
        let store = StateStore()

        let error = store.bulkResetCompatibilityError(
            for: first.name,
            at: 0,
            selectedNames: [first.name, second.name],
            schema: schema
        )

        XCTAssertEqual(
            error,
            .schemaInvalid(
                reason: "firstValue initial conflicts with selected sibling slice 'secondValue'"
            )
        )
    }

    @MainActor
    internal func testSchemaRejectsDifferentSiblingSliceTypesForOneDeclaredField() async {
        let first = SchemaKeyEntry(
            name: "firstValue",
            type: "Int",
            storage: "Slice",
            initial: .int(1),
            doc: "integer child",
            sliceOf: "parent",
            sliceField: "value"
        )
        let second = SchemaKeyEntry(
            name: "secondValue",
            type: "String",
            storage: "Slice",
            initial: .string("1"),
            doc: "string child",
            sliceOf: "parent",
            sliceField: "value"
        )
        let parent = SchemaKeyEntry(
            name: "parent",
            type: "object",
            storage: "FileState",
            initial: .object(["value": .int(1)]),
            path: "parent.json",
            doc: "typed parent",
            objectShape: ["value": "Int"]
        )
        let root = FileManager.defaultFileStatePath
        XCTAssertThrowsError(
            try UserSchema.write(
                UserSchemaDocument(keys: [first, second, parent]),
                stateRoot: root
            )
        ) { error in
            XCTAssertEqual(
                error as? APSError,
                .schemaInvalid(
                    reason: "secondValue type 'String' must match parent.value type 'Int'"
                )
            )
        }
    }

    @MainActor
    internal func testSchemaRejectsMissingDeclaredParentInitialField() async {
        let parent = SchemaKeyEntry(
            name: "parent",
            type: "object",
            storage: "FileState",
            initial: .object([:]),
            path: "parent.json",
            doc: "parent",
            objectShape: ["name": "String"]
        )
        let slice = SchemaKeyEntry(
            name: "childName",
            type: "String",
            storage: "Slice",
            initial: .string("slice-initial"),
            doc: "child",
            sliceOf: "parent",
            sliceField: "name"
        )
        let root = FileManager.defaultFileStatePath
        XCTAssertThrowsError(
            try UserSchema.write(
                UserSchemaDocument(keys: [parent, slice]),
                stateRoot: root
            )
        ) { error in
            XCTAssertEqual(
                error as? APSError,
                .schemaInvalid(reason: "parent object initial requires field 'name'")
            )
        }
    }

    @MainActor
    internal func testBulkResetRejectsTypeDistinctParentAndSliceInitials() async {
        let parent = SchemaKeyEntry(
            name: "parent",
            type: "object",
            storage: "FileState",
            initial: .object(["value": .int(1)]),
            path: "parent.json",
            doc: "parent",
            objectShape: ["value": "Int"]
        )
        let slice = SchemaKeyEntry(
            name: "childValue",
            type: "String",
            storage: "Slice",
            initial: .string("1"),
            doc: "child",
            sliceOf: "parent",
            sliceField: "value"
        )
        let schema = UserSchemaDocument(keys: [parent, slice])
        let store = StateStore()

        let error = store.bulkResetCompatibilityError(
            for: parent.name,
            at: 0,
            selectedNames: [parent.name, slice.name],
            schema: schema
        )

        XCTAssertEqual(
            error,
            .schemaInvalid(
                reason: "childValue initial conflicts with selected parent reset 'parent'"
            )
        )
    }

    @MainActor
    internal func testDocumentationOnlyDefaultChangeStillUsesDemoAdapter() async throws {
        var schema = UserSchema.defaultDocument()
        let flagIndex = try XCTUnwrap(schema.keys.firstIndex(where: { $0.name == "flag" }))
        schema.keys[flagIndex].doc = "Updated documentation without a behavior change."
        try UserSchema.write(schema, stateRoot: FileManager.defaultFileStatePath)
        let store = StateStore()

        try store.set(.flag, value: "true")

        XCTAssertEqual(store.get(.flag), "true")
        XCTAssertEqual(try store.get(name: "flag"), "true")
        XCTAssertNotNil(hermeticDefaults?.object(forKey: "App/aps.flag"))
        XCTAssertEqual(hermeticDefaults?.object(forKey: "aps.user.flag") as? Bool, true)
    }

    @MainActor
    internal func testDefaultFlagWriteAfterResetAlignsCanonicalAndLegacyStorage() async throws {
        let store = StateStore()
        _ = try store.reset(.flag)

        try store.set(.flag, value: "true")

        let legacyData = try XCTUnwrap(hermeticDefaults?.object(forKey: "App/aps.flag") as? Data)
        XCTAssertEqual(try JSONDecoder().decode(Bool.self, from: legacyData), true)
        XCTAssertEqual(hermeticDefaults?.object(forKey: "aps.user.flag") as? Bool, true)
        XCTAssertEqual(store.get(.flag), "true")
        XCTAssertEqual(try store.get(name: "flag"), "true")
    }

    @MainActor
    internal func testRollbackFailureRetainsOriginalPurgeDiagnostic() async throws {
        let store = StateStore()
        _ = try store.loadSchema()
        var schemaWriteCount = 0

        XCTAssertThrowsError(
            try store.removeKey(
                name: "note",
                purge: true,
                purgeOperation: { _, _ in
                    throw APSError.persistenceFailed(key: "note-data")
                },
                schemaWriter: { document, root in
                    schemaWriteCount += 1
                    if schemaWriteCount == 2 {
                        throw APSError.persistenceFailed(key: UserSchema.fileName)
                    }
                    try UserSchema.write(document, stateRoot: root)
                }
            )
        ) { error in
            guard
                let domainError = error as? APSError,
                case .rollbackFailed(let context, let purgeCode, let purgeDescription) = domainError
            else {
                return XCTFail("Expected rollbackFailed, got \(error)")
            }
            XCTAssertEqual(context, .schema(key: "note"))
            XCTAssertEqual(purgeCode, "persistence_failed")
            XCTAssertEqual(purgeDescription, "Failed to persist note-data")
            XCTAssertTrue(domainError.description.contains("note-data"))
        }
    }

    internal func testHumanBulkFailureNamesSelectedKeyWhenStorageErrorNamesParent() {
        let underlying = APSError.corruptState(key: "parent")
        let report = BulkResetReport(
            reset: ["alpha"],
            failed: ResetFailure(key: "blocked", error: underlying),
            notAttempted: ["omega"]
        )

        XCTAssertEqual(
            CLIOutput.bulkFailureHumanLines(report),
            [
                "Reset: alpha",
                "Failed: blocked",
                "Not attempted: omega",
            ]
        )
    }

    internal func testBulkResetReportSchemaMarksOmittedFailureOptional() throws {
        let json = try CLIOutput.encodeLine(Schema.staticDocument())
        let data = try XCTUnwrap(json.data(using: .utf8))
        let document = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let payloads = try XCTUnwrap(document["payloads"] as? [String: Any])
        let report = try XCTUnwrap(payloads["BulkResetReport"] as? [String: Any])
        let required = try XCTUnwrap(report["required"] as? [String])
        let properties = try XCTUnwrap(report["properties"] as? [String: Any])
        let failed = try XCTUnwrap(properties["failed"] as? [String: Any])

        XCTAssertFalse(required.contains("failed"))
        XCTAssertEqual(failed["type"] as? String, "ResetFailure")
    }

    @MainActor
    internal func testStoredStateResetRejectsDroppedInitialWrite() async throws {
        let defaults = DroppingWritesUserDefaults()
        let override = Application.override(\Application.userDefaults, with: defaults)
        defer { _ = override }
        let entry = SchemaKeyEntry(
            name: "droppedReset",
            type: "String",
            storage: "StoredState",
            initial: .string("initial"),
            path: nil,
            doc: "Dropped reset write"
        )
        let schema = UserSchemaDocument(keys: [entry])

        XCTAssertThrowsError(
            try DynamicKeyStorage.reset(entry: entry, stateRoot: "/tmp", schema: schema)
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: entry.name))
        }
        XCTAssertNil(defaults.object(forKey: "aps.user.\(entry.name)"))
    }

    @MainActor
    internal func testStoredStateSetRejectsDroppedCanonicalWriteAndRestoresPriorObject() async throws {
        let defaults = OneShotDroppingUserDefaults()
        let canonicalKey = "aps.user.droppedSet"
        defaults.seed("before", forKey: canonicalKey)
        defaults.dropNextSet(forKey: canonicalKey)
        let override = Application.override(\Application.userDefaults, with: defaults)
        defer { _ = override }
        let entry = SchemaKeyEntry(
            name: "droppedSet",
            type: "String",
            storage: "StoredState",
            initial: .string("initial"),
            doc: "Dropped registered set write"
        )
        let schema = UserSchemaDocument(keys: [entry])

        XCTAssertThrowsError(
            try DynamicKeyStorage.set(
                entry: entry,
                value: "after",
                stateRoot: "/tmp",
                schema: schema
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: entry.name))
        }
        XCTAssertEqual(defaults.object(forKey: canonicalKey) as? String, "before")
    }
}

/// Locked storage makes this synchronous test double safe across Sendable boundaries.
private final class DroppingWritesUserDefaults: UserDefaultsManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]

    fileprivate func object(forKey key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    fileprivate func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    fileprivate func set(_ value: Any?, forKey key: String) {
        // Model a UserDefaults backend that accepts the call but loses the write.
    }
}

extension APSTests {
    @MainActor
    internal func testStoredStateResetRestoresCanonicalAndLegacyObjectsAfterVerificationFailure() async throws {
        let defaults = OneShotDroppingUserDefaults()
        let canonicalKey = "aps.user.flag"
        let legacyKey = "App/aps.flag"
        let oldCanonical = try JSONEncoder().encode(true)
        let oldLegacy = try JSONEncoder().encode(false)
        defaults.seed(oldCanonical, forKey: canonicalKey)
        defaults.seed(oldLegacy, forKey: legacyKey)
        defaults.dropNextSet(forKey: canonicalKey)

        let overrideToken = Application.override(\Application.userDefaults, with: defaults)
        defer { _ = overrideToken }
        let entry = SchemaKeyEntry(
            name: "flag",
            type: "Bool",
            storage: "StoredState",
            initial: .bool(false),
            doc: "Transactional StoredState reset"
        )
        let schema = UserSchemaDocument(keys: [entry])

        XCTAssertThrowsError(
            try DynamicKeyStorage.reset(entry: entry, stateRoot: "/tmp", schema: schema)
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: entry.name))
        }
        XCTAssertEqual(defaults.object(forKey: canonicalKey) as? Data, oldCanonical)
        XCTAssertEqual(defaults.object(forKey: legacyKey) as? Data, oldLegacy)
    }

    @MainActor
    internal func testStoredStateResetRestoresCanonicalObjectAfterSynchronizationFailure() async throws {
        let defaults = OneShotFailingSynchronizationUserDefaults()
        let canonicalKey = "aps.user.syncFailure"
        let oldCanonical = try JSONEncoder().encode("before")
        defaults.set(oldCanonical, forKey: canonicalKey)
        defaults.failNextSynchronization()

        let overrideToken = Application.override(\Application.userDefaults, with: defaults)
        defer { _ = overrideToken }
        let entry = SchemaKeyEntry(
            name: "syncFailure",
            type: "String",
            storage: "StoredState",
            initial: .string("after"),
            doc: "Transactional synchronization failure"
        )
        let schema = UserSchemaDocument(keys: [entry])

        XCTAssertThrowsError(
            try DynamicKeyStorage.reset(entry: entry, stateRoot: "/tmp", schema: schema)
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: entry.name))
        }
        XCTAssertEqual(defaults.object(forKey: canonicalKey) as? Data, oldCanonical)
    }

    @MainActor
    internal func testStoredStatePurgeRestoresCanonicalAndLegacyObjectsAfterSynchronizationFailure() async throws {
        let defaults = OneShotFailingSynchronizationUserDefaults()
        let canonicalKey = "aps.user.flag"
        let legacyKey = "App/aps.flag"
        let oldCanonical = try JSONEncoder().encode(true)
        let oldLegacy = try JSONEncoder().encode(false)
        defaults.set(oldCanonical, forKey: canonicalKey)
        defaults.set(oldLegacy, forKey: legacyKey)
        defaults.failNextSynchronization()

        let overrideToken = Application.override(\Application.userDefaults, with: defaults)
        defer { _ = overrideToken }
        let entry = SchemaKeyEntry(
            name: "flag",
            type: "Bool",
            storage: "StoredState",
            initial: .bool(false),
            doc: "Transactional StoredState purge"
        )

        XCTAssertThrowsError(
            try DynamicKeyStorage.purge(entry: entry, stateRoot: "/tmp")
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: entry.name))
        }
        XCTAssertEqual(defaults.object(forKey: canonicalKey) as? Data, oldCanonical)
        XCTAssertEqual(defaults.object(forKey: legacyKey) as? Data, oldLegacy)
    }

    @MainActor
    internal func testStoredStateResetReportsRollbackFailureWhenRestorationCannotSynchronize() async throws {
        let defaults = OneShotFailingSynchronizationUserDefaults()
        let canonicalKey = "aps.user.doubleSyncFailure"
        defaults.set("before", forKey: canonicalKey)
        defaults.failNextSynchronizations(count: 2)

        let overrideToken = Application.override(\Application.userDefaults, with: defaults)
        defer { _ = overrideToken }
        let entry = SchemaKeyEntry(
            name: "doubleSyncFailure",
            type: "String",
            storage: "StoredState",
            initial: .string("after"),
            doc: "Failed rollback synchronization"
        )
        let schema = UserSchemaDocument(keys: [entry])

        XCTAssertThrowsError(
            try DynamicKeyStorage.reset(entry: entry, stateRoot: "/tmp", schema: schema)
        ) { error in
            XCTAssertEqual(
                error as? APSError,
                .rollbackFailed(
                    context: .storedState(key: entry.name),
                    originalErrorCode: "persistence_failed",
                    originalErrorDescription: "Failed to persist \(entry.name)"
                )
            )
        }
    }

    @MainActor
    internal func testStoredStateResetReportsRollbackFailureWhenRestorationWriteIsDropped() async throws {
        let defaults = DroppedRollbackUserDefaults()
        let canonicalKey = "aps.user.droppedRollback"
        defaults.seed("before", forKey: canonicalKey)

        let overrideToken = Application.override(\Application.userDefaults, with: defaults)
        defer { _ = overrideToken }
        let entry = SchemaKeyEntry(
            name: "droppedRollback",
            type: "String",
            storage: "StoredState",
            initial: .string("after"),
            doc: "Dropped rollback write"
        )
        let schema = UserSchemaDocument(keys: [entry])

        XCTAssertThrowsError(
            try DynamicKeyStorage.reset(entry: entry, stateRoot: "/tmp", schema: schema)
        ) { error in
            XCTAssertEqual(
                error as? APSError,
                .rollbackFailed(
                    context: .storedState(key: entry.name),
                    originalErrorCode: "persistence_failed",
                    originalErrorDescription: "Failed to persist \(entry.name)"
                )
            )
        }
        XCTAssertEqual(defaults.object(forKey: canonicalKey) as? String, "after")
    }

    @MainActor
    internal func testBoolSliceResetVerifiesJSONBooleanUsingDeclaredShape() async throws {
        let parent = SchemaKeyEntry(
            name: "preferences",
            type: "object",
            storage: "FileState",
            initial: .object(["enabled": .bool(true)]),
            path: "preferences.json",
            doc: "Boolean slice parent",
            objectShape: ["enabled": "Bool"]
        )
        let slice = SchemaKeyEntry(
            name: "enabled",
            type: "Bool",
            storage: "Slice",
            initial: .bool(false),
            doc: "Boolean slice",
            sliceOf: parent.name,
            sliceField: "enabled"
        )
        let schema = UserSchemaDocument(keys: [parent, slice])
        let root = FileManager.defaultFileStatePath

        try DynamicKeyStorage.set(
            entry: parent,
            value: #"{"enabled":true}"#,
            stateRoot: root,
            schema: schema
        )

        let outcome = try DynamicKeyStorage.reset(entry: slice, stateRoot: root, schema: schema)

        XCTAssertEqual(outcome, ResetOutcome(key: slice.name))
        XCTAssertEqual(
            try DynamicKeyStorage.get(entry: slice, stateRoot: root, schema: schema),
            "false"
        )
    }

    @MainActor
    internal func testSchemaRejectsUnshapedBoolSlice() async {
        let parent = SchemaKeyEntry(
            name: "preferences",
            type: "object",
            storage: "FileState",
            initial: .object(["enabled": .bool(true)]),
            path: "preferences.json",
            doc: "Unshaped Boolean slice parent",
            objectShape: [:]
        )
        let slice = SchemaKeyEntry(
            name: "enabled",
            type: "Bool",
            storage: "Slice",
            initial: .bool(false),
            doc: "Unshaped Boolean slice",
            sliceOf: parent.name,
            sliceField: "enabled"
        )
        let schema = UserSchemaDocument(keys: [parent, slice])

        XCTAssertThrowsError(try UserSchema.validate(schema)) { error in
            XCTAssertEqual(
                error as? APSError,
                .schemaInvalid(
                    reason: "enabled sliceField 'enabled' must be declared by preferences.objectShape"
                )
            )
        }
    }

    @MainActor
    internal func testShapedSlicesUseDeclaredTypesForSetAndResetRoundTrips() async throws {
        let parent = SchemaKeyEntry(
            name: "settings",
            type: "object",
            storage: "FileState",
            initial: .object([
                "label": .string("initial"),
                "count": .int(1),
                "enabled": .bool(true),
                "metadata": .object(["state": .string("initial")]),
            ]),
            path: "settings.json",
            doc: "Typed Slice parent",
            objectShape: [
                "label": "String",
                "count": "Int",
                "enabled": "Bool",
                "metadata": "object",
            ]
        )
        let stringSlice = SchemaKeyEntry(
            name: "settingsLabel",
            type: "String",
            storage: "Slice",
            initial: .string("reset"),
            doc: "Typed String Slice",
            sliceOf: parent.name,
            sliceField: "label"
        )
        let intSlice = SchemaKeyEntry(
            name: "settingsCount",
            type: "Int",
            storage: "Slice",
            initial: .int(2),
            doc: "Typed Int Slice",
            sliceOf: parent.name,
            sliceField: "count"
        )
        let boolSlice = SchemaKeyEntry(
            name: "settingsEnabled",
            type: "Bool",
            storage: "Slice",
            initial: .bool(false),
            doc: "Typed Bool Slice",
            sliceOf: parent.name,
            sliceField: "enabled"
        )
        let objectSlice = SchemaKeyEntry(
            name: "settingsMetadata",
            type: "object",
            storage: "Slice",
            initial: .object(["state": .string("reset")]),
            doc: "Typed object Slice",
            objectShape: ["state": "String"],
            sliceOf: parent.name,
            sliceField: "metadata"
        )
        let schema = UserSchemaDocument(keys: [
            parent,
            stringSlice,
            intSlice,
            boolSlice,
            objectSlice,
        ])
        try UserSchema.validate(schema)
        let root = FileManager.defaultFileStatePath
        let cases: [(entry: SchemaKeyEntry, set: String, reset: String)] = [
            (stringSlice, "set", "reset"),
            (intSlice, "9", "2"),
            (boolSlice, "true", "false"),
            (objectSlice, #"{"state":"set"}"#, #"{"state":"reset"}"#),
        ]

        for testCase in cases {
            try DynamicKeyStorage.set(
                entry: testCase.entry,
                value: testCase.set,
                stateRoot: root,
                schema: schema
            )
            XCTAssertEqual(
                try DynamicKeyStorage.get(entry: testCase.entry, stateRoot: root, schema: schema),
                testCase.set
            )
        }

        for testCase in cases {
            _ = try DynamicKeyStorage.reset(entry: testCase.entry, stateRoot: root, schema: schema)
            XCTAssertEqual(
                try DynamicKeyStorage.get(entry: testCase.entry, stateRoot: root, schema: schema),
                testCase.reset
            )
        }
    }

    internal func testPostconditionReadFailureRestoresStagedLeaf() throws {
        try withTransactionalDeletionStateRoot { root in
            let file = root.appendingPathComponent("value.json")
            let original = Data("keep".utf8)
            try original.write(to: file)
            let path = try SchemaStoragePath("value.json")
            let operations = SchemaStoragePath.DeletionOperations(
                removeItem: { url in
                    try FileManager.default.removeItem(at: url)
                },
                isAbsent: { url in
                    let isAbsent = !FileManager.default.fileExists(atPath: url.path)
                    if url.lastPathComponent == "value.json", isAbsent {
                        throw TransactionalDeletionFailure.postconditionRead
                    }
                    return isAbsent
                }
            )

            XCTAssertThrowsError(
                try path.removeRegularFileIfPresent(
                    stateRoot: root.path,
                    operations: operations
                )
            ) { error in
                XCTAssertEqual(error as? APSError, .persistenceFailed(key: "value.json"))
            }
            XCTAssertEqual(try Data(contentsOf: file), original)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy {
                !$0.contains(".aps-delete-")
            })
        }
    }

    internal func testStagedLeafMoveBackFailureReportsRollbackFailure() throws {
        try withTransactionalDeletionStateRoot { root in
            let file = root.appendingPathComponent("value.json")
            try Data("keep".utf8).write(to: file)
            let path = try SchemaStoragePath("value.json")
            let mover = MoveBackFailingDeletionMover()
            let operations = SchemaStoragePath.DeletionOperations(
                moveItem: { source, destination in
                    try mover.move(source, to: destination)
                },
                removeItem: { url in
                    try FileManager.default.removeItem(at: url)
                },
                isAbsent: { _ in
                    throw TransactionalDeletionFailure.postconditionRead
                }
            )

            XCTAssertThrowsError(
                try path.removeRegularFileIfPresent(
                    stateRoot: root.path,
                    operations: operations
                )
            ) { error in
                XCTAssertEqual(
                    error as? APSError,
                    .rollbackFailed(
                        context: .stagedFile(path: "value.json"),
                        originalErrorCode: "persistence_failed",
                        originalErrorDescription: "Failed to persist value.json"
                    )
                )
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).contains {
                $0.contains(".aps-delete-")
            })
        }
    }

    @MainActor
    internal func testFileStateLockNamesUseFullPortableRelativePath() async throws {
        let nestedSchema = SchemaKeyEntry(
            name: "nestedSchema",
            type: "String",
            storage: "FileState",
            initial: .string(""),
            path: "nested/schema.json",
            doc: "Nested schema leaf"
        )
        let otherSchema = SchemaKeyEntry(
            name: "otherSchema",
            type: "String",
            storage: "FileState",
            initial: .string(""),
            path: "other/schema.json",
            doc: "Other schema leaf"
        )
        let portableAlias = SchemaKeyEntry(
            name: "portableAlias",
            type: "String",
            storage: "FileState",
            initial: .string(""),
            path: "NESTED/SCHEMA.JSON",
            doc: "Portable spelling alias"
        )

        let nestedLock = try DynamicKeyStorage.fileLockName(nestedSchema)
        XCTAssertEqual(nestedLock, try DynamicKeyStorage.fileLockName(nestedSchema))
        XCTAssertNotEqual(nestedLock, "schema.json.lock")
        XCTAssertNotEqual(nestedLock, try DynamicKeyStorage.fileLockName(otherSchema))
        XCTAssertEqual(nestedLock, try DynamicKeyStorage.fileLockName(portableAlias))
        XCTAssertTrue(nestedLock.hasPrefix("storage-"))
        XCTAssertTrue(nestedLock.hasSuffix(".lock"))
        let profile = try XCTUnwrap(
            UserSchema.defaultDocument().keys.first { $0.name == "profile" }
        )
        XCTAssertEqual(
            try DynamicKeyStorage.fileLockName(profile),
            "profile.json.lock"
        )
    }

    internal func testSecretResetPostconditionReadFailureRestoresEnvelope() throws {
        try withTransactionalDeletionStateRoot { root in
            let envelope = root.appendingPathComponent("custom.enc")
            let original = Data("encrypted-envelope".utf8)
            try original.write(to: envelope)
            let operations = SchemaStoragePath.DeletionOperations(
                removeItem: { url in
                    try FileManager.default.removeItem(at: url)
                },
                isAbsent: { url in
                    let isAbsent = !FileManager.default.fileExists(atPath: url.path)
                    if url.lastPathComponent == "custom.enc", isAbsent {
                        throw TransactionalDeletionFailure.postconditionRead
                    }
                    return isAbsent
                }
            )
            let store = SecretStore(
                directory: root.path,
                storeFileName: "custom.enc",
                keyName: "custom",
                deletionOperations: operations
            )

            XCTAssertThrowsError(try store.reset()) { error in
                XCTAssertEqual(error as? APSError, .persistenceFailed(key: "custom"))
            }
            XCTAssertEqual(try Data(contentsOf: envelope), original)
        }
    }

    internal func testStructuredBulkFailureKeepsHumanLineBeforeJSONEnvelope() throws {
        let error = transactionalBulkError()
        let lines = CLIOutput.bulkFailureOutputLines(error, structuredErrors: true)

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], "Error: \(error.description)")
        let data = try XCTUnwrap(lines[1].data(using: .utf8))
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let envelope = try XCTUnwrap(object["error"] as? [String: Any])
        XCTAssertEqual(envelope["code"] as? String, error.code)
        XCTAssertNotNil(envelope["report"])
    }

    internal func testHumanBulkFailureKeepsReportDetailsWithoutJSONEnvelope() {
        let error = transactionalBulkError()

        XCTAssertEqual(
            CLIOutput.bulkFailureOutputLines(error, structuredErrors: false),
            [
                "Error: \(error.description)",
                "Reset: alpha",
                "Failed: beta",
                "Not attempted: gamma",
            ]
        )
    }

    private func transactionalBulkError() -> BulkResetError {
        let underlying = APSError.persistenceFailed(key: "beta")
        return BulkResetError(
            report: BulkResetReport(
                reset: ["alpha"],
                failed: ResetFailure(key: "beta", error: underlying),
                notAttempted: ["gamma"]
            ),
            underlying: underlying
        )
    }

    private func withTransactionalDeletionStateRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-transactional-delete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}

private enum TransactionalDeletionFailure: Error, Sendable {
    case postconditionRead
    case moveBack
}

private final class MoveBackFailingDeletionMover: @unchecked Sendable {
    private let lock = NSLock()
    private var moveCount = 0

    fileprivate func move(_ source: URL, to destination: URL) throws {
        lock.lock()
        moveCount += 1
        let currentMove = moveCount
        lock.unlock()
        guard currentMove == 1 else {
            throw TransactionalDeletionFailure.moveBack
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }
}

/// UserDefaults test double that loses exactly one selected write.
private final class OneShotDroppingUserDefaults: UserDefaultsManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]
    private var droppedKey: String?

    fileprivate func object(forKey key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    fileprivate func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    fileprivate func set(_ value: Any?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        if droppedKey == key {
            droppedKey = nil
            return
        }
        storage[key] = value
    }

    fileprivate func seed(_ value: Any, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    fileprivate func dropNextSet(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        droppedKey = key
    }
}

/// In-memory UserDefaults test double that reports one deterministic synchronization failure.
private final class OneShotFailingSynchronizationUserDefaults:
    UserDefaultsSynchronizing,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storage: [String: Any] = [:]
    private var remainingSynchronizationFailures = 0

    fileprivate func object(forKey key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    fileprivate func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    fileprivate func set(_ value: Any?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    fileprivate func failNextSynchronization() {
        failNextSynchronizations(count: 1)
    }

    fileprivate func failNextSynchronizations(count: Int) {
        lock.lock()
        defer { lock.unlock() }
        remainingSynchronizationFailures = count
    }

    fileprivate func synchronize() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard remainingSynchronizationFailures > 0 else { return true }
        remainingSynchronizationFailures -= 1
        return false
    }
}

/// StoredState double that fails the forward sync and silently drops the rollback write.
private final class DroppedRollbackUserDefaults: UserDefaultsSynchronizing, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]
    private var failedForwardSynchronization = false

    fileprivate func object(forKey key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    fileprivate func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    fileprivate func set(_ value: Any?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        guard !failedForwardSynchronization else { return }
        storage[key] = value
    }

    fileprivate func seed(_ value: Any, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    fileprivate func synchronize() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !failedForwardSynchronization else { return true }
        failedForwardSynchronization = true
        return false
    }
}

/// Locked fault injector for deterministic FileState reset verification tests.
private final class ResetFileFaults: @unchecked Sendable {
    private let lock = NSLock()
    private var readCount = 0
    private var writeCount = 0
    private let failingRead: Int
    private let droppedWrites: Set<Int>

    fileprivate init(failingRead: Int, droppedWrites: Set<Int> = []) {
        self.failingRead = failingRead
        self.droppedWrites = droppedWrites
    }

    fileprivate var operations: DynamicKeyStorage.FileOperations {
        DynamicKeyStorage.FileOperations(
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            read: { [self] url in
                lock.lock()
                readCount += 1
                let shouldFail = readCount == failingRead
                lock.unlock()
                if shouldFail {
                    throw APSError.persistenceFailed(key: url.lastPathComponent)
                }
                return try Data(contentsOf: url)
            },
            write: { [self] data, url in
                lock.lock()
                writeCount += 1
                let shouldDrop = droppedWrites.contains(writeCount)
                lock.unlock()
                guard !shouldDrop else { return }
                try data.write(to: url, options: .atomic)
            },
            remove: { try FileManager.default.removeItem(at: $0) }
        )
    }
}

/// Replaces a newly written rollback target with a directory before failing verification.
private struct DirectoryReplacingReadFaults: Sendable {
    fileprivate let sentinel: Data

    fileprivate var operations: DynamicKeyStorage.FileOperations {
        DynamicKeyStorage.FileOperations(
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            read: { [sentinel] url in
                try FileManager.default.removeItem(at: url)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                try sentinel.write(to: url.appendingPathComponent("sentinel.txt"))
                throw APSError.persistenceFailed(key: url.lastPathComponent)
            },
            write: { try $0.write(to: $1, options: .atomic) },
            remove: { try FileManager.default.removeItem(at: $0) }
        )
    }
}

extension APSTests {
    @MainActor
    internal func testFileStateResetRestoresExactPriorBytesAfterVerificationFailure() async throws {
        let entry = SchemaKeyEntry(
            name: "transactionalFile",
            type: "object",
            storage: "FileState",
            initial: .object(["value": .string("after")]),
            path: "transactional-file.json",
            doc: "Transactional FileState reset"
        )
        let schema = UserSchemaDocument(keys: [entry])
        let url = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("transactional-file.json")
        let original = Data(#"{ "value" : "before", "spacing" : true }"#.utf8)
        try original.write(to: url)
        let faults = ResetFileFaults(failingRead: 2)

        XCTAssertThrowsError(
            try DynamicKeyStorage.reset(
                entry: entry,
                stateRoot: FileManager.defaultFileStatePath,
                schema: schema,
                fileOperations: faults.operations
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: entry.name))
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor
    internal func testFileStateResetRestoresPriorAbsenceAfterVerificationFailure() async throws {
        let entry = SchemaKeyEntry(
            name: "transactionalAbsentFile",
            type: "String",
            storage: "FileState",
            initial: .string("after"),
            path: "transactional-absent-file.json",
            doc: "Transactional absent FileState reset"
        )
        let schema = UserSchemaDocument(keys: [entry])
        let url = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("transactional-absent-file.json")
        let faults = ResetFileFaults(failingRead: 1)

        XCTAssertThrowsError(
            try DynamicKeyStorage.reset(
                entry: entry,
                stateRoot: FileManager.defaultFileStatePath,
                schema: schema,
                fileOperations: faults.operations
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: entry.name))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    internal func testAbsentFileRollbackRefusesReplacementDirectoryAndPreservesItsContents() async throws {
        let entry = SchemaKeyEntry(
            name: "hostileAbsentRollback",
            type: "String",
            storage: "FileState",
            initial: .string("after"),
            path: "hostile-absent-rollback.json",
            doc: "Hostile replacement during absent rollback"
        )
        let schema = UserSchemaDocument(keys: [entry])
        let url = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("hostile-absent-rollback.json")
        let sentinel = Data("must survive".utf8)
        let faults = DirectoryReplacingReadFaults(sentinel: sentinel)

        XCTAssertThrowsError(
            try DynamicKeyStorage.reset(
                entry: entry,
                stateRoot: FileManager.defaultFileStatePath,
                schema: schema,
                fileOperations: faults.operations
            )
        ) { error in
            XCTAssertEqual(
                error as? APSError,
                .rollbackFailed(
                    context: .fileState(path: "hostile-absent-rollback.json"),
                    originalErrorCode: "corrupt_state",
                    originalErrorDescription: APSError.corruptState(key: entry.name).description
                )
            )
        }
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(try Data(contentsOf: url.appendingPathComponent("sentinel.txt")), sentinel)
    }

    @MainActor
    internal func testSliceResetRestoresExactParentBytesAfterVerificationFailure() async throws {
        let parent = SchemaKeyEntry(
            name: "transactionalParent",
            type: "object",
            storage: "FileState",
            initial: .object(["name": .string("initial")]),
            path: "transactional-parent.json",
            doc: "Transactional Slice parent",
            objectShape: ["name": "String"]
        )
        let slice = SchemaKeyEntry(
            name: "transactionalSlice",
            type: "String",
            storage: "Slice",
            initial: .string("after"),
            doc: "Transactional Slice reset",
            sliceOf: parent.name,
            sliceField: "name"
        )
        let schema = UserSchemaDocument(keys: [parent, slice])
        let url = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("transactional-parent.json")
        let original = Data(#"{ "name" : "before", "version" : 7 }"#.utf8)
        try original.write(to: url)
        let faults = ResetFileFaults(failingRead: 3)

        XCTAssertThrowsError(
            try DynamicKeyStorage.reset(
                entry: slice,
                stateRoot: FileManager.defaultFileStatePath,
                schema: schema,
                fileOperations: faults.operations
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .corruptState(key: parent.name))
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor
    internal func testFileStateResetReportsRollbackFailureWhenPriorBytesCannotBeRestored() async throws {
        let entry = SchemaKeyEntry(
            name: "failedFileRollback",
            type: "String",
            storage: "FileState",
            initial: .string("after"),
            path: "failed-file-rollback.json",
            doc: "Failed FileState rollback"
        )
        let schema = UserSchemaDocument(keys: [entry])
        let url = URL(fileURLWithPath: FileManager.defaultFileStatePath)
            .appendingPathComponent("failed-file-rollback.json")
        try Data(#""before""#.utf8).write(to: url)
        let faults = ResetFileFaults(failingRead: 2, droppedWrites: [2])

        XCTAssertThrowsError(
            try DynamicKeyStorage.reset(
                entry: entry,
                stateRoot: FileManager.defaultFileStatePath,
                schema: schema,
                fileOperations: faults.operations
            )
        ) { error in
            XCTAssertEqual(
                error as? APSError,
                .rollbackFailed(
                    context: .fileState(path: "failed-file-rollback.json"),
                    originalErrorCode: "corrupt_state",
                    originalErrorDescription: APSError.corruptState(key: entry.name).description
                )
            )
        }
        XCTAssertEqual(try JSONDecoder().decode(String.self, from: Data(contentsOf: url)), "after")
    }
}
