import AppState
import Crypto
import Foundation

/// Encrypted-file secret store (issue #35): replaces the Keychain-backed
/// `secret` with an age-style envelope under the state root. Ephemeral
/// X25519 ECDH + HKDF + ChaCha20-Poly1305 (AlgoChat construction, directly
/// on swift-crypto). Prompt-free for humans and agents; tri-OS.
///
/// Unlock model (interview decision):
/// - `APS_SECRET_PASSPHRASE` set: the recipient key is derived from the
///   passphrase via the envelope's bounded scrypt profile (no key file involved).
/// - `APS_SECRET_USE_PASSPHRASE=1` on a TTY: one interactive prompt (our
///   getpass prompt, not macOS Keychain's), same derivation.
/// - Otherwise a key file at `<state-root>/secret.key` (base64 raw X25519
///   private key, owner-only POSIX mode or Windows DACL) is created on first use.
public struct SecretStore: Sendable {

    /// Instance-scoped encrypted-envelope I/O for deterministic rollback tests.
    internal struct EnvelopeOperations: Sendable {
        internal let read: @Sendable (URL) throws -> Data
        internal let write: @Sendable (Data, URL) throws -> Void

        internal init(
            read: @escaping @Sendable (URL) throws -> Data,
            write: @escaping @Sendable (Data, URL) throws -> Void
        ) {
            self.read = read
            self.write = write
        }

        internal static let live = EnvelopeOperations(
            read: { try Data(contentsOf: $0) },
            write: { try $0.write(to: $1, options: .atomic) }
        )
    }

    /// Instance-scoped interactive passphrase operations for deterministic
    /// one-prompt watch tests.
    internal struct InteractivePassphraseOperations: Sendable {
        internal let isTerminal: @Sendable () -> Bool
        internal let prompt: @Sendable () -> String?

        internal init(
            isTerminal: @escaping @Sendable () -> Bool,
            prompt: @escaping @Sendable () -> String?
        ) {
            self.isTerminal = isTerminal
            self.prompt = prompt
        }

        internal static let live = InteractivePassphraseOperations(
            isTerminal: {
                #if os(Windows)
                false
                #else
                isatty(FileHandle.standardError.fileDescriptor) == 1
                #endif
            },
            prompt: {
                #if os(Windows)
                nil
                #else
                SecretStore.promptPassphrase()
                #endif
            }
        )
    }

    /// Recipient modes persisted by the version 2 envelope.
    internal enum RecipientMode: String, Codable, Sendable {
        case keyFile
        case passphrase
    }

    /// Exact scrypt profile persisted for auditability and strict read bounds.
    internal struct ScryptMetadata: Codable, Equatable, Sendable {
        internal let algorithm: String
        internal let salt: String
        internal let rounds: Int
        internal let blockSize: Int
        internal let parallelism: Int
        internal let outputByteCount: Int
    }

    /// On-disk envelope. Missing version/mode/KDF fields identify legacy v1 data.
    internal struct Envelope: Codable, Equatable, Sendable {
        internal let version: Int?
        internal let recipientMode: String?
        internal let kdf: ScryptMetadata?
        internal let ephemeralPublicKey: String
        internal let nonce: String
        internal let ciphertext: String
        internal let tag: String
    }

