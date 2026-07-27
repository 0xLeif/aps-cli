import Foundation
import XCTest
import Crypto
@testable import aps

#if os(Windows)
import WinSDK
#endif

internal final class SecretStoreSecurityTests: XCTestCase {
    private var directoryURL: URL?
    private var holdsIsolationGate = false

    internal override func setUp() async throws {
        try await super.setUp()
        await TestIsolationGate.shared.acquire()
        holdsIsolationGate = true

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-secret-security-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        directoryURL = directory
        setSecretPassphrase(nil)
        setUsePassphrase(nil)
    }

    internal override func tearDown() async throws {
        setSecretPassphrase(nil)
        setUsePassphrase(nil)
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        directoryURL = nil

        if holdsIsolationGate {
            await TestIsolationGate.shared.release()
            holdsIsolationGate = false
        }
        try await super.tearDown()
    }

    internal func testPassphraseSealPersistsExactVersionModeProfileAndRandomSalt() throws {
        setSecretPassphrase("metadata-passphrase")
        let fixture = try makeFixture()

        try fixture.store.set("metadata-secret")

        let envelope = try readEnvelope(from: fixture.envelopeURL)
        XCTAssertEqual(envelope.version, 2)
        XCTAssertEqual(envelope.recipientMode, SecretStore.RecipientMode.passphrase.rawValue)
        let metadata = try XCTUnwrap(envelope.kdf)
        XCTAssertEqual(metadata.algorithm, "scrypt")
        XCTAssertEqual(metadata.rounds, 131_072)
        XCTAssertEqual(metadata.blockSize, 8)
        XCTAssertEqual(metadata.parallelism, 1)
        XCTAssertEqual(metadata.outputByteCount, 32)
        XCTAssertEqual(try XCTUnwrap(Data(base64Encoded: metadata.salt)).count, 16)
    }

    internal func testResealingSamePassphraseAndPlaintextChangesSaltAndCiphertext() throws {
        setSecretPassphrase("repeat-passphrase")
        let fixture = try makeFixture()
        try fixture.store.set("same-plaintext")
        let first = try readEnvelope(from: fixture.envelopeURL)

        try fixture.store.set("same-plaintext")
        let second = try readEnvelope(from: fixture.envelopeURL)

        XCTAssertNotEqual(first.kdf?.salt, second.kdf?.salt)
        XCTAssertNotEqual(first.ciphertext, second.ciphertext)
    }

    internal func testSetInvokesExactScryptProfileOncePerDistinctSalt() throws {
        setSecretPassphrase("counted-passphrase")
        let recorder = KDFCallRecorder()
        let fixture = try makeFixture(recorder: recorder)

        try fixture.store.set("first")
        recorder.reset()
        try fixture.store.set("second")

        let calls = recorder.snapshot()
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(Set(calls.map(\.salt)).count, 2)
        for call in calls {
            XCTAssertEqual(call.password, Data("counted-passphrase".utf8))
            XCTAssertEqual(call.salt.count, 16)
            XCTAssertEqual(call.parameters, PasswordKDF.profile)
        }
    }

    internal func testMalformedAndHostileMetadataIsRejectedBeforeKDF() throws {
        setSecretPassphrase("metadata-validation")
        let recorder = KDFCallRecorder()
        let fixture = try makeFixture(recorder: recorder)
        let validPayload = validEnvelope()
        let malformedEnvelopes = [
            replacingMetadata(
                in: validPayload,
                with: SecretStore.ScryptMetadata(
                    algorithm: "not-scrypt",
                    salt: Data(repeating: 0x31, count: 16).base64EncodedString(),
                    rounds: PasswordKDF.profile.rounds,
                    blockSize: PasswordKDF.profile.blockSize,
                    parallelism: PasswordKDF.profile.parallelism,
                    outputByteCount: PasswordKDF.profile.outputByteCount
                )
            ),
            replacingMetadata(
                in: validPayload,
                with: SecretStore.ScryptMetadata(
                    algorithm: "scrypt",
                    salt: Data(repeating: 0x32, count: 16).base64EncodedString(),
                    rounds: Int.max,
                    blockSize: PasswordKDF.profile.blockSize,
                    parallelism: PasswordKDF.profile.parallelism,
                    outputByteCount: PasswordKDF.profile.outputByteCount
                )
            ),
            replacingMetadata(
                in: validPayload,
                with: SecretStore.ScryptMetadata(
                    algorithm: "scrypt",
                    salt: Data(repeating: 0x33, count: 1_024).base64EncodedString(),
                    rounds: PasswordKDF.profile.rounds,
                    blockSize: PasswordKDF.profile.blockSize,
                    parallelism: PasswordKDF.profile.parallelism,
                    outputByteCount: PasswordKDF.profile.outputByteCount
                )
            )
        ]

        for envelope in malformedEnvelopes {
            try JSONEncoder().encode(envelope).write(to: fixture.envelopeURL, options: .atomic)
            XCTAssertThrowsError(try fixture.store.get()) { error in
                XCTAssertEqual(error as? APSError, .decodingFailed)
            }
        }
        XCTAssertTrue(recorder.snapshot().isEmpty)
    }

