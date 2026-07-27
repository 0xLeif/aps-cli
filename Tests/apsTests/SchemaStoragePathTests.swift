import Foundation
import XCTest
@testable import aps

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

internal final class SchemaStoragePathTests: XCTestCase {
    internal func testAcceptsNestedPortablePathAndBuildsCollisionKey() throws {
        let path = try SchemaStoragePath("Profiles/User.JSON")

        XCTAssertEqual(path.rawValue, "Profiles/User.JSON")
        XCTAssertEqual(path.collisionKey, "profiles/user.json")
    }

    internal func testRejectsUnsafeLexicalPaths() {
        let paths = [
            "",
            ".",
            "./",
            "../escape.json",
            "nested/../escape.json",
            "nested//file.json",
            "/absolute.json",
            #"C:\absolute.json"#,
            #"nested\file.json"#,
            "file.json/",
            "trailing. /file.json",
            "nested/question?.json",
            "nested/colon:name.json",
            "control\u{0000}.json",
        ]

        for path in paths {
            XCTAssertThrowsError(try SchemaStoragePath(path), "accepted unsafe path: \(path)")
        }
    }

    internal func testRejectsReservedAPSAndWindowsPathsCaseInsensitively() {
        let paths = [
            "schema.json",
            "SCHEMA.JSON",
            "secret.key",
            "SECRET.KEY",
            "secret.key/child.json",
            "schema.json.lock",
            "nested/value.lock",
            "nested/value.lock.held",
            "nested/value.lock/child.json",
            "CON",
            "nul.txt",
            "nested/COM1.json",
            "Lpt9",
            "COM¹",
            "com².txt",
            "nested/LPT³.json",
        ]

        for path in paths {
            XCTAssertThrowsError(try SchemaStoragePath(path), "accepted reserved path: \(path)")
        }
    }

    internal func testCollisionKeyNormalizesCaseAndUnicodeComposition() throws {
        let composed = try SchemaStoragePath("Caf\u{00E9}/VALUE.json")
        let decomposed = try SchemaStoragePath("Cafe\u{0301}/value.JSON")

        XCTAssertEqual(composed.collisionKey, decomposed.collisionKey)
    }

    internal func testCollisionKeyUsesFullUnicodeCaseFolding() throws {
        let capitalSigma = try SchemaStoragePath("\u{03A3}.json")
        let finalSigma = try SchemaStoragePath("\u{03C2}.json")

        XCTAssertEqual(capitalSigma.collisionKey, finalSigma.collisionKey)
    }

    internal func testDetectsAncestorAndDescendantStoragePathCollisions() throws {
        let ancestor = try SchemaStoragePath("data")
        let descendant = try SchemaStoragePath("DATA/value.json")
        let sibling = try SchemaStoragePath("database/value.json")

        XCTAssertTrue(ancestor.collides(with: descendant))
        XCTAssertTrue(descendant.collides(with: ancestor))
        XCTAssertFalse(ancestor.collides(with: sibling))
    }

    internal func testSchemaRejectsAncestorAndDescendantStoragePathCollisions() {
        let document = UserSchemaDocument(keys: [
            SchemaKeyEntry(
                name: "ancestor",
                type: "String",
                storage: "FileState",
                initial: .string(""),
                path: "data"
            ),
            SchemaKeyEntry(
                name: "descendant",
                type: "String",
                storage: "EncryptedFile",
                initial: .string(""),
                path: "data/value.json"
            ),
        ])

        XCTAssertThrowsError(try UserSchema.validate(document))
    }

    internal func testResolvesMissingNestedLeafBeneathCanonicalRoot() throws {
        try withStateRoot { root in
            let path = try SchemaStoragePath("nested/value.json")
            let resolved = try path.resolve(stateRoot: root.path)
            let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()

            XCTAssertEqual(
                resolved,
                canonicalRoot.appendingPathComponent("nested/value.json")
            )
        }
    }