    fileprivate struct RecipientOperation: Sendable {
        private(set) var mode: RecipientMode
        fileprivate let lockKeyFile: Bool
        private let passphrase: Data?
        private var legacyPassphraseKey: Curve25519.KeyAgreement.PrivateKey?
        private var scryptSalt: Data?
        private var scryptKey: Curve25519.KeyAgreement.PrivateKey?
        private var keyFileKey: Curve25519.KeyAgreement.PrivateKey?

        fileprivate init(
            mode: RecipientMode,
            lockKeyFile: Bool,
            passphrase: Data? = nil
        ) {
            self.mode = mode
            self.lockKeyFile = lockKeyFile
            self.passphrase = passphrase
        }

        fileprivate mutating func cachedLegacyPassphraseKey(
            derive: (Data) throws -> Curve25519.KeyAgreement.PrivateKey
        ) throws -> Curve25519.KeyAgreement.PrivateKey {
            if let legacyPassphraseKey {
                return legacyPassphraseKey
            }
            guard let passphrase else {
                throw APSError.secretUnlockFailed
            }
            let key = try derive(passphrase)
            legacyPassphraseKey = key
            return key
        }

        fileprivate mutating func cachedScryptKey(
            salt: Data,
            derive: (Data, Data) throws -> Curve25519.KeyAgreement.PrivateKey
        ) throws -> Curve25519.KeyAgreement.PrivateKey {
            if scryptSalt == salt, let scryptKey {
                return scryptKey
            }
            guard let passphrase else {
                throw APSError.secretUnlockFailed
            }
            let key = try derive(passphrase, salt)
            scryptSalt = salt
            scryptKey = key
            return key
        }

        fileprivate mutating func cachedKeyFileKey(
            load: () throws -> Curve25519.KeyAgreement.PrivateKey
        ) throws -> Curve25519.KeyAgreement.PrivateKey {
            if let keyFileKey {
                return keyFileKey
            }
            let key = try load()
            keyFileKey = key
            return key
        }
    }

    /// Recipient state retained for the lifetime of one encrypted watch.
    internal struct EncryptedWatchSession: Sendable {
        fileprivate var operation: RecipientOperation
    }

    /// Decrypted value plus the exact snapshot that produced it.
    internal struct EncryptedWatchValue: Sendable {
        internal let value: String
        internal let snapshot: Data
    }

    private struct DuplicateKeyJSONValidator {
        private static let maximumNestingDepth = 32

        private let bytes: [UInt8]
        private var index: Int = 0

        fileprivate init(data: Data) {
            self.bytes = Array(data)
        }

        fileprivate mutating func validate() throws {
            skipWhitespace()
            try parseValue(depth: 0)
            skipWhitespace()
            guard index == bytes.count else {
                throw APSError.decodingFailed
            }
        }

        private mutating func parseValue(depth: Int) throws {
            guard index < bytes.count else {
                throw APSError.decodingFailed
            }
            switch bytes[index] {
            case 0x7B:
                guard depth < Self.maximumNestingDepth else {
                    throw APSError.decodingFailed
                }
                try parseObject(depth: depth)
            case 0x5B:
                guard depth < Self.maximumNestingDepth else {
                    throw APSError.decodingFailed
                }
                try parseArray(depth: depth)
            case 0x22:
                _ = try parseString()
            default:
                try parsePrimitive()
            }
        }

        private mutating func parseObject(depth: Int) throws {
            index += 1
            skipWhitespace()
            if consume(0x7D) {
                return
            }
            var keys: Set<String> = []
            while true {
                let key = try parseString()
                guard keys.insert(key).inserted else {
                    throw APSError.decodingFailed
                }
                skipWhitespace()
                guard consume(0x3A) else {
                    throw APSError.decodingFailed
                }
                skipWhitespace()
                try parseValue(depth: depth + 1)
                skipWhitespace()
                if consume(0x7D) {
                    return
                }
                guard consume(0x2C) else {
                    throw APSError.decodingFailed
                }
                skipWhitespace()
            }
        }

        private mutating func parseArray(depth: Int) throws {
            index += 1
            skipWhitespace()
            if consume(0x5D) {
                return
            }
            while true {
                try parseValue(depth: depth + 1)
                skipWhitespace()
                if consume(0x5D) {
                    return
                }
                guard consume(0x2C) else {
                    throw APSError.decodingFailed
                }
                skipWhitespace()
            }
        }

        private mutating func parseString() throws -> String {
            guard index < bytes.count, bytes[index] == 0x22 else {
                throw APSError.decodingFailed
            }
            let start = index
            index += 1
            while index < bytes.count {
                switch bytes[index] {
                case 0x22:
                    index += 1
                    let token = Data(bytes[start..<index])
                    do {
                        return try JSONDecoder().decode(String.self, from: token)
                    } catch {
                        throw APSError.decodingFailed
                    }
                case 0x5C:
                    index += 1
                    guard index < bytes.count else {
                        throw APSError.decodingFailed
                    }
                    if bytes[index] == 0x75 {
                        guard index + 4 < bytes.count else {
                            throw APSError.decodingFailed
                        }
                        index += 5
                    } else {
                        index += 1
                    }
                default:
                    index += 1
                }
            }
            throw APSError.decodingFailed
        }