    internal func testMalformedPayloadIsRejectedBeforeKDF() throws {
        setSecretPassphrase("payload-validation")
        let recorder = KDFCallRecorder()
        let fixture = try makeFixture(recorder: recorder)
        let valid = validEnvelope()
        let malformed = [
            replacingPayload(in: valid, ephemeralPublicKey: "not-base64"),
            replacingPayload(in: valid, nonce: Data(repeating: 0x01, count: 11).base64EncodedString()),
            replacingPayload(in: valid, ciphertext: "not-base64"),
            replacingPayload(in: valid, tag: Data(repeating: 0x02, count: 15).base64EncodedString()),
        ]

        for envelope in malformed {
            try JSONEncoder().encode(envelope).write(to: fixture.envelopeURL, options: .atomic)
            XCTAssertThrowsError(try fixture.store.get()) { error in
                XCTAssertEqual(error as? APSError, .decodingFailed)
            }
        }
        XCTAssertTrue(recorder.snapshot().isEmpty)
    }

    internal func testLowOrderEphemeralPointMapsKeyAgreementFailureToDecodingFailed() throws {
        setSecretPassphrase("low-order-point")
        let fixture = try makeFixture()
        try fixture.store.set("protected")
        let envelope = try readEnvelope(from: fixture.envelopeURL)
        let hostile = replacingPayload(
            in: envelope,
            ephemeralPublicKey: Data(repeating: 0, count: 32).base64EncodedString()
        )
        try JSONEncoder().encode(hostile).write(to: fixture.envelopeURL, options: .atomic)

        XCTAssertThrowsError(try fixture.store.get()) { error in
            XCTAssertEqual(error as? APSError, .decodingFailed)
        }
    }

