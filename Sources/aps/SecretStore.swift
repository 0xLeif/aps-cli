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
///   passphrase via HKDF-SHA256 (no key file involved).
/// - `APS_SECRET_USE_PASSPHRASE=1` on a TTY: one interactive prompt (our
///   getpass prompt, not macOS Keychain's), same derivation.
/// - Otherwise a key file at `<state-root>/secret.key` (base64 raw X25519
///   private key, mode 0600) is created on first use, like an SSH key.
public struct SecretStore: Sendable {

    /// On-disk envelope: one JSON object with base64 fields.
    struct Envelope: Codable {
        let ephemeralPublicKey: String
        let nonce: String
        let ciphertext: String
        let tag: String
    }

    private let directory: String
    private let storeFileName: String
    private let keyName: String

    /// Store rooted at the configured FileState path (`secret.enc`).
    @MainActor
    public init() {
        self.directory = FileManager.defaultFileStatePath
        self.storeFileName = "secret.enc"
        self.keyName = "secret"
    }

    /// Store rooted at an explicit directory (tests, tooling).
    public init(directory: String, storeFileName: String = "secret.enc", keyName: String = "secret") {
        self.directory = directory
        self.storeFileName = storeFileName
        self.keyName = keyName
    }

    private var storeURL: URL {
        URL(fileURLWithPath: directory).appendingPathComponent(storeFileName)
    }

    private var keyFileURL: URL {
        URL(fileURLWithPath: directory).appendingPathComponent("secret.key")
    }

    private var usesPassphraseMode: Bool {
        if ProcessInfo.processInfo.environment["APS_SECRET_PASSPHRASE"] != nil {
            return true
        }
        #if !os(Windows)
        return ProcessInfo.processInfo.environment["APS_SECRET_USE_PASSPHRASE"] == "1"
            && isatty(FileHandle.standardError.fileDescriptor) == 1
        #else
        return false
        #endif
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
        try getUnlocked(lockKeyFile: true)
    }

