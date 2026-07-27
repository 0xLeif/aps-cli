import Foundation
import XCTest
@testable import aps

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

#if os(Windows)
import WinSDK
#endif

internal final class SecureKeyFileTests: XCTestCase {
    #if !os(Windows)
    internal func testLoadRepairsOwnedRegularFilePermissions() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let expected = keyData(1)
        try expected.write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o644)), 0)

        XCTAssertEqual(try fixture.secureFile.load(), expected)

        var status = stat()
        XCTAssertEqual(stat(fixture.file.path, &status), 0)
        XCTAssertEqual(status.st_mode & mode_t(0o777), mode_t(0o600))
    }

    internal func testLoadRepairsOwnedParentDirectoryPermissions() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try keyData(2).write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.directory.path, mode_t(0o755)), 0)

        XCTAssertNotNil(try fixture.secureFile.load())

        var status = stat()
        XCTAssertEqual(stat(fixture.directory.path, &status), 0)
        XCTAssertEqual(status.st_mode & mode_t(0o077), 0)
    }

    internal func testLoadRejectsOversizedFileBeforeReading() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try Data(repeating: 1, count: SecureKeyFile.expectedByteCount + 1)
            .write(to: fixture.file)

        XCTAssertThrowsError(try fixture.secureFile.load()) { error in
            XCTAssertEqual(
                error as? SecureKeyFileError,
                .invalidSize(actual: Int64(SecureKeyFile.expectedByteCount + 1))
            )
        }
    }

    internal func testLoadRejectsSparseFileBeforeReading() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try Data().write(to: fixture.file)
        let sparseSize: off_t = 1_073_741_824
        XCTAssertEqual(truncate(fixture.file.path, sparseSize), 0)

        XCTAssertThrowsError(try fixture.secureFile.load()) { error in
            XCTAssertEqual(
                error as? SecureKeyFileError,
                .invalidSize(actual: Int64(sparseSize))
            )
        }
    }

    internal func testLoadRejectsSymlinkWithoutChangingTarget() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let target = fixture.directory.appendingPathComponent("target")
        let expected = Data("target-key".utf8)
        try expected.write(to: target)
        XCTAssertEqual(chmod(target.path, mode_t(0o644)), 0)
        XCTAssertEqual(symlink(target.path, fixture.file.path), 0)

        XCTAssertThrowsError(try fixture.secureFile.load()) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .unsafeFileType)
        }
        XCTAssertEqual(try Data(contentsOf: target), expected)

        var status = stat()
        XCTAssertEqual(stat(target.path, &status), 0)
        XCTAssertEqual(status.st_mode & mode_t(0o777), mode_t(0o644))
    }

    internal func testLoadRejectsDirectory() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try FileManager.default.createDirectory(at: fixture.file, withIntermediateDirectories: false)

        XCTAssertThrowsError(try fixture.secureFile.load()) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .unsafeFileType)
        }
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.file.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    internal func testLoadRejectsFIFOWithoutBlocking() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        XCTAssertEqual(mkfifo(fixture.file.path, mode_t(0o600)), 0)

        XCTAssertThrowsError(try fixture.secureFile.load()) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .unsafeFileType)
        }
        var status = stat()
        XCTAssertEqual(lstat(fixture.file.path, &status), 0)
        XCTAssertEqual(status.st_mode & mode_t(S_IFMT), mode_t(S_IFIFO))
    }

    internal func testCreateUses0600UnderHostileUmask() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let previousMask = umask(mode_t(0o777))
        defer { _ = umask(previousMask) }
        let expected = keyData(3)

        try fixture.secureFile.create(expected)

        XCTAssertEqual(try fixture.secureFile.load(), expected)
        var status = stat()
        XCTAssertEqual(stat(fixture.file.path, &status), 0)
        XCTAssertEqual(status.st_mode & mode_t(0o777), mode_t(0o600))
    }

    internal func testCreateDoesNotReplaceExistingFile() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let existing = keyData(4)
        try existing.write(to: fixture.file)

        XCTAssertThrowsError(try fixture.secureFile.create(keyData(5))) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .alreadyExists)
        }
        XCTAssertEqual(try Data(contentsOf: fixture.file), existing)
    }

    internal func testRemoveForRegenerationRequiresExplicitAuthorization() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let corrupt = Data("corrupt-key".utf8)
        try corrupt.write(to: fixture.file)

        XCTAssertThrowsError(try fixture.secureFile.removeForRegeneration(noEnvelope: false)) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .regenerationNotAllowed)
        }
        XCTAssertEqual(try Data(contentsOf: fixture.file), corrupt)

        XCTAssertTrue(try fixture.secureFile.removeForRegeneration(noEnvelope: true))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.file.path))
        XCTAssertFalse(try fixture.secureFile.removeForRegeneration(noEnvelope: true))
    }

    internal func testRemoveForRegenerationRejectsSpecialPaths() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let target = fixture.directory.appendingPathComponent("target")
        let expected = Data("unchanged".utf8)
        try expected.write(to: target)
        XCTAssertEqual(symlink(target.path, fixture.file.path), 0)

        XCTAssertThrowsError(try fixture.secureFile.removeForRegeneration(noEnvelope: true)) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .unsafeFileType)
        }
        XCTAssertEqual(try Data(contentsOf: target), expected)
    }

    internal func testCreateRaceNeverDeletesSwappedEntry() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let displaced = fixture.directory.appendingPathComponent("displaced-created-key")
        let replacement = keyData(6)
        let created = keyData(7)
        let filePath = fixture.file.path
        let displacedPath = displaced.path
        let secureFile = SecureKeyFile(
            path: filePath,
            raceHooks: SecureKeyFileRaceHooks(
                beforeCreatePathVerification: {
                    _ = rename(filePath, displacedPath)
                    _ = FileManager.default.createFile(
                        atPath: filePath,
                        contents: replacement
                    )
                }
            )
        )

        XCTAssertThrowsError(try secureFile.create(created)) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .securityUnproven)
        }
        XCTAssertTrue(try directoryContains(data: replacement, directory: fixture.directory))
        XCTAssertEqual(try Data(contentsOf: displaced), created)
    }

    internal func testRemoveRaceNeverDeletesSwappedEntry() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let original = Data("original-key".utf8)
        let replacement = keyData(8)
        let displaced = fixture.directory.appendingPathComponent("displaced-original-key")
        try original.write(to: fixture.file)
        let filePath = fixture.file.path
        let displacedPath = displaced.path
        let secureFile = SecureKeyFile(
            path: filePath,
            raceHooks: SecureKeyFileRaceHooks(
                beforeQuarantineRename: {
                    _ = rename(filePath, displacedPath)
                    _ = FileManager.default.createFile(
                        atPath: filePath,
                        contents: replacement
                    )
                }
            )
        )

        XCTAssertThrowsError(try secureFile.removeForRegeneration(noEnvelope: true)) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .securityUnproven)
        }
        XCTAssertTrue(try directoryContains(data: replacement, directory: fixture.directory))
        XCTAssertEqual(try Data(contentsOf: displaced), original)
    }

    private func makeFixture() throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-secure-key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let file = directory.appendingPathComponent("secret.key")
        return Fixture(
            directory: directory,
            file: file,
            secureFile: SecureKeyFile(path: file.path)
        )
    }

    private func directoryContains(data: Data, directory: URL) throws -> Bool {
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return entries.contains { entry in
            (try? Data(contentsOf: entry)) == data
        }
    }

    private func keyData(_ byte: UInt8) -> Data {
        Data(repeating: byte, count: SecureKeyFile.expectedByteCount)
    }

    private struct Fixture {
        fileprivate let directory: URL
        fileprivate let file: URL
        fileprivate let secureFile: SecureKeyFile
    }
    #else
    internal func testMissingWindowsKeyReturnsNil() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-missing-\(UUID().uuidString)")
            .path
        XCTAssertNil(try SecureKeyFile(path: path).load())
    }

    internal func testWindowsCreateUsesProtectedACLUnderPermissiveParent() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-key-parent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let file = directory.appendingPathComponent("secret.key")
        let secureFile = SecureKeyFile(path: file.path)
        let expected = Data(repeating: 1, count: SecureKeyFile.expectedByteCount)
        defer { try? FileManager.default.removeItem(at: directory) }

        try secureFile.create(expected)

        XCTAssertEqual(try secureFile.load(), expected)
        XCTAssertTrue(try secureFile.removeForRegeneration(noEnvelope: true))
        XCTAssertNil(try secureFile.load())
    }

    internal func testWindowsLoadRepairsCurrentUserFileACL() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-key-repair-\(UUID().uuidString)")
        let expected = Data(repeating: 2, count: SecureKeyFile.expectedByteCount)
        let secureFile = SecureKeyFile(path: file.path)
        try secureFile.create(expected)
        try makeWindowsDACLPermissive(file)
        defer { try? FileManager.default.removeItem(at: file) }

        XCTAssertEqual(try secureFile.load(), expected)
    }

    internal func testWindowsLoadRejectsOversizedFileBeforeReading() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-key-oversized-\(UUID().uuidString)")
        let secureFile = SecureKeyFile(path: file.path)
        try secureFile.create(Data(repeating: 3, count: SecureKeyFile.expectedByteCount))
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: Data([3]))
        defer { try? FileManager.default.removeItem(at: file) }

        XCTAssertThrowsError(try secureFile.load()) { error in
            XCTAssertEqual(
                error as? SecureKeyFileError,
                .invalidSize(actual: Int64(SecureKeyFile.expectedByteCount + 1))
            )
        }
    }

    internal func testWindowsDirectoryIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-key-directory-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try SecureKeyFile(path: directory.path).load()) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .unsafeFileType)
        }
    }

    private func makeWindowsDACLPermissive(_ file: URL) throws {
        let handle = file.path.withCString(encodedAs: UTF16.self) { pathPointer in
            CreateFileW(
                pathPointer,
                DWORD(READ_CONTROL) | DWORD(WRITE_DAC),
                DWORD(FILE_SHARE_READ) | DWORD(FILE_SHARE_WRITE) | DWORD(FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_ATTRIBUTE_NORMAL),
                nil
            )
        }
        guard handle != INVALID_HANDLE_VALUE, let handle else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { _ = CloseHandle(handle) }
        let result = SetSecurityInfo(
            handle,
            SE_FILE_OBJECT,
            SECURITY_INFORMATION(
                UInt32(bitPattern: DACL_SECURITY_INFORMATION)
                    | UInt32(UNPROTECTED_DACL_SECURITY_INFORMATION)
            ),
            nil,
            nil,
            nil,
            nil
        )
        guard result == DWORD(ERROR_SUCCESS) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
    #endif
}