    @MainActor
    internal func testScryptFailuresMapByFreshWriteUnlockWatchAndMigrationOperation() async throws {
        setSecretPassphrase("kdf-failure")
        let directory = try XCTUnwrap(directoryURL)
        let working = try makeFixture(directory: directory)
        try working.store.set("existing")

        let failure = PasswordKDFFailure()
        let failingKDF = PasswordKDF(
            operations: PasswordKDF.Operations { _, _, _ in throw failure }
        )
        let failing = try makeFixture(passwordKDF: failingKDF, directory: directory)
        XCTAssertThrowsError(try failing.store.get()) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }
        XCTAssertThrowsError(try failing.store.set("replacement")) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }
        XCTAssertThrowsError(
            try StateStore().watchEncryptedStore(
                failing.store,
                initialValue: "",
                pollInterval: 0,
                pollDeadline: nil,
                shouldContinue: { false },
                onChange: { _ in }
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }

        let freshDirectory = directory.appendingPathComponent("fresh", isDirectory: true)
        try FileManager.default.createDirectory(at: freshDirectory, withIntermediateDirectories: true)
        let fresh = try makeFixture(passwordKDF: failingKDF, directory: freshDirectory)
        XCTAssertThrowsError(try fresh.store.set("fresh")) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "secret"))
        }

        let legacyDirectory = directory.appendingPathComponent("legacy-kdf", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        let legacy = try makeLegacyEnvelope(value: "legacy", passphrase: "kdf-failure")
        try JSONEncoder().encode(legacy).write(
            to: legacyDirectory.appendingPathComponent("secret.enc"),
            options: .atomic
        )
        let failingLegacy = try makeFixture(passwordKDF: failingKDF, directory: legacyDirectory)
        XCTAssertThrowsError(
            try StateStore().watchEncryptedStore(
                failingLegacy.store,
                initialValue: "",
                pollInterval: 0,
                pollDeadline: nil,
                shouldContinue: { false },
                onChange: { _ in }
            )
        ) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "secret"))
        }
    }

    internal func testDuplicateSecurityFieldsAreRejectedBeforeKDF() throws {
        setSecretPassphrase("duplicate-validation")
        let recorder = KDFCallRecorder()
        let fixture = try makeFixture(recorder: recorder)
        let encoded = try JSONEncoder().encode(validEnvelope())
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        let duplicateVersion = json.replacingOccurrences(
            of: "{",
            with: #"{"version":2,"#,
            options: [],
            range: json.startIndex..<json.index(after: json.startIndex)
        )
        let duplicateAlgorithm = json.replacingOccurrences(
            of: #""algorithm":"scrypt""#,
            with: #""algorithm":"scrypt","algorithm":"scrypt""#
        )

        for duplicate in [duplicateVersion, duplicateAlgorithm] {
            try Data(duplicate.utf8).write(to: fixture.envelopeURL, options: .atomic)
            XCTAssertThrowsError(try fixture.store.get()) { error in
                XCTAssertEqual(error as? APSError, .decodingFailed)
            }
        }
        XCTAssertTrue(recorder.snapshot().isEmpty)
    }

    internal func testEncryptedSnapshotMapsConcurrentRemovalToMissing() throws {
        let fixture = try makeFixture(
            envelopeOperations: SecretStore.EnvelopeOperations(
                read: { _ in throw CocoaError(.fileReadNoSuchFile) },
                write: { _, _ in }
            )
        )

        XCTAssertNil(try fixture.store.encryptedSnapshot())
    }

    internal func testUnknownVersionAndModeUseUnsupportedEnvelopeError() throws {
        setSecretPassphrase("unsupported-metadata")
        let recorder = KDFCallRecorder()
        let fixture = try makeFixture(recorder: recorder)
        let validPayload = validEnvelope()
        let unsupported = [
            SecretStore.Envelope(
                version: 99,
                recipientMode: SecretStore.RecipientMode.passphrase.rawValue,
                kdf: validPayload.kdf,
                ephemeralPublicKey: validPayload.ephemeralPublicKey,
                nonce: validPayload.nonce,
                ciphertext: validPayload.ciphertext,
                tag: validPayload.tag
            ),
            SecretStore.Envelope(
                version: 2,
                recipientMode: "future-recipient",
                kdf: validPayload.kdf,
                ephemeralPublicKey: validPayload.ephemeralPublicKey,
                nonce: validPayload.nonce,
                ciphertext: validPayload.ciphertext,
                tag: validPayload.tag
            )
        ]

        for envelope in unsupported {
            try JSONEncoder().encode(envelope).write(to: fixture.envelopeURL, options: .atomic)
            XCTAssertThrowsError(try fixture.store.get()) { error in
                XCTAssertEqual(error as? APSError, .unsupportedSecretEnvelope)
            }
        }
        XCTAssertTrue(recorder.snapshot().isEmpty)
    }

    internal func testVersion2RecipientModeMismatchFailsWithoutChangingBytes() throws {
        setSecretPassphrase("mode-owner")
        let fixture = try makeFixture()
        try fixture.store.set("mode-protected")
        let original = try Data(contentsOf: fixture.envelopeURL)

        setSecretPassphrase(nil)
        XCTAssertThrowsError(try fixture.store.get()) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }

        XCTAssertEqual(try Data(contentsOf: fixture.envelopeURL), original)
    }

    internal func testLegacyPassphraseGetMigratesToVersion2AndWrongPassphrasePreservesBytes() throws {
        let fixture = try makeFixture()
        let legacy = try makeLegacyEnvelope(value: "legacy-secret", passphrase: "legacy-owner")
        let legacyData = try JSONEncoder().encode(legacy)
        try legacyData.write(to: fixture.envelopeURL, options: .atomic)
        XCTAssertNil(legacy.version)
        XCTAssertNil(legacy.recipientMode)
        XCTAssertNil(legacy.kdf)

        setSecretPassphrase("wrong-owner")
        XCTAssertThrowsError(try fixture.store.get()) { error in
            XCTAssertEqual(error as? APSError, .secretUnlockFailed)
        }
        XCTAssertEqual(try Data(contentsOf: fixture.envelopeURL), legacyData)

        setSecretPassphrase("legacy-owner")
        XCTAssertEqual(try fixture.store.get(), "legacy-secret")

        let migratedData = try Data(contentsOf: fixture.envelopeURL)
        let migrated = try JSONDecoder().decode(SecretStore.Envelope.self, from: migratedData)
        XCTAssertNotEqual(migratedData, legacyData)
        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(migrated.recipientMode, SecretStore.RecipientMode.passphrase.rawValue)
        XCTAssertEqual(migrated.kdf?.algorithm, "scrypt")
        XCTAssertEqual(try fixture.store.get(), "legacy-secret")
    }

    internal func testLegacyKeyFileReadsUnchangedAndUpgradesOnSet() throws {
        let fixture = try makeFixture()
        let recipient = Curve25519.KeyAgreement.PrivateKey()
        let encodedKey = recipient.rawRepresentation.base64EncodedData()
        try SecureKeyFile(path: fixture.keyFileURL.path).create(encodedKey)
        let legacyData = try JSONEncoder().encode(
            makeLegacyEnvelope(value: "legacy-key-file", recipient: recipient)
        )
        try legacyData.write(to: fixture.envelopeURL, options: .atomic)

        XCTAssertEqual(try fixture.store.get(), "legacy-key-file")
        XCTAssertEqual(try Data(contentsOf: fixture.envelopeURL), legacyData)
        XCTAssertEqual(try Data(contentsOf: fixture.keyFileURL), encodedKey)

        try fixture.store.set("upgraded-key-file")

        let upgraded = try readEnvelope(from: fixture.envelopeURL)
        XCTAssertEqual(upgraded.version, 2)
        XCTAssertEqual(upgraded.recipientMode, SecretStore.RecipientMode.keyFile.rawValue)
        XCTAssertNil(upgraded.kdf)
        XCTAssertEqual(try fixture.store.get(), "upgraded-key-file")
        XCTAssertEqual(try Data(contentsOf: fixture.keyFileURL), encodedKey)
    }

    internal func testEncryptedSnapshotDoesNotInvokeKDF() throws {
        setSecretPassphrase("snapshot-passphrase")
        let recorder = KDFCallRecorder()
        let fixture = try makeFixture(recorder: recorder)
        let bytes = Data("opaque-encrypted-snapshot".utf8)
        try bytes.write(to: fixture.envelopeURL, options: .atomic)

        XCTAssertEqual(try fixture.store.encryptedSnapshot(), bytes)
        XCTAssertTrue(recorder.snapshot().isEmpty)
    }

    @MainActor
    internal func testWatchEncryptedStoreDerivesOnlyInitiallyAndAfterEnvelopeChange() async throws {
        setSecretPassphrase("watch-passphrase")
        let recorder = KDFCallRecorder()
        let fixture = try makeFixture(recorder: recorder)
        try fixture.store.set("initial-watch-value")

        let root = try XCTUnwrap(directoryURL)
        let replacementDirectory = root.appendingPathComponent("replacement", isDirectory: true)
        try FileManager.default.createDirectory(at: replacementDirectory, withIntermediateDirectories: true)
        let replacementFixture = try makeFixture(directory: replacementDirectory)
        try replacementFixture.store.set("changed-watch-value")
        let replacementBytes = try Data(contentsOf: replacementFixture.envelopeURL)
        recorder.reset()

        var iteration = 0
        var derivationCountsAtPollStart: [Int] = []
        var mutationError: Error?
        var observedValues: [String] = []
        try StateStore().watchEncryptedStore(
            fixture.store,
            initialValue: "",
            pollInterval: 0,
            pollDeadline: nil,
            shouldContinue: {
                iteration += 1
                if iteration == 3 {
                    do {
                        try replacementBytes.write(to: fixture.envelopeURL, options: .atomic)
                    } catch {
                        mutationError = error
                    }
                }
                derivationCountsAtPollStart.append(recorder.snapshot().count)
                return iteration <= 5
            },
            onChange: { observedValues.append($0) }
        )

        XCTAssertNil(mutationError)
        XCTAssertEqual(observedValues, ["initial-watch-value", "changed-watch-value"])
        XCTAssertEqual(derivationCountsAtPollStart, [1, 1, 1, 2, 2, 2])
        XCTAssertEqual(recorder.snapshot().count, 2)
    }

    @MainActor
    internal func testWatchReusesOneInteractivePassphrasePromptAcrossChanges() async throws {
        let promptRecorder = PassphrasePromptRecorder(passphrase: "interactive-watch")
        setUsePassphrase("1")
        let fixture = try makeFixture(interactivePassphraseOperations: promptRecorder.operations)
        setSecretPassphrase("interactive-watch")
        try fixture.store.set("initial")

        let root = try XCTUnwrap(directoryURL)
        let replacementDirectory = root.appendingPathComponent("interactive-replacement", isDirectory: true)
        try FileManager.default.createDirectory(at: replacementDirectory, withIntermediateDirectories: true)
        let replacementFixture = try makeFixture(directory: replacementDirectory)
        try replacementFixture.store.set("changed")
        let replacement = try Data(contentsOf: replacementFixture.envelopeURL)
        setSecretPassphrase(nil)

        var iteration = 0
        var observed: [String] = []
        try StateStore().watchEncryptedStore(
            fixture.store,
            initialValue: "",
            pollInterval: 0,
            pollDeadline: nil,
            shouldContinue: {
                iteration += 1
                if iteration == 2 {
                    try? replacement.write(to: fixture.envelopeURL, options: .atomic)
                }
                return iteration <= 3
            },
            onChange: { observed.append($0) }
        )

        XCTAssertEqual(observed, ["initial", "changed"])
        XCTAssertEqual(promptRecorder.count, 1)
    }

    @MainActor
    internal func testWatchDoesNotPromptWhileEncryptedStoreIsMissing() async throws {
        let promptRecorder = PassphrasePromptRecorder(passphrase: "unused")
        setUsePassphrase("1")
        let fixture = try makeFixture(interactivePassphraseOperations: promptRecorder.operations)
        var observed: [String] = []

        try StateStore().watchEncryptedStore(
            fixture.store,
            initialValue: "initial",
            pollInterval: 0,
            pollDeadline: nil,
            shouldContinue: { false },
            onChange: { observed.append($0) }
        )

        XCTAssertEqual(observed, ["initial"])
        XCTAssertEqual(promptRecorder.count, 0)
    }

    @MainActor
    internal func testWatchMigratesLegacyPassphraseEnvelopeAfterExactSnapshotUnlock() async throws {
        setSecretPassphrase("legacy-watch")
        let fixture = try makeFixture()
        let legacy = try JSONEncoder().encode(
            makeLegacyEnvelope(value: "legacy-watched", passphrase: "legacy-watch")
        )
        try legacy.write(to: fixture.envelopeURL, options: .atomic)

        var iterations = 0
        var observed: [String] = []
        try StateStore().watchEncryptedStore(
            fixture.store,
            initialValue: "",
            pollInterval: 0,
            pollDeadline: nil,
            shouldContinue: {
                iterations += 1
                return iterations <= 1
            },
            onChange: { observed.append($0) }
        )

        XCTAssertEqual(observed, ["legacy-watched"])
        let migrated = try readEnvelope(from: fixture.envelopeURL)
        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(migrated.recipientMode, SecretStore.RecipientMode.passphrase.rawValue)
        XCTAssertNotEqual(try Data(contentsOf: fixture.envelopeURL), legacy)
    }

    @MainActor
    internal func testWatchDoesNotMigrateWhenLegacyBackingBytesChangedBeforeLock() async throws {
        setSecretPassphrase("legacy-race")
        let first = try JSONEncoder().encode(
            makeLegacyEnvelope(value: "first", passphrase: "legacy-race")
        )
        let changed = try JSONEncoder().encode(
            makeLegacyEnvelope(value: "changed", passphrase: "legacy-race")
        )
        let sequence = EnvelopeReadSequence(values: [first, changed])
        let fixture = try makeFixture(envelopeOperations: sequence.operations)
        var observed: [String] = []

        try StateStore().watchEncryptedStore(
            fixture.store,
            initialValue: "",
            pollInterval: 0,
            pollDeadline: nil,
            shouldContinue: { false },
            onChange: { observed.append($0) }
        )

        XCTAssertEqual(observed, ["first"])
        XCTAssertEqual(sequence.readCount, 2)
        XCTAssertEqual(sequence.writeCount, 0)
    }

    @MainActor
    internal func testWatchDecryptsTheExactComparedEnvelopeSnapshot() async throws {
        setSecretPassphrase("snapshot-owner")
        let firstFixture = try makeFixture()
        try firstFixture.store.set("snapshot-a")
        let firstBytes = try Data(contentsOf: firstFixture.envelopeURL)

        let root = try XCTUnwrap(directoryURL)
        let secondDirectory = root.appendingPathComponent("snapshot-b", isDirectory: true)
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)
        let secondFixture = try makeFixture(directory: secondDirectory)
        try secondFixture.store.set("snapshot-b")
        let secondBytes = try Data(contentsOf: secondFixture.envelopeURL)

        let sequence = EnvelopeReadSequence(values: [firstBytes, secondBytes, firstBytes])
        let watchedFixture = try makeFixture(envelopeOperations: sequence.operations)
        var iterations = 0
        var observedValues: [String] = []

        try StateStore().watchEncryptedStore(
            watchedFixture.store,
            initialValue: "",
            pollInterval: 0,
            pollDeadline: nil,
            shouldContinue: {
                iterations += 1
                return iterations <= 2
            },
            onChange: { observedValues.append($0) }
        )

        XCTAssertEqual(observedValues, ["snapshot-a", "snapshot-b", "snapshot-a"])
        XCTAssertEqual(sequence.readCount, 3)
    }

    internal func testLegacyMigrationFirstReplacementWriteFailurePreservesOriginalBytes() throws {
        setSecretPassphrase("migration-owner")
        let controller = EnvelopeWriteController(behavior: .failBeforeFirstWrite)
        let fixture = try makeFixture(envelopeOperations: controller.operations)
        let original = try JSONEncoder().encode(
            makeLegacyEnvelope(value: "legacy-value", passphrase: "migration-owner")
        )
        try original.write(to: fixture.envelopeURL, options: .atomic)

        XCTAssertThrowsError(try fixture.store.get()) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "secret"))
        }
        XCTAssertEqual(controller.writeCount, 2)
        XCTAssertEqual(try Data(contentsOf: fixture.envelopeURL), original)
    }

    internal func testLegacyMigrationPersistThenThrowRestoresExactOriginalBytes() throws {
        setSecretPassphrase("migration-owner")
        let controller = EnvelopeWriteController(behavior: .persistThenFailFirstWrite)
        let fixture = try makeFixture(envelopeOperations: controller.operations)
        let original = try JSONEncoder().encode(
            makeLegacyEnvelope(value: "legacy-value", passphrase: "migration-owner")
        )
        try original.write(to: fixture.envelopeURL, options: .atomic)

        XCTAssertThrowsError(try fixture.store.get()) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "secret"))
        }
        XCTAssertEqual(controller.writeCount, 2)
        XCTAssertEqual(try Data(contentsOf: fixture.envelopeURL), original)
    }

    internal func testLegacyMigrationLateRestoreErrorUsesVerifiedOriginalBytes() throws {
        setSecretPassphrase("migration-owner")
        let controller = EnvelopeWriteController(behavior: .persistThenFailFirstAndLateRestore)
        let fixture = try makeFixture(envelopeOperations: controller.operations)
        let original = try JSONEncoder().encode(
            makeLegacyEnvelope(value: "legacy-value", passphrase: "migration-owner")
        )
        try original.write(to: fixture.envelopeURL, options: .atomic)

        XCTAssertThrowsError(try fixture.store.get()) { error in
            XCTAssertEqual(error as? APSError, .persistenceFailed(key: "secret"))
        }
        XCTAssertEqual(controller.writeCount, 2)
        XCTAssertEqual(try Data(contentsOf: fixture.envelopeURL), original)
    }

    internal func testLegacyMigrationRestoreFailureReportsSecretEnvelopeRollback() throws {
        setSecretPassphrase("migration-owner")
        let controller = EnvelopeWriteController(behavior: .persistThenFailFirstAndRestore)
        let fixture = try makeFixture(envelopeOperations: controller.operations)
        let original = try JSONEncoder().encode(
            makeLegacyEnvelope(value: "legacy-value", passphrase: "migration-owner")
        )
        try original.write(to: fixture.envelopeURL, options: .atomic)

        XCTAssertThrowsError(try fixture.store.get()) { error in
            guard
                case .rollbackFailed(
                    let context,
                    let originalErrorCode,
                    let originalErrorDescription
                ) = error as? APSError
            else {
                return XCTFail("Expected rollbackFailed, got \(error)")
            }
            XCTAssertEqual(context, .secretEnvelope(path: "secret.enc"))
            XCTAssertEqual(originalErrorCode, "persistence_failed")
            XCTAssertEqual(
                originalErrorDescription,
                APSError.persistenceFailed(key: "secret").description
            )
        }
        XCTAssertEqual(controller.writeCount, 2)
        XCTAssertNotEqual(try Data(contentsOf: fixture.envelopeURL), original)
    }

    private func makeFixture(
        recorder: KDFCallRecorder = KDFCallRecorder(),
        envelopeOperations: SecretStore.EnvelopeOperations = .live,
        passwordKDF explicitPasswordKDF: PasswordKDF? = nil,
        interactivePassphraseOperations: SecretStore.InteractivePassphraseOperations = .live,
        directory explicitDirectory: URL? = nil
    ) throws -> SecretFixture {
        let directory = try explicitDirectory ?? XCTUnwrap(directoryURL)
        let operations = PasswordKDF.Operations { password, salt, parameters in
            recorder.record(password: password, salt: salt, parameters: parameters)
            var material = Data()
            material.append(password)
            material.append(salt)
            return SymmetricKey(data: Data(SHA256.hash(data: material)))
        }
        let passwordKDF = explicitPasswordKDF ?? PasswordKDF(operations: operations)
        let store = SecretStore(
            directory: directory.path,
            deletionOperations: .live,
            passwordKDF: passwordKDF,
            envelopeOperations: envelopeOperations,
            interactivePassphraseOperations: interactivePassphraseOperations
        )
        return SecretFixture(
            store: store,
            envelopeURL: directory.appendingPathComponent("secret.enc"),
            keyFileURL: directory.appendingPathComponent("secret.key")
        )
    }

    private func readEnvelope(from url: URL) throws -> SecretStore.Envelope {
        try JSONDecoder().decode(SecretStore.Envelope.self, from: Data(contentsOf: url))
    }

    private func validEnvelope() -> SecretStore.Envelope {
        SecretStore.Envelope(
            version: 2,
            recipientMode: SecretStore.RecipientMode.passphrase.rawValue,
            kdf: SecretStore.ScryptMetadata(
                algorithm: "scrypt",
                salt: Data(repeating: 0x30, count: 16).base64EncodedString(),
                rounds: PasswordKDF.profile.rounds,
                blockSize: PasswordKDF.profile.blockSize,
                parallelism: PasswordKDF.profile.parallelism,
                outputByteCount: PasswordKDF.profile.outputByteCount
            ),
            ephemeralPublicKey: Data(repeating: 0x41, count: 32).base64EncodedString(),
            nonce: Data(repeating: 0x42, count: 12).base64EncodedString(),
            ciphertext: Data("ciphertext".utf8).base64EncodedString(),
            tag: Data(repeating: 0x43, count: 16).base64EncodedString()
        )
    }

    private func replacingMetadata(
        in envelope: SecretStore.Envelope,
        with metadata: SecretStore.ScryptMetadata
    ) -> SecretStore.Envelope {
        SecretStore.Envelope(
            version: envelope.version,
            recipientMode: envelope.recipientMode,
            kdf: metadata,
            ephemeralPublicKey: envelope.ephemeralPublicKey,
            nonce: envelope.nonce,
            ciphertext: envelope.ciphertext,
            tag: envelope.tag
        )
    }

    private func replacingPayload(
        in envelope: SecretStore.Envelope,
        ephemeralPublicKey: String? = nil,
        nonce: String? = nil,
        ciphertext: String? = nil,
        tag: String? = nil
    ) -> SecretStore.Envelope {
        SecretStore.Envelope(
            version: envelope.version,
            recipientMode: envelope.recipientMode,
            kdf: envelope.kdf,
            ephemeralPublicKey: ephemeralPublicKey ?? envelope.ephemeralPublicKey,
            nonce: nonce ?? envelope.nonce,
            ciphertext: ciphertext ?? envelope.ciphertext,
            tag: tag ?? envelope.tag
        )
    }

    private func makeLegacyEnvelope(
        value: String,
        passphrase: String
    ) throws -> SecretStore.Envelope {
        let recipientMaterial = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(passphrase.utf8)),
            salt: Data("aps-secret-store-v1".utf8),
            info: Data("x25519-key".utf8),
            outputByteCount: 32
        )
        let recipient = try Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: recipientMaterial.withUnsafeBytes { Data($0) }
        )
        return try makeLegacyEnvelope(value: value, recipient: recipient)
    }

    private func makeLegacyEnvelope(
        value: String,
        recipient: Curve25519.KeyAgreement.PrivateKey
    ) throws -> SecretStore.Envelope {
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let sharedSecret = try ephemeral.sharedSecretFromKeyAgreement(with: recipient.publicKey)
        let symmetric = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("aps-secret-store-v1".utf8),
            sharedInfo: Data("envelope".utf8),
            outputByteCount: 32
        )
        let nonce = ChaChaPoly.Nonce()
        let sealed = try ChaChaPoly.seal(Data(value.utf8), using: symmetric, nonce: nonce)
        return SecretStore.Envelope(
            version: nil,
            recipientMode: nil,
            kdf: nil,
            ephemeralPublicKey: ephemeral.publicKey.rawRepresentation.base64EncodedString(),
            nonce: nonce.withUnsafeBytes { Data($0) }.base64EncodedString(),
            ciphertext: sealed.ciphertext.base64EncodedString(),
            tag: sealed.tag.base64EncodedString()
        )
    }
}