        private mutating func parsePrimitive() throws {
            let start = index
            while index < bytes.count {
                switch bytes[index] {
                case 0x20, 0x09, 0x0A, 0x0D, 0x2C, 0x5D, 0x7D:
                    guard index > start else {
                        throw APSError.decodingFailed
                    }
                    return
                default:
                    index += 1
                }
            }
            guard index > start else {
                throw APSError.decodingFailed
            }
        }

        private mutating func skipWhitespace() {
            while index < bytes.count {
                switch bytes[index] {
                case 0x20, 0x09, 0x0A, 0x0D:
                    index += 1
                default:
                    return
                }
            }
        }

        private mutating func consume(_ byte: UInt8) -> Bool {
            guard index < bytes.count, bytes[index] == byte else {
                return false
            }
            index += 1
            return true
        }
    }

    private let directory: String
    private let storeFileName: String
    private let keyName: String
    private let deletionOperations: SchemaStoragePath.DeletionOperations
    private let passwordKDF: PasswordKDF
    private let envelopeOperations: EnvelopeOperations
    private let interactivePassphraseOperations: InteractivePassphraseOperations

    /// Store rooted at the configured FileState path (`secret.enc`).
    @MainActor
    public init() {
        self.directory = FileManager.defaultFileStatePath
        self.storeFileName = "secret.enc"
        self.keyName = "secret"
        self.deletionOperations = .live
        self.passwordKDF = PasswordKDF()
        self.envelopeOperations = .live
        self.interactivePassphraseOperations = .live
    }

    /// Store rooted at an explicit directory (tests, tooling).
    public init(directory: String, storeFileName: String = "secret.enc", keyName: String = "secret") {
        self.directory = directory
        self.storeFileName = storeFileName
        self.keyName = keyName
        self.deletionOperations = .live
        self.passwordKDF = PasswordKDF()
        self.envelopeOperations = .live
        self.interactivePassphraseOperations = .live
    }

    /// Store with instance-scoped deletion operations for deterministic tests.
    internal init(
        directory: String,
        storeFileName: String = "secret.enc",
        keyName: String = "secret",
        deletionOperations: SchemaStoragePath.DeletionOperations,
        passwordKDF: PasswordKDF = PasswordKDF(),
        envelopeOperations: EnvelopeOperations = .live,
        interactivePassphraseOperations: InteractivePassphraseOperations = .live
    ) {
        self.directory = directory
        self.storeFileName = storeFileName
        self.keyName = keyName
        self.deletionOperations = deletionOperations
        self.passwordKDF = passwordKDF
        self.envelopeOperations = envelopeOperations
        self.interactivePassphraseOperations = interactivePassphraseOperations
    }

    private var storeURL: URL {
        URL(fileURLWithPath: directory).appendingPathComponent(storeFileName)
    }

    private var keyFileURL: URL {
        URL(fileURLWithPath: directory).appendingPathComponent("secret.key")
    }

    // MARK: - Public API

    /// True when a secret is stored (missing file means the initial value).
    public var hasSecret: Bool {
        FileManager.default.fileExists(atPath: storeURL.path)
    }

    /// Decrypt and return the stored secret.
    /// Missing file throws `APSError.persistenceFailed`; an existing file that
    /// does not parse throws `APSError.decodingFailed`; a valid envelope that
    /// does not open throws `APSError.secretUnlockFailed` (wrong key).
    public func get() throws -> String {
        _ = try validatedStoragePath()
        var operation = try makeRecipientOperation(lockKeyFile: true)
        let data = try readStoreData()
        let envelope = try decodeEnvelope(data)
        if try envelopeKind(envelope) == .legacy, operation.mode == .passphrase {
            return try SchemaFileLock.withExclusiveStorageLock(
                stateRoot: directory,
                lockFileName: "secret.store.lock",
                resourceKey: keyName
            ) {
                let currentData = try readStoreData()
                let currentEnvelope = try decodeEnvelope(currentData)
                if try envelopeKind(currentEnvelope) != .legacy {
                    return try open(currentEnvelope, operation: &operation)
                }
                let value = try open(currentEnvelope, operation: &operation)
                let migrated = try seal(value, operation: &operation)
                _ = try writeAndVerify(
                    migrated,
                    expectedValue: value,
                    rollbackData: currentData,
                    operation: &operation
                )
                return value
            }
        }
        return try open(envelope, operation: &operation)
    }

