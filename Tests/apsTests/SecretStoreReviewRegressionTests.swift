import Foundation
import XCTest
@testable import aps

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import WinSDK
#endif

internal final class SecretStoreReviewRegressionTests: XCTestCase {
    private var directoryURL: URL?
    private var holdsIsolationGate = false
    private var originalFileStatePath: String?

    internal override func setUp() async throws {
        try await super.setUp()
        await TestIsolationGate.shared.acquire()
        holdsIsolationGate = true

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-secret-review-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        directoryURL = directory
        setReviewEnvironment("APS_SECRET_PASSPHRASE", nil)
        setReviewEnvironment("APS_SECRET_USE_PASSPHRASE", nil)
        originalFileStatePath = await MainActor.run {
            let original = FileManager.defaultFileStatePath
            FileManager.defaultFileStatePath = directory.path
            return original
        }
    }

    internal override func tearDown() async throws {
        setReviewEnvironment("APS_SECRET_PASSPHRASE", nil)
        setReviewEnvironment("APS_SECRET_USE_PASSPHRASE", nil)
        let originalPath = originalFileStatePath
        await MainActor.run {
            if let originalPath {
                FileManager.defaultFileStatePath = originalPath
            }
        }
        originalFileStatePath = nil
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

    internal func testDeeplyNestedEnvelopeReturnsDecodingFailed() throws {
        let directory = try XCTUnwrap(directoryURL)
        let store = SecretStore(directory: directory.path)
        let depth = 8_192
        let hostile = String(repeating: "[", count: depth)
            + "null"
            + String(repeating: "]", count: depth)
        try Data(hostile.utf8).write(
            to: directory.appendingPathComponent("secret.enc"),
            options: .atomic
        )

        XCTAssertThrowsError(try store.get()) { error in
            XCTAssertEqual(error as? APSError, .decodingFailed)
        }
    }

    #if os(Linux)
    internal func testParallelFirstLoadsSerializePermissionRepair() async throws {
        let directory = try XCTUnwrap(directoryURL)
        let store = SecretStore(directory: directory.path)
        try store.set("protected")
        let keyURL = directory.appendingPathComponent("secret.key")
        XCTAssertEqual(chmod(keyURL.path, mode_t(0o000)), 0)

        let successCount = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    (try? store.get()) == "protected"
                }
            }
            var successes = 0
            for await succeeded in group where succeeded {
                successes += 1
            }
            return successes
        }

        XCTAssertEqual(successCount, 16)
    }
    #endif

    @MainActor
    internal func testRegisteredEncryptedWatchRejectsReplacedSymlinkAncestor() async throws {
        #if canImport(Darwin) || canImport(Glibc)
        let root = try XCTUnwrap(directoryURL)
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-secret-watch-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }

        let store = StateStore()
        let entry = SchemaKeyEntry(
            name: "nestedSecret",
            type: "String",
            storage: "EncryptedFile",
            initial: .string(""),
            path: "nested/secret.enc",
            doc: "nested encrypted watch"
        )
        try store.addKey(entry, force: false)
        try store.set(name: entry.name, value: "outside")
        let nestedDirectory = root.appendingPathComponent("nested", isDirectory: true)
        let envelopeURL = nestedDirectory.appendingPathComponent("secret.enc")
        let outsideEnvelope = try Data(contentsOf: envelopeURL)
        try outsideEnvelope.write(
            to: outside.appendingPathComponent("secret.enc"),
            options: .atomic
        )
        try store.set(name: entry.name, value: "inside")

        var observed: [String] = []
        var replacementError: Error?
        var pollCount = 0
        XCTAssertThrowsError(
            try store.watchBlocking(
                name: entry.name,
                pollInterval: 0,
                shouldContinue: {
                    pollCount += 1
                    return pollCount <= 1
                },
                onChange: { value in
                    observed.append(value)
                    guard observed.count == 1 else { return }
                    do {
                        try FileManager.default.removeItem(at: nestedDirectory)
                        try FileManager.default.createSymbolicLink(
                            at: nestedDirectory,
                            withDestinationURL: outside
                        )
                    } catch {
                        replacementError = error
                    }
                }
            )
        ) { error in
            guard case .schemaInvalid = error as? APSError else {
                XCTFail("expected schemaInvalid, received \(error)")
                return
            }
        }
        XCTAssertNil(replacementError)
        XCTAssertEqual(observed, ["inside"])
        #else
        throw XCTSkip("symbolic-link ancestor replacement requires POSIX")
        #endif
    }
}

private func setReviewEnvironment(_ key: String, _ value: String?) {
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