private struct SecretFixture {
    fileprivate let store: SecretStore
    fileprivate let envelopeURL: URL
    fileprivate let keyFileURL: URL
}

private struct KDFCall: Sendable {
    fileprivate let password: Data
    fileprivate let salt: Data
    fileprivate let parameters: PasswordKDF.Parameters
}

private final class KDFCallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [KDFCall] = []

    fileprivate func record(
        password: Data,
        salt: Data,
        parameters: PasswordKDF.Parameters
    ) {
        lock.lock()
        defer { lock.unlock() }
        calls.append(KDFCall(password: password, salt: salt, parameters: parameters))
    }

    fileprivate func snapshot() -> [KDFCall] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    fileprivate func reset() {
        lock.lock()
        defer { lock.unlock() }
        calls.removeAll()
    }
}

private enum EnvelopeWriteBehavior: Sendable {
    case failBeforeFirstWrite
    case persistThenFailFirstWrite
    case persistThenFailFirstAndRestore
    case persistThenFailFirstAndLateRestore
}

private struct EnvelopeWriteFailure: Error, Sendable {}

private final class EnvelopeWriteController: @unchecked Sendable {
    private let behavior: EnvelopeWriteBehavior
    private let lock = NSLock()
    private var writes = 0

    fileprivate init(behavior: EnvelopeWriteBehavior) {
        self.behavior = behavior
    }