    /// Captures one recipient operation for an encrypted watch command.
    internal func makeEncryptedWatchSession() throws -> EncryptedWatchSession {
        EncryptedWatchSession(operation: try makeRecipientOperation(lockKeyFile: true))
    }

    /// Decrypts an exact encrypted snapshot, retaining recipient state across
    /// changes and transactionally migrating an observed legacy passphrase
    /// envelope only when the backing bytes still match that snapshot.
    internal func value(
        forEncryptedSnapshot data: Data,
        session: inout EncryptedWatchSession
    ) throws -> EncryptedWatchValue {
        _ = try validatedStoragePath()
        let envelope = try decodeEnvelope(data)
        guard
            try envelopeKind(envelope) == .legacy,
            session.operation.mode == .passphrase
        else {
            return EncryptedWatchValue(
                value: try open(envelope, operation: &session.operation),
                snapshot: data
            )
        }
        return try SchemaFileLock.withExclusiveStorageLock(
            stateRoot: directory,
            lockFileName: "secret.store.lock",
            resourceKey: keyName
        ) {
            let value = try open(envelope, operation: &session.operation)
            let currentData = try readStoreData()
            guard currentData == data else {
                return EncryptedWatchValue(value: value, snapshot: data)
            }
            let migrated = try seal(value, operation: &session.operation)
            let migratedData = try writeAndVerify(
                migrated,
                expectedValue: value,
                rollbackData: data,
                operation: &session.operation
            )
            return EncryptedWatchValue(value: value, snapshot: migratedData)
        }
    }

    /// Encrypt and store the value, then verify by decrypting the file back.
    ///
    /// When an envelope already exists, unlock it with the current recipient key
    /// before rewriting. A wrong passphrase or key fails with
    /// `secretUnlockFailed` and leaves ciphertext unchanged (issue #89).
    public func set(_ value: String) throws {
        _ = try validatedStoragePath()
        var operation = try makeRecipientOperation(lockKeyFile: false)
        try SchemaFileLock.withExclusiveStorageLock(
            stateRoot: directory,
            lockFileName: "secret.store.lock",
            resourceKey: keyName
        ) {
            try setUnlocked(value, operation: &operation)
        }
    }

    private func setUnlocked(
        _ value: String,
        operation: inout RecipientOperation
    ) throws {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var rollbackData: Data?
        if hasSecret {
            let existingData = try readStoreData()
            rollbackData = existingData
            let existing = try decodeEnvelope(existingData)
            _ = try open(existing, operation: &operation)
        }
        let envelope = try seal(value, operation: &operation)
        _ = try writeAndVerify(
            envelope,
            expectedValue: value,
            rollbackData: rollbackData,
            operation: &operation
        )
    }

    /// Reset to the initial value by removing only the encrypted envelope.
    ///
    /// The shared recipient key remains unchanged. Reset is serialized with
    /// `set` and returns whether an envelope was removed.
    /// - Returns: `true` when the envelope was removed, or `false` when it was
    ///   already missing.
    @discardableResult
    public func reset() throws -> Bool {
        let storagePath = try validatedStoragePath()
        do {
            return try SchemaFileLock.withExclusiveStorageLock(
                stateRoot: directory,
                lockFileName: "secret.store.lock",
                resourceKey: keyName
            ) {
                try storagePath.removeRegularFileIfPresent(
                    stateRoot: directory,
                    operations: deletionOperations
                )
            }
        } catch APSError.persistenceFailed {
            throw APSError.persistenceFailed(key: keyName)
        }
    }

    private func validatedStoragePath() throws -> SchemaStoragePath {
        try SchemaStoragePath(storeFileName)
    }

    // MARK: - Envelope cryptography

    private enum EnvelopeKind: Equatable {
        case legacy
        case version2(mode: RecipientMode, salt: Data?)
    }