    private func getUnlocked(lockKeyFile: Bool) throws -> String {
        let data: Data
        do {
            data = try Data(contentsOf: storeURL)
        } catch {
            throw APSError.persistenceFailed(key: keyName)
        }
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw APSError.decodingFailed
        }
        return try open(envelope, lockKeyFile: lockKeyFile)
    }

    /// Encrypt and store the value, then verify by decrypting the file back.
    ///
    /// When an envelope already exists, unlock it with the current recipient key
    /// before rewriting. A wrong passphrase or key fails with
    /// `secretUnlockFailed` and leaves ciphertext unchanged (issue #89).
    public func set(_ value: String) throws {
        try SchemaFileLock.withExclusiveLock(
            stateRoot: directory,
            lockFileName: "secret.store.lock"
        ) {
            try setUnlocked(value)
        }
    }

    private func setUnlocked(_ value: String) throws {
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
        if !hasSecret && !usesPassphraseMode {
            try removeInvalidKeyFileWithoutEnvelope()
        }
        if hasSecret {
            // Prove the caller can open the existing envelope before re-keying.
            do {
                _ = try getUnlocked(lockKeyFile: false)
            } catch {
                if let error = error as? APSError {
                    throw error
                }
                throw APSError.secretUnlockFailed
            }
        }
        let envelope = try seal(value, lockKeyFile: false)
        let data = try JSONEncoder().encode(envelope)
        do {
            try data.write(to: storeURL, options: .atomic)
        } catch {
            throw APSError.persistenceFailed(key: keyName)
        }
        // Read-back verification (same discipline as FileState writes).
        guard try getUnlocked(lockKeyFile: false) == value else {
            throw APSError.persistenceFailed(key: keyName)
        }
    }

    /// Reset to the initial value: the store file is deleted.
    public func reset() {
        try? FileManager.default.removeItem(at: storeURL)
    }

    // MARK: - Envelope cryptography

    private func seal(_ value: String, lockKeyFile: Bool) throws -> Envelope {
        let recipientPublic = try recipientKey(lockKeyFile: lockKeyFile).publicKey
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let symmetric = try deriveSymmetricKey(privateKey: ephemeral, publicKey: recipientPublic)
        let nonce = ChaChaPoly.Nonce()
        let sealedBox = try ChaChaPoly.seal(
            Data(value.utf8),
            using: symmetric,
            nonce: nonce
        )
        return Envelope(
            ephemeralPublicKey: ephemeral.publicKey.rawRepresentation.base64EncodedString(),
            nonce: nonce.withUnsafeBytes { Data($0) }.base64EncodedString(),
            ciphertext: sealedBox.ciphertext.base64EncodedString(),
            tag: sealedBox.tag.base64EncodedString()
        )
    }

    private func open(_ envelope: Envelope, lockKeyFile: Bool) throws -> String {
        guard
            let ephemeralPublicData = Data(base64Encoded: envelope.ephemeralPublicKey),
            let nonceData = Data(base64Encoded: envelope.nonce),
            let ciphertext = Data(base64Encoded: envelope.ciphertext),
            let tag = Data(base64Encoded: envelope.tag),
            let ephemeralPublic = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralPublicData),
            let nonce = try? ChaChaPoly.Nonce(data: nonceData),
            let box = try? ChaChaPoly.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        else {
            throw APSError.decodingFailed
        }
        let symmetric = try deriveSymmetricKey(
            privateKey: try recipientKey(lockKeyFile: lockKeyFile),
            publicKey: ephemeralPublic
        )
        let plaintext: Data
        do {
            plaintext = try ChaChaPoly.open(box, using: symmetric)
        } catch {
            throw APSError.secretUnlockFailed
        }
        guard let value = String(data: plaintext, encoding: .utf8) else {
            throw APSError.decodingFailed
        }
        return value
    }

    private func deriveSymmetricKey(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        publicKey: Curve25519.KeyAgreement.PublicKey
    ) throws -> SymmetricKey {
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("aps-secret-store-v1".utf8),
            sharedInfo: Data("envelope".utf8),
            outputByteCount: 32
        )
    }

    // MARK: - Recipient key

    private func recipientKey(lockKeyFile: Bool) throws -> Curve25519.KeyAgreement.PrivateKey {
        if let passphrase = ProcessInfo.processInfo.environment["APS_SECRET_PASSPHRASE"] {
            guard !passphrase.isEmpty else {
                throw APSError.secretUnlockFailed
            }
            return Self.keyFromPassphrase(passphrase)
        }
        #if !os(Windows)
        if ProcessInfo.processInfo.environment["APS_SECRET_USE_PASSPHRASE"] == "1",
           isatty(FileHandle.standardError.fileDescriptor) == 1,
           let passphrase = Self.promptPassphrase() {
            return Self.keyFromPassphrase(passphrase)
        }
        #endif
        if lockKeyFile {
            return try loadOrCreateKeyFile()
        }
        do {
            return try loadOrCreateKeyFileUnlocked()
        } catch let error as APSError {
            if case .persistenceFailed = error {
                throw APSError.secretUnlockFailed
            }
            throw error
        }
    }

    static func keyFromPassphrase(_ passphrase: String) -> Curve25519.KeyAgreement.PrivateKey {
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(passphrase.utf8)),
            salt: Data("aps-secret-store-v1".utf8),
            info: Data("x25519-key".utf8),
            outputByteCount: 32
        )
        return try! Curve25519.KeyAgreement.PrivateKey(rawRepresentation: derived.withUnsafeBytes { Data($0) })
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
        if let key = loadKeyFileIfValid() {
            return key
        }

        return try SchemaFileLock.withExclusiveLock(
            stateRoot: directory,
            lockFileName: "secret.key.lock"
        ) {
            try loadOrCreateKeyFileUnlocked()
        }
    }

    private func loadOrCreateKeyFileUnlocked() throws -> Curve25519.KeyAgreement.PrivateKey {
        if let key = loadKeyFileIfValid() {
            return key
        }

        let hasExistingKeyPath = FileManager.default.fileExists(atPath: keyFileURL.path)
        do {
            return try createKeyFile()
        } catch let error as APSError {
            if hasExistingKeyPath, case .persistenceFailed = error {
                throw APSError.secretUnlockFailed
            }
            throw error
        }
    }

    private func loadKeyFileIfValid() -> Curve25519.KeyAgreement.PrivateKey? {
        guard
            let data = try? Data(contentsOf: keyFileURL),
            let raw = Data(base64Encoded: data),
            let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw)
        else {
            return nil
        }
        return key
    }

    private func removeInvalidKeyFileWithoutEnvelope() throws {
        guard
            FileManager.default.fileExists(atPath: keyFileURL.path),
            loadKeyFileIfValid() == nil
        else {
            return
        }
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: keyFileURL.path),
            let type = attributes[.type] as? FileAttributeType,
            type == .typeRegular
        else {
            throw APSError.persistenceFailed(key: keyName)
        }
        do {
            try FileManager.default.removeItem(at: keyFileURL)
        } catch {
            throw APSError.persistenceFailed(key: keyName)
        }
    }

    private func createKeyFile() throws -> Curve25519.KeyAgreement.PrivateKey {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let created = FileManager.default.createFile(
            atPath: keyFileURL.path,
            contents: key.rawRepresentation.base64EncodedData(),
            attributes: [.posixPermissions: 0o600]
        )
        guard created else {
            throw APSError.persistenceFailed(key: keyName)
        }
        return key
    }
}
