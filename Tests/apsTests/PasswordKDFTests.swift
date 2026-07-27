import Foundation
import Crypto
import XCTest
@testable import aps

internal final class PasswordKDFTests: XCTestCase {
    internal func testProfileUsesExactParameters() throws {
        let expectedKey = SymmetricKey(data: Data(repeating: 0xA5, count: 32))
        let operations = PasswordKDF.Operations { password, salt, parameters in
            XCTAssertEqual(password, Data("correct horse battery staple".utf8))
            XCTAssertEqual(salt, Data(repeating: 0x3C, count: 16))
            XCTAssertEqual(parameters.rounds, 131_072)
            XCTAssertEqual(parameters.blockSize, 8)
            XCTAssertEqual(parameters.parallelism, 1)
            XCTAssertEqual(parameters.outputByteCount, 32)
            XCTAssertEqual(parameters.saltByteCount, 16)
            return expectedKey
        }
        let kdf = PasswordKDF(operations: operations)

        let key = try kdf.deriveKey(
            from: Data("correct horse battery staple".utf8),
            salt: Data(repeating: 0x3C, count: 16)
        )

        XCTAssertEqual(key, expectedKey)
    }

    internal func testRejectsMalformedSaltBeforeInvokingKDF() throws {
        let operations = PasswordKDF.Operations { _, _, _ in
            XCTFail("Invalid input must not reach CryptoExtras")
            return SymmetricKey(data: Data(repeating: 0, count: 32))
        }
        let kdf = PasswordKDF(operations: operations)

        XCTAssertThrowsError(
            try kdf.deriveKey(
                from: Data("password".utf8),
                salt: Data(repeating: 0x7A, count: 15)
            )
        ) { error in
            XCTAssertEqual(
                error as? PasswordKDF.ValidationError,
                .invalidSaltLength(expected: 16, actual: 15)
            )
        }
    }

    internal func testRejectsHostileParametersBeforeInvokingKDF() throws {
        let operations = PasswordKDF.Operations { _, _, _ in
            XCTFail("Invalid input must not reach CryptoExtras")
            return SymmetricKey(data: Data(repeating: 0, count: 32))
        }
        let kdf = PasswordKDF(operations: operations)
        let parameters = PasswordKDF.Parameters(
            rounds: Int.max,
            blockSize: 8,
            parallelism: 1,
            outputByteCount: 32,
            saltByteCount: 16
        )

        XCTAssertThrowsError(
            try kdf.deriveKeyForTesting(
                from: Data("password".utf8),
                salt: Data(repeating: 0x7A, count: 16),
                parameters: parameters
            )
        ) { error in
            XCTAssertEqual(
                error as? PasswordKDF.ValidationError,
                .invalidRounds(Int.max)
            )
        }
    }

    internal func testRFC7914EmptyPasswordAndSaltVector() throws {
        let parameters = PasswordKDF.Parameters(
            rounds: 16,
            blockSize: 1,
            parallelism: 1,
            outputByteCount: 64,
            saltByteCount: 0
        )
        let expected = try XCTUnwrap(
            data(
                hexadecimal: """
                77d6576238657b203b19ca42c18a0497
                f16b4844e3074ae8dfdffa3fede21442
                fcd0069ded0948f8326a753a0fc81f17
                e8d3e0fb2e0d3628cf35e20c38d18906
                """
            )
        )

        let key = try PasswordKDF().deriveKeyForTesting(
            from: Data(),
            salt: Data(),
            parameters: parameters
        )
        let actual = key.withUnsafeBytes { bytes in
            Data(bytes)
        }

        XCTAssertEqual(actual, expected)
    }
}

fileprivate func data(hexadecimal: String) -> Data? {
    let compact = hexadecimal.filter { !$0.isWhitespace }
    guard compact.count.isMultiple(of: 2) else {
        return nil
    }

    var bytes: [UInt8] = []
    bytes.reserveCapacity(compact.count / 2)
    var index = compact.startIndex
    while index < compact.endIndex {
        let nextIndex = compact.index(index, offsetBy: 2)
        guard let byte = UInt8(compact[index..<nextIndex], radix: 16) else {
            return nil
        }
        bytes.append(byte)
        index = nextIndex
    }
    return Data(bytes)
}