    private struct ValidatedPayload {
        fileprivate let ephemeralPublic: Curve25519.KeyAgreement.PublicKey
        fileprivate let box: ChaChaPoly.SealedBox
    }

    private func seal(
        _ value: String,
        operation: inout RecipientOperation
    ) throws -> Envelope {
        let metadata: ScryptMetadata?
        let recipientKey: Curve25519.KeyAgreement.PrivateKey
        switch operation.mode {
        case .keyFile:
            metadata = nil
            recipientKey = try keyFileRecipientKey(operation: &operation)
        case .passphrase:
            let salt = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
            metadata = ScryptMetadata(
                algorithm: "scrypt",
                salt: salt.base64EncodedString(),
                rounds: PasswordKDF.profile.rounds,
                blockSize: PasswordKDF.profile.blockSize,
                parallelism: PasswordKDF.profile.parallelism,
                outputByteCount: PasswordKDF.profile.outputByteCount
            )
            recipientKey = try scryptRecipientKey(
                salt: salt,
                operation: &operation,
                failure: .persistenceFailed(key: keyName)
            )
        }
        let recipientPublic = recipientKey.publicKey
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let symmetric = try deriveSymmetricKey(
            privateKey: ephemeral,
            publicKey: recipientPublic,
            failure: .persistenceFailed(key: keyName)
        )
        let nonce = ChaChaPoly.Nonce()
        let sealedBox = try ChaChaPoly.seal(
            Data(value.utf8),
            using: symmetric,
            nonce: nonce
        )
        return Envelope(
            version: 2,
            recipientMode: operation.mode.rawValue,
            kdf: metadata,
            ephemeralPublicKey: ephemeral.publicKey.rawRepresentation.base64EncodedString(),
            nonce: nonce.withUnsafeBytes { Data($0) }.base64EncodedString(),
            ciphertext: sealedBox.ciphertext.base64EncodedString(),
            tag: sealedBox.tag.base64EncodedString()
        )
    }

    private func open(
        _ envelope: Envelope,
        operation: inout RecipientOperation
    ) throws -> String {
        let kind = try envelopeKind(envelope)
        let payload = try validatedPayload(envelope)
        let privateKey: Curve25519.KeyAgreement.PrivateKey
        switch kind {
        case .legacy:
            switch operation.mode {
            case .keyFile:
                privateKey = try keyFileRecipientKey(operation: &operation)
            case .passphrase:
                privateKey = try legacyPassphraseRecipientKey(operation: &operation)
            }
        case .version2(let mode, let salt):
            guard mode == operation.mode else {
                throw APSError.secretUnlockFailed
            }
            switch mode {
            case .keyFile:
                privateKey = try keyFileRecipientKey(operation: &operation)
            case .passphrase:
                guard let salt else {
                    throw APSError.decodingFailed
                }
                privateKey = try scryptRecipientKey(
                    salt: salt,
                    operation: &operation,
                    failure: .secretUnlockFailed
                )
            }
        }

        let symmetric = try deriveSymmetricKey(
            privateKey: privateKey,
            publicKey: payload.ephemeralPublic,
            failure: .decodingFailed
        )
        let plaintext: Data
        do {
            plaintext = try ChaChaPoly.open(payload.box, using: symmetric)
        } catch {
            throw APSError.secretUnlockFailed
        }
        guard let value = String(data: plaintext, encoding: .utf8) else {
            throw APSError.decodingFailed
        }
        return value
    }

    private func validatedPayload(_ envelope: Envelope) throws -> ValidatedPayload {
        guard
            let ephemeralPublicData = strictBase64(envelope.ephemeralPublicKey, expectedByteCount: 32),
            let nonceData = strictBase64(envelope.nonce, expectedByteCount: 12),
            let ciphertext = strictBase64(envelope.ciphertext),
            let tag = strictBase64(envelope.tag, expectedByteCount: 16),
            let ephemeralPublic = try? Curve25519.KeyAgreement.PublicKey(
                rawRepresentation: ephemeralPublicData
            ),
            let nonce = try? ChaChaPoly.Nonce(data: nonceData),
            let box = try? ChaChaPoly.SealedBox(
                nonce: nonce,
                ciphertext: ciphertext,
                tag: tag
            )
        else {
            throw APSError.decodingFailed
        }
        return ValidatedPayload(ephemeralPublic: ephemeralPublic, box: box)
    }

