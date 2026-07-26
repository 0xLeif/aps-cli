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
            "schema.json.lock",
            "nested/value.lock",
            "nested/value.lock.held",
            "CON",
            "nul.txt",
            "nested/COM1.json",
            "Lpt9",
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

    internal func testResolvesMissingNestedLeafBeneathCanonicalRoot() throws {
        try withStateRoot { root in
            let path = try SchemaStoragePath("nested/value.json")
            let resolved = try path.resolve(stateRoot: root.path)

            XCTAssertEqual(resolved, root.appendingPathComponent("nested/value.json"))
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

            XCTAssertNoThrow(try path.removeRegularFileIfPresent(stateRoot: root.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        }
    }

    internal func testDeletesOnlyRegularLeaf() throws {
        try withStateRoot { root in
            let file = root.appendingPathComponent("value.json")
            try Data("value".utf8).write(to: file)
            let path = try SchemaStoragePath("value.json")

            try path.removeRegularFileIfPresent(stateRoot: root.path)

            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
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

    #if canImport(Darwin) || canImport(Glibc)
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

    private func withStateRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-storage-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