    fileprivate var operations: SecretStore.EnvelopeOperations {
        SecretStore.EnvelopeOperations(
            read: { try Data(contentsOf: $0) },
            write: { [self] data, url in
                try write(data, to: url)
            }
        )
    }

    fileprivate var writeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return writes
    }

    private func write(_ data: Data, to url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        writes += 1
        switch (behavior, writes) {
        case (.failBeforeFirstWrite, 1):
            throw EnvelopeWriteFailure()
        case (.persistThenFailFirstWrite, 1), (.persistThenFailFirstAndRestore, 1):
            try data.write(to: url, options: .atomic)
            throw EnvelopeWriteFailure()
        case (.persistThenFailFirstAndRestore, 2):
            throw EnvelopeWriteFailure()
        case (.persistThenFailFirstAndLateRestore, 1),
             (.persistThenFailFirstAndLateRestore, 2):
            try data.write(to: url, options: .atomic)
            throw EnvelopeWriteFailure()
        default:
            try data.write(to: url, options: .atomic)
        }
    }
}

private struct PasswordKDFFailure: Error, Sendable {}

private final class PassphrasePromptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let passphrase: String
    private var prompts = 0

    fileprivate init(passphrase: String) {
        self.passphrase = passphrase
    }

    fileprivate var operations: SecretStore.InteractivePassphraseOperations {
        SecretStore.InteractivePassphraseOperations(
            isTerminal: { true },
            prompt: { [self] in
                lock.lock()
                defer { lock.unlock() }
                prompts += 1
                return passphrase
            }
        )
    }

    fileprivate var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return prompts
    }
}

private final class EnvelopeReadSequence: @unchecked Sendable {
    private let lock = NSLock()
    private let values: [Data]
    private var reads = 0
    private var writes = 0

    fileprivate init(values: [Data]) {
        self.values = values
    }

    fileprivate var operations: SecretStore.EnvelopeOperations {
        SecretStore.EnvelopeOperations(
            read: { [self] _ in try next() },
            write: { [self] data, url in try write(data, to: url) }
        )
    }

    fileprivate var readCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return reads
    }

    fileprivate var writeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return writes
    }

    private func next() throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard !values.isEmpty else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let index = min(reads, values.count - 1)
        reads += 1
        return values[index]
    }

    private func write(_ data: Data, to url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        writes += 1
        try data.write(to: url, options: .atomic)
    }
}

private func setSecretPassphrase(_ value: String?) {
    setProcessEnvironment("APS_SECRET_PASSPHRASE", value)
}

private func setUsePassphrase(_ value: String?) {
    setProcessEnvironment("APS_SECRET_USE_PASSPHRASE", value)
}

private func setProcessEnvironment(_ key: String, _ value: String?) {
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