    private func decodeEnvelope(_ data: Data) throws -> Envelope {
        let envelope: Envelope
        let object: [String: Any]
        do {
            var duplicateValidator = DuplicateKeyJSONValidator(data: data)
            try duplicateValidator.validate()
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw APSError.decodingFailed
            }
            object = dictionary
        } catch {
            if let error = error as? APSError {
                throw error
            }
            throw APSError.decodingFailed
        }
        let kind = try envelopeKind(envelope)
        let cryptographicKeys: Set<String> = [
            "ephemeralPublicKey", "nonce", "ciphertext", "tag",
        ]
        let expectedKeys: Set<String>
        switch kind {
        case .legacy:
            expectedKeys = cryptographicKeys
        case .version2(let mode, _):
            expectedKeys = mode == .passphrase
                ? cryptographicKeys.union(["version", "recipientMode", "kdf"])
                : cryptographicKeys.union(["version", "recipientMode"])
        }
        guard Set(object.keys) == expectedKeys else {
            throw APSError.decodingFailed
        }
        if case .version2(mode: .passphrase, salt: _) = kind {
            guard
                let kdf = object["kdf"] as? [String: Any],
                Set(kdf.keys) == [
                    "algorithm", "salt", "rounds", "blockSize", "parallelism", "outputByteCount",
                ]
            else {
                throw APSError.decodingFailed
            }
        }
        return envelope
    }

    private func envelopeKind(_ envelope: Envelope) throws -> EnvelopeKind {
        guard let version = envelope.version else {
            guard envelope.recipientMode == nil, envelope.kdf == nil else {
                throw APSError.decodingFailed
            }
            return .legacy
        }
        guard version == 2 else {
            throw APSError.unsupportedSecretEnvelope
        }
        guard
            let rawMode = envelope.recipientMode,
            let mode = RecipientMode(rawValue: rawMode)
        else {
            throw APSError.unsupportedSecretEnvelope
        }
        switch mode {
        case .keyFile:
            guard envelope.kdf == nil else {
                throw APSError.decodingFailed
            }
            return .version2(mode: mode, salt: nil)
        case .passphrase:
            guard
                let metadata = envelope.kdf,
                metadata.algorithm == "scrypt",
                metadata.rounds == PasswordKDF.profile.rounds,
                metadata.blockSize == PasswordKDF.profile.blockSize,
                metadata.parallelism == PasswordKDF.profile.parallelism,
                metadata.outputByteCount == PasswordKDF.profile.outputByteCount,
                let salt = strictBase64(
                    metadata.salt,
                    expectedByteCount: PasswordKDF.profile.saltByteCount
                )
            else {
                throw APSError.decodingFailed
            }
            return .version2(mode: mode, salt: salt)
        }
    }

    private func strictBase64(
        _ encoded: String,
        expectedByteCount: Int? = nil
    ) -> Data? {
        guard
            let data = Data(base64Encoded: encoded),
            data.base64EncodedString() == encoded
        else {
            return nil
        }
        if let expectedByteCount, data.count != expectedByteCount {
            return nil
        }
        return data
    }

    private func readStoreData() throws -> Data {
        do {
            return try envelopeOperations.read(storeURL)
        } catch {
            throw APSError.persistenceFailed(key: keyName)
        }
    }

    /// Returns the encrypted bytes without invoking recipient-key derivation.
    ///
    /// Watch polling uses this snapshot to avoid repeating an expensive password
    /// KDF while the envelope has not changed.
    internal func encryptedSnapshot() throws -> Data? {
        _ = try validatedStoragePath()
        do {
            return try envelopeOperations.read(storeURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        } catch let error as POSIXError where error.code == .ENOENT {
            return nil
        } catch {
            throw APSError.persistenceFailed(key: keyName)
        }
    }

    private func writeAndVerify(
        _ envelope: Envelope,
        expectedValue: String,
        rollbackData: Data?,
        operation: inout RecipientOperation
    ) throws -> Data {
        let replacement: Data
        do {
            replacement = try JSONEncoder().encode(envelope)
            try envelopeOperations.write(replacement, storeURL)
            guard try readStoreData() == replacement else {
                throw APSError.persistenceFailed(key: keyName)
            }
            let persisted = try decodeEnvelope(replacement)
            guard try open(persisted, operation: &operation) == expectedValue else {
                throw APSError.persistenceFailed(key: keyName)
            }
            return replacement
        } catch {
            let originalError = (error as? APSError) ?? APSError.persistenceFailed(key: keyName)
            do {
                try restoreEnvelope(rollbackData)
            } catch {
                throw APSError.rollbackFailed(
                    context: .secretEnvelope(path: storeFileName),
                    originalErrorCode: originalError.code,
                    originalErrorDescription: originalError.description
                )
            }
            throw originalError
        }
    }

    private func restoreEnvelope(_ rollbackData: Data?) throws {
        if let rollbackData {
            do {
                try envelopeOperations.write(rollbackData, storeURL)
            } catch {
                // A writer can report a late flush or close error after the
                // bytes reached storage. Verification, not the write result,
                // determines whether rollback succeeded.
            }
            guard (try? readStoreData()) == rollbackData else {
                throw APSError.persistenceFailed(key: keyName)
            }
            return
        }
        let storagePath = try validatedStoragePath()
        _ = try storagePath.removeRegularFileIfPresent(
            stateRoot: directory,
            operations: deletionOperations
        )
        guard !hasSecret else {
            throw APSError.persistenceFailed(key: keyName)
        }
    }

    private func deriveSymmetricKey(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        publicKey: Curve25519.KeyAgreement.PublicKey,
        failure: APSError
    ) throws -> SymmetricKey {
        let sharedSecret: SharedSecret
        do {
            sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        } catch {
            throw failure
        }
        let isAllZero = sharedSecret.withUnsafeBytes { bytes in
            bytes.reduce(UInt8(0)) { partialResult, byte in
                partialResult | byte
            } == 0
        }
        guard !isAllZero else {
            throw failure
        }
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("aps-secret-store-v1".utf8),
            sharedInfo: Data("envelope".utf8),
            outputByteCount: 32
        )
    }

    // MARK: - Recipient key

    private func makeRecipientOperation(
        lockKeyFile: Bool
    ) throws -> RecipientOperation {
        if let passphrase = ProcessInfo.processInfo.environment["APS_SECRET_PASSPHRASE"] {
            guard !passphrase.isEmpty else {
                throw APSError.secretUnlockFailed
            }
            return RecipientOperation(
                mode: .passphrase,
                lockKeyFile: lockKeyFile,
                passphrase: Data(passphrase.utf8)
            )
        }
        if ProcessInfo.processInfo.environment["APS_SECRET_USE_PASSPHRASE"] == "1",
           interactivePassphraseOperations.isTerminal() {
            if let passphrase = interactivePassphraseOperations.prompt() {
                return RecipientOperation(
                    mode: .passphrase,
                    lockKeyFile: lockKeyFile,
                    passphrase: Data(passphrase.utf8)
                )
            }
        }
        return RecipientOperation(mode: .keyFile, lockKeyFile: lockKeyFile)
    }

    private func legacyPassphraseRecipientKey(
        operation: inout RecipientOperation
    ) throws -> Curve25519.KeyAgreement.PrivateKey {
        try operation.cachedLegacyPassphraseKey { passphrase in
            let derived = HKDF<SHA256>.deriveKey(
                inputKeyMaterial: SymmetricKey(data: passphrase),
                salt: Data("aps-secret-store-v1".utf8),
                info: Data("x25519-key".utf8),
                outputByteCount: 32
            )
            return try Curve25519.KeyAgreement.PrivateKey(
                rawRepresentation: derived.withUnsafeBytes { Data($0) }
            )
        }
    }

    private func scryptRecipientKey(
        salt: Data,
        operation: inout RecipientOperation,
        failure: APSError
    ) throws -> Curve25519.KeyAgreement.PrivateKey {
        do {
            return try operation.cachedScryptKey(salt: salt) { passphrase, salt in
                let derived = try passwordKDF.deriveKey(from: passphrase, salt: salt)
                return try Curve25519.KeyAgreement.PrivateKey(
                    rawRepresentation: derived.withUnsafeBytes { Data($0) }
                )
            }
        } catch {
            throw failure
        }
    }

    private func keyFileRecipientKey(
        operation: inout RecipientOperation
    ) throws -> Curve25519.KeyAgreement.PrivateKey {
        let lockKeyFile = operation.lockKeyFile
        return try operation.cachedKeyFileKey {
            if lockKeyFile {
                return try loadOrCreateKeyFile()
            }
            return try loadOrCreateKeyFileUnlocked()
        }
    }

    private static func promptPassphrase() -> String? {
        #if os(Windows)
        return nil
        #else
        FileHandle.standardError.write(Data("aps secret passphrase: ".utf8))
        guard let raw = getpass("") else { return nil }
        let passphrase = String(cString: raw)
        return passphrase.isEmpty ? nil : passphrase
        #endif
    }

    private func loadOrCreateKeyFile() throws -> Curve25519.KeyAgreement.PrivateKey {
        return try SchemaFileLock.withExclusiveStorageLock(
            stateRoot: directory,
            lockFileName: "secret.key.lock",
            resourceKey: keyName
        ) {
            try loadOrCreateKeyFileUnlocked()
        }
    }

    private func loadOrCreateKeyFileUnlocked() throws -> Curve25519.KeyAgreement.PrivateKey {
        if let key = try loadKeyFileIfValid(invalidError: invalidKeyMaterialError()) {
            return key
        }

        if hasSecret {
            throw APSError.secretUnlockFailed
        }
        return try createKeyFile()
    }

    private func createKeyFile() throws -> Curve25519.KeyAgreement.PrivateKey {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let encoded = key.rawRepresentation.base64EncodedData()
        do {
            try secureKeyFile.create(encoded)
            guard try secureKeyFile.load() == encoded else {
                throw APSError.persistenceFailed(key: keyName)
            }
        } catch SecureKeyFileError.alreadyExists {
            if let racedKey = try loadKeyFileIfValid(
                invalidError: .persistenceFailed(key: keyName)
            ) {
                return racedKey
            }
            throw APSError.persistenceFailed(key: keyName)
        } catch {
            if let error = error as? APSError {
                throw error
            }
            throw mapSecureKeyFileError(error)
        }
        return key
    }

    private var secureKeyFile: SecureKeyFile {
        SecureKeyFile(path: keyFileURL.path)
    }

    private func loadKeyFileIfValid(
        invalidError: APSError
    ) throws -> Curve25519.KeyAgreement.PrivateKey? {
        let encoded: Data?
        do {
            encoded = try secureKeyFile.load()
        } catch SecureKeyFileError.invalidSize {
            throw invalidError
        } catch {
            throw mapSecureKeyFileError(error)
        }
        guard let encoded else {
            return nil
        }
        guard let raw = Data(base64Encoded: encoded), raw.base64EncodedData() == encoded else {
            throw invalidError
        }
        do {
            return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw)
        } catch {
            throw invalidError
        }
    }

    private func invalidKeyMaterialError() -> APSError {
        hasSecret ? .secretUnlockFailed : .persistenceFailed(key: keyName)
    }

    private func mapSecureKeyFileError(_ error: Error) -> APSError {
        guard let secureError = error as? SecureKeyFileError else {
            return APSError.persistenceFailed(key: keyName)
        }
        switch secureError {
        case .unsafeFileType:
            return APSError.insecureSecretKeyFile(reason: "path is not a regular file")
        case .wrongOwner:
            return APSError.insecureSecretKeyFile(reason: "file is not owned by the current user")
        case .insecurePermissions:
            return APSError.insecureSecretKeyFile(reason: "owner-only permissions could not be enforced")
        case .invalidSize(let actual):
            return APSError.insecureSecretKeyFile(reason: "unexpected size \(actual) bytes")
        case .securityUnproven:
            return APSError.insecureSecretKeyFile(reason: "file privacy could not be proven")
        case .alreadyExists, .io:
            return APSError.persistenceFailed(key: keyName)
        }
    }
}