    internal func testRejectsExistingDirectoryLeaf() throws {
        try withStateRoot { root in
            let directory = root.appendingPathComponent("value.json", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)

            let path = try SchemaStoragePath("value.json")
            XCTAssertThrowsError(try path.resolve(stateRoot: root.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        }
    }

    internal func testRejectsSymbolicLinkLeaf() throws {
        try withStateRoot { root in
            let target = root.appendingPathComponent("target.json")
            try Data("sentinel".utf8).write(to: target)
            let link = root.appendingPathComponent("link.json")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

            let path = try SchemaStoragePath("link.json")
            XCTAssertThrowsError(try path.resolve(stateRoot: root.path))
            XCTAssertEqual(try Data(contentsOf: target), Data("sentinel".utf8))
        }
    }

    internal func testRejectsSymbolicLinkAncestor() throws {
        try withStateRoot { root in
            let outside = FileManager.default.temporaryDirectory
                .appendingPathComponent("aps-path-outside-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: outside) }

            let link = root.appendingPathComponent("linked", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

            let path = try SchemaStoragePath("linked/value.json")
            XCTAssertThrowsError(try path.resolve(stateRoot: root.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("value.json").path))
        }
    }

    internal func testDeletionOfMissingLeafIsNoOp() throws {
        try withStateRoot { root in
            let path = try SchemaStoragePath("missing.json")

            XCTAssertFalse(try path.removeRegularFileIfPresent(stateRoot: root.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        }
    }

    internal func testDeletesOnlyRegularLeaf() throws {
        try withStateRoot { root in
            let file = root.appendingPathComponent("value.json")
            try Data("value".utf8).write(to: file)
            let path = try SchemaStoragePath("value.json")

            XCTAssertTrue(try path.removeRegularFileIfPresent(stateRoot: root.path))

            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        }
    }

    internal func testInjectedDeletionFailureIsPersistenceErrorAndPreservesLeaf() throws {
        try withStateRoot { root in
            let file = root.appendingPathComponent("value.json")
            try Data("keep".utf8).write(to: file)
            let path = try SchemaStoragePath("value.json")
            let operations = SchemaStoragePath.DeletionOperations(
                removeItem: { _ in throw InjectedFailure.delete },
                isAbsent: { _ in false }
            )

            XCTAssertThrowsError(
                try path.removeRegularFileIfPresent(
                    stateRoot: root.path,
                    operations: operations
                )
            ) { error in
                XCTAssertEqual(error as? APSError, .persistenceFailed(key: "value.json"))
            }
            XCTAssertEqual(try Data(contentsOf: file), Data("keep".utf8))
        }
    }

    internal func testInjectedPostconditionFailureIsPersistenceError() throws {
        try withStateRoot { root in
            let file = root.appendingPathComponent("value.json")
            try Data("keep".utf8).write(to: file)
            let path = try SchemaStoragePath("value.json")
            let operations = SchemaStoragePath.DeletionOperations(
                removeItem: { _ in },
                isAbsent: { _ in false }
            )

            XCTAssertThrowsError(
                try path.removeRegularFileIfPresent(
                    stateRoot: root.path,
                    operations: operations
                )
            ) { error in
                XCTAssertEqual(error as? APSError, .persistenceFailed(key: "value.json"))
            }
            XCTAssertEqual(try Data(contentsOf: file), Data("keep".utf8))
        }
    }

    internal func testInjectedPostconditionReadFailureIsPersistenceError() throws {
        try withStateRoot { root in
            let file = root.appendingPathComponent("value.json")
            try Data("keep".utf8).write(to: file)
            let path = try SchemaStoragePath("value.json")
            let operations = SchemaStoragePath.DeletionOperations(
                removeItem: { _ in },
                isAbsent: { _ in throw InjectedFailure.postcondition }
            )

            XCTAssertThrowsError(
                try path.removeRegularFileIfPresent(
                    stateRoot: root.path,
                    operations: operations
                )
            ) { error in
                XCTAssertEqual(error as? APSError, .persistenceFailed(key: "value.json"))
            }
            XCTAssertEqual(try Data(contentsOf: file), Data("keep".utf8))
        }
    }

    internal func testDirectoryDeletionIsRejectedAndPreserved() throws {
        try withStateRoot { root in
            let directory = root.appendingPathComponent("value.json", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            let sentinel = directory.appendingPathComponent("sentinel")
            try Data("keep".utf8).write(to: sentinel)
            let path = try SchemaStoragePath("value.json")

            XCTAssertThrowsError(try path.removeRegularFileIfPresent(stateRoot: root.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
        }
    }

    internal func testSecretResetReturnsRemovalStateAndPreservesSharedKey() throws {
        try withStateRoot { root in
            let envelope = root.appendingPathComponent("custom.enc")
            let key = root.appendingPathComponent("secret.key")
            let keyData = Data("shared-key-material".utf8)
            try Data("envelope".utf8).write(to: envelope)
            try keyData.write(to: key)
            let store = SecretStore(
                directory: root.path,
                storeFileName: "custom.enc",
                keyName: "custom"
            )

            XCTAssertTrue(try store.reset())
            XCTAssertFalse(FileManager.default.fileExists(atPath: envelope.path))
            XCTAssertEqual(try Data(contentsOf: key), keyData)
            XCTAssertFalse(try store.reset())
            XCTAssertEqual(try Data(contentsOf: key), keyData)
        }
    }

    internal func testSecretResetMapsInjectedDeletionFailureAndPreservesFiles() throws {
        try withStateRoot { root in
            let envelope = root.appendingPathComponent("custom.enc")
            let key = root.appendingPathComponent("secret.key")
            let envelopeData = Data("envelope".utf8)
            let keyData = Data("shared-key-material".utf8)
            try envelopeData.write(to: envelope)
            try keyData.write(to: key)
            let operations = SchemaStoragePath.DeletionOperations(
                removeItem: { _ in throw InjectedFailure.delete },
                isAbsent: { _ in false }
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
            XCTAssertEqual(try Data(contentsOf: envelope), envelopeData)
            XCTAssertEqual(try Data(contentsOf: key), keyData)
        }
    }

    internal func testSecretResetRejectsDirectoryEnvelopeAndPreservesContents() throws {
        try withStateRoot { root in
            let envelope = root.appendingPathComponent("custom.enc", isDirectory: true)
            try FileManager.default.createDirectory(at: envelope, withIntermediateDirectories: false)
            let sentinel = envelope.appendingPathComponent("sentinel")
            try Data("keep".utf8).write(to: sentinel)
            let store = SecretStore(
                directory: root.path,
                storeFileName: "custom.enc",
                keyName: "custom"
            )

            XCTAssertThrowsError(try store.reset()) { error in
                guard let apsError = error as? APSError,
                      case .schemaInvalid = apsError
                else {
                    XCTFail("expected schemaInvalid, received \(error)")
                    return
                }
            }
            XCTAssertEqual(try Data(contentsOf: sentinel), Data("keep".utf8))
        }
    }

    #if canImport(Darwin) || canImport(Glibc)
    internal func testInaccessibleAncestorIsNotReportedAsMissing() throws {
        try withStateRoot { root in
            let directory = root.appendingPathComponent("blocked", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            let file = directory.appendingPathComponent("value.json")
            try Data("keep".utf8).write(to: file)
            XCTAssertEqual(chmod(directory.path, 0), 0)
            defer { _ = chmod(directory.path, 0o700) }

            let path = try SchemaStoragePath("blocked/value.json")
            XCTAssertThrowsError(try path.resolve(stateRoot: root.path))
            XCTAssertThrowsError(try path.removeRegularFileIfPresent(stateRoot: root.path))
        }
    }

    internal func testSpecialFileIsRejected() throws {
        try withStateRoot { root in
            let fifo = root.appendingPathComponent("value.json")
            XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
            let path = try SchemaStoragePath("value.json")

            XCTAssertThrowsError(try path.resolve(stateRoot: root.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: fifo.path))
        }
    }
    #endif

    private enum InjectedFailure: Error, Sendable {
        case delete
        case postcondition
    }

    private func withStateRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-storage-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
