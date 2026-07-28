import Foundation
import Crypto
import CryptoExtras

/// Scrypt password key derivation with the fixed aps secret-store profile.
internal struct PasswordKDF: Sendable {
    /// Parameters accepted by the internal vector-testing entry point.
    internal struct Parameters: Equatable, Sendable {
        internal let rounds: Int
        internal let blockSize: Int
        internal let parallelism: Int
        internal let outputByteCount: Int
        internal let saltByteCount: Int

        internal init(
            rounds: Int,
            blockSize: Int,
            parallelism: Int,
            outputByteCount: Int,
            saltByteCount: Int
        ) {
            self.rounds = rounds
            self.blockSize = blockSize
            self.parallelism = parallelism
            self.outputByteCount = outputByteCount
            self.saltByteCount = saltByteCount
        }
    }

    /// Instance-scoped operation seam for deterministic tests and call counting.
    internal struct Operations: Sendable {
        internal let derive: @Sendable (Data, Data, Parameters) throws -> SymmetricKey

        internal init(
            derive: @escaping @Sendable (Data, Data, Parameters) throws -> SymmetricKey
        ) {
            self.derive = derive
        }

        internal static let live = Operations { password, salt, parameters in
            try KDF.Scrypt.deriveKey(
                from: password,
                salt: salt,
                outputByteCount: parameters.outputByteCount,
                rounds: parameters.rounds,
                blockSize: parameters.blockSize,
                parallelism: parameters.parallelism
            )
        }
    }

    internal enum ValidationError: Error, Equatable, Sendable {
        case invalidRounds(Int)
        case invalidBlockSize(Int)
        case invalidParallelism(Int)
        case invalidOutputByteCount(Int)
        case invalidSaltByteCount(Int)
        case invalidSaltLength(expected: Int, actual: Int)
    }

    internal static let profile = Parameters(
        rounds: 131_072,
        blockSize: 8,
        parallelism: 1,
        outputByteCount: 32,
        saltByteCount: 16
    )

    private static let maximumTestOutputByteCount = 64
    private static let maximumTestParallelism = 16
    private let operations: Operations

    internal init(operations: Operations = .live) {
        self.operations = operations
    }

    /// Derives a 32-byte key using N=131072, r=8, p=1 and a 16-byte salt.
    internal func deriveKey(from password: Data, salt: Data) throws -> SymmetricKey {
        try deriveKeyValidated(from: password, salt: salt, parameters: Self.profile)
    }

    /// Derives a key with bounded parameters for inexpensive published-vector tests.
    internal func deriveKeyForTesting(
        from password: Data,
        salt: Data,
        parameters: Parameters
    ) throws -> SymmetricKey {
        try deriveKeyValidated(from: password, salt: salt, parameters: parameters)
    }

    private func deriveKeyValidated(
        from password: Data,
        salt: Data,
        parameters: Parameters
    ) throws -> SymmetricKey {
        try Self.validate(parameters: parameters, salt: salt)
        return try operations.derive(password, salt, parameters)
    }

    private static func validate(parameters: Parameters, salt: Data) throws {
        guard
            parameters.rounds >= 2,
            parameters.rounds <= profile.rounds,
            isPowerOfTwo(parameters.rounds)
        else {
            throw ValidationError.invalidRounds(parameters.rounds)
        }
        guard (1...profile.blockSize).contains(parameters.blockSize) else {
            throw ValidationError.invalidBlockSize(parameters.blockSize)
        }
        guard (1...maximumTestParallelism).contains(parameters.parallelism) else {
            throw ValidationError.invalidParallelism(parameters.parallelism)
        }
        guard (1...maximumTestOutputByteCount).contains(parameters.outputByteCount) else {
            throw ValidationError.invalidOutputByteCount(parameters.outputByteCount)
        }
        guard (0...profile.saltByteCount).contains(parameters.saltByteCount) else {
            throw ValidationError.invalidSaltByteCount(parameters.saltByteCount)
        }
        guard salt.count == parameters.saltByteCount else {
            throw ValidationError.invalidSaltLength(
                expected: parameters.saltByteCount,
                actual: salt.count
            )
        }
    }

    private static func isPowerOfTwo(_ value: Int) -> Bool {
        value > 0 && (value & (value - 1)) == 0
    }
}
