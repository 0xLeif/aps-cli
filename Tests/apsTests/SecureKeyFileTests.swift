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

private struct PermissionRepairFailure: Error, Sendable {}

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

    internal func testLoadRepairsOwnedRegularFileWithoutReadPermission() throws {
        #if canImport(Glibc)
        let repairablePermissions: [mode_t] = [0o000, 0o200]
        #else
        let repairablePermissions: [mode_t] = [0o200]
        #endif
        for permissions in repairablePermissions {
            let fixture = try makeFixture()
            defer { try? FileManager.default.removeItem(at: fixture.directory) }
            let expected = keyData(UInt8(permissions + 1))
            try expected.write(to: fixture.file)
            XCTAssertEqual(chmod(fixture.file.path, permissions), 0)

            XCTAssertEqual(try fixture.secureFile.load(), expected)

            var status = stat()
            XCTAssertEqual(stat(fixture.file.path, &status), 0)
            XCTAssertEqual(status.st_mode & mode_t(0o777), mode_t(0o600))
        }
    }

    #if canImport(Darwin)
    internal func testLoadFailsClosedAndRestoresMode000File() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let expected = keyData(14)
        try expected.write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o000)), 0)

        XCTAssertThrowsError(try fixture.secureFile.load())
        var status = stat()
        XCTAssertEqual(stat(fixture.file.path, &status), 0)
        XCTAssertEqual(status.st_mode & mode_t(0o777), mode_t(0o000))
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o600)), 0)
        XCTAssertEqual(try Data(contentsOf: fixture.file), expected)
    }
    #endif

    internal func testLoadRejectsPathReplacementAfterReading() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let original = keyData(15)
        let replacement = keyData(16)
        let displaced = fixture.directory.appendingPathComponent("displaced-after-read")
        try original.write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o600)), 0)
        let filePath = fixture.file.path
        let displacedPath = displaced.path
        let secureFile = SecureKeyFile(
            path: filePath,
            raceHooks: SecureKeyFileRaceHooks(
                beforeLoadPathVerification: {
                    _ = rename(filePath, displacedPath)
                    _ = FileManager.default.createFile(atPath: filePath, contents: replacement)
                    _ = chmod(filePath, mode_t(0o600))
                }
            )
        )

        XCTAssertThrowsError(try secureFile.load()) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .securityUnproven)
        }
        XCTAssertEqual(try Data(contentsOf: displaced), original)
        XCTAssertEqual(try Data(contentsOf: fixture.file), replacement)
    }

    internal func testLoadPreservesOwnedParentDirectoryPermissions() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try keyData(2).write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.directory.path, mode_t(0o755)), 0)

        XCTAssertNotNil(try fixture.secureFile.load())

        var status = stat()
        XCTAssertEqual(stat(fixture.directory.path, &status), 0)
        XCTAssertEqual(status.st_mode & mode_t(0o777), mode_t(0o755))
    }

    internal func testLoadSupportsSymlinkedOwnedParentDirectory() throws {
        let fixture = try makeFixture()
        let linkedDirectory = fixture.directory
            .deletingLastPathComponent()
            .appendingPathComponent("aps-key-link-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: linkedDirectory)
            try? FileManager.default.removeItem(at: fixture.directory)
        }
        try keyData(3).write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o600)), 0)
        try FileManager.default.createSymbolicLink(
            at: linkedDirectory,
            withDestinationURL: fixture.directory
        )
        let linkedFile = linkedDirectory.appendingPathComponent("secret.key")

        XCTAssertEqual(try SecureKeyFile(path: linkedFile.path).load(), keyData(3))
    }

    internal func testLoadRejectsWritableParentWithoutChangingIt() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let expected = keyData(4)
        try expected.write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o600)), 0)
        XCTAssertEqual(chmod(fixture.directory.path, mode_t(0o0775)), 0)

        XCTAssertThrowsError(try fixture.secureFile.load()) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .insecurePermissions)
        }

        var status = stat()
        XCTAssertEqual(stat(fixture.directory.path, &status), 0)
        XCTAssertEqual(status.st_mode & mode_t(0o777), mode_t(0o775))
        XCTAssertEqual(try Data(contentsOf: fixture.file), expected)
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

    internal func testLoadRejectsSocketAsUnsafeFileType() throws {
        #if os(Linux)
        let temporaryRoot = URL(fileURLWithPath: "/tmp", isDirectory: true)
        #else
        let temporaryRoot = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
        #endif
        let directory = temporaryRoot.appendingPathComponent("a\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let socketPath = directory.appendingPathComponent("key").path
        #if canImport(Glibc)
        let socketType = Int32(SOCK_STREAM.rawValue)
        #else
        let socketType = SOCK_STREAM
        #endif
        let descriptor = socket(AF_UNIX, socketType, 0)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        defer { _ = close(descriptor) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8CString)
        let copied = withUnsafeMutableBytes(of: &address.sun_path) { destination -> Bool in
            guard pathBytes.count <= destination.count else {
                return false
            }
            pathBytes.withUnsafeBytes { source in
                destination.copyBytes(from: source)
            }
            return true
        }
        XCTAssertTrue(copied)
        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                #if canImport(Glibc)
                Glibc.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                #else
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                #endif
            }
        }
        XCTAssertEqual(bindResult, 0)

        XCTAssertThrowsError(try SecureKeyFile(path: socketPath).load()) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .unsafeFileType)
        }
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

    internal func testUnreadableRepairRaceNeverChangesSwappedSymlinkTarget() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try keyData(9).write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o000)), 0)
        let target = fixture.directory.appendingPathComponent("permission-target")
        try Data("target".utf8).write(to: target)
        XCTAssertEqual(chmod(target.path, mode_t(0o644)), 0)
        let displaced = fixture.directory.appendingPathComponent("displaced-unreadable")
        let filePath = fixture.file.path
        let targetPath = target.path
        let displacedPath = displaced.path
        let secureFile = SecureKeyFile(
            path: filePath,
            raceHooks: SecureKeyFileRaceHooks(
                beforeUnreadableQuarantineRename: {
                    _ = rename(filePath, displacedPath)
                    _ = symlink(targetPath, filePath)
                }
            )
        )

        XCTAssertThrowsError(try secureFile.load()) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .securityUnproven)
        }
        var status = stat()
        XCTAssertEqual(stat(target.path, &status), 0)
        XCTAssertEqual(status.st_mode & mode_t(0o777), mode_t(0o644))
        XCTAssertEqual(try Data(contentsOf: target), Data("target".utf8))
    }

    internal func testUnreadableChmodNeverFollowsSwappedQuarantineSymlink() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try keyData(10).write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o000)), 0)
        let target = fixture.directory.appendingPathComponent("chmod-target")
        try Data("target".utf8).write(to: target)
        XCTAssertEqual(chmod(target.path, mode_t(0o644)), 0)
        let displaced = fixture.directory.appendingPathComponent("displaced-quarantine")
        let directory = fixture.directory
        let targetPath = target.path
        let displacedPath = displaced.path
        let secureFile = SecureKeyFile(
            path: fixture.file.path,
            raceHooks: SecureKeyFileRaceHooks(
                beforeUnreadablePermissionRepair: {
                    guard
                        let quarantine = try? FileManager.default.contentsOfDirectory(
                            at: directory,
                            includingPropertiesForKeys: nil
                        ).first(where: {
                            $0.lastPathComponent.hasPrefix(".aps-key-permission-repair-")
                        })
                    else {
                        return
                    }
                    _ = rename(quarantine.path, displacedPath)
                    _ = symlink(targetPath, quarantine.path)
                }
            )
        )

        XCTAssertThrowsError(try secureFile.load())
        var status = stat()
        XCTAssertEqual(stat(target.path, &status), 0)
        XCTAssertEqual(status.st_mode & mode_t(0o777), mode_t(0o644))
        XCTAssertEqual(try Data(contentsOf: target), Data("target".utf8))
    }

    internal func testUnreadableRepairFailureRestoresExactOriginalEntry() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let original = keyData(11)
        try original.write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o000)), 0)
        let secureFile = SecureKeyFile(
            path: fixture.file.path,
            raceHooks: SecureKeyFileRaceHooks(
                beforeUnreadablePermissionRepair: {
                    throw PermissionRepairFailure()
                }
            )
        )

        XCTAssertThrowsError(try secureFile.load()) { error in
            XCTAssertTrue(error is PermissionRepairFailure)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.file.path))
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o600)), 0)
        XCTAssertEqual(try Data(contentsOf: fixture.file), original)
        let entries = try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path)
        XCTAssertFalse(entries.contains { $0.hasPrefix(".aps-key-permission-repair-") })
    }

    internal func testUnreadableRepairNeverChmodsSwappedRegularFile() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let original = keyData(12)
        let replacement = keyData(13)
        try original.write(to: fixture.file)
        XCTAssertEqual(chmod(fixture.file.path, mode_t(0o000)), 0)
        let displaced = fixture.directory.appendingPathComponent("displaced-unreadable-regular")
        let directory = fixture.directory
        let filePath = fixture.file.path
        let displacedPath = displaced.path
        let secureFile = SecureKeyFile(
            path: filePath,
            raceHooks: SecureKeyFileRaceHooks(
                beforeUnreadablePermissionRepair: {
                    guard
                        let quarantine = try? FileManager.default.contentsOfDirectory(
                            at: directory,
                            includingPropertiesForKeys: nil
                        ).first(where: {
                            $0.lastPathComponent.hasPrefix(".aps-key-permission-repair-")
                        })
                    else {
                        return
                    }
                    _ = rename(quarantine.path, displacedPath)
                    _ = FileManager.default.createFile(atPath: quarantine.path, contents: replacement)
                    _ = chmod(quarantine.path, mode_t(0o644))
                }
            )
        )

        XCTAssertThrowsError(try secureFile.load()) { error in
            XCTAssertEqual(error as? SecureKeyFileError, .securityUnproven)
        }
        var replacementStatus = stat()
        XCTAssertEqual(stat(filePath, &replacementStatus), 0)
        XCTAssertEqual(replacementStatus.st_mode & mode_t(0o777), mode_t(0o644))
        XCTAssertEqual(try Data(contentsOf: fixture.file), replacement)
        var originalStatus = stat()
        XCTAssertEqual(stat(displacedPath, &originalStatus), 0)
        XCTAssertEqual(originalStatus.st_mode & mode_t(0o777), mode_t(0o000))
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

    internal func testWindowsLoadRepairsACLThatBlocksDataRead() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-key-repair-read-\(UUID().uuidString)")
        let expected = Data(repeating: 4, count: SecureKeyFile.expectedByteCount)
        let secureFile = SecureKeyFile(path: file.path)
        try secureFile.create(expected)
        try makeWindowsDACLRepairOnly(file)
        defer { try? FileManager.default.removeItem(at: file) }

        XCTAssertEqual(try secureFile.load(), expected)
    }

    internal func testWindowsLoadSharesExistingKeyForConcurrentReaders() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-key-concurrent-read-\(UUID().uuidString)")
        let expected = Data(repeating: 5, count: SecureKeyFile.expectedByteCount)
        let secureFile = SecureKeyFile(path: file.path)
        try secureFile.create(expected)
        defer { try? FileManager.default.removeItem(at: file) }
        let heldReadHandle = file.path.withCString(encodedAs: UTF16.self) { pathPointer in
            CreateFileW(
                pathPointer,
                DWORD(GENERIC_READ) | DWORD(READ_CONTROL),
                DWORD(FILE_SHARE_READ) | DWORD(FILE_SHARE_WRITE) | DWORD(FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_ATTRIBUTE_NORMAL),
                nil
            )
        }
        guard heldReadHandle != INVALID_HANDLE_VALUE, let heldReadHandle else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { _ = CloseHandle(heldReadHandle) }

        XCTAssertEqual(try secureFile.load(), expected)
    }

    internal func testWindowsLoadRejectsOversizedFileBeforeReading() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-key-oversized-\(UUID().uuidString)")
        let secureFile = SecureKeyFile(path: file.path)
        try secureFile.create(Data(repeating: 3, count: SecureKeyFile.expectedByteCount))
        let handle = try FileHandle(forWritingTo: file)
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: Data([3]))
        try handle.close()
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

    private func makeWindowsDACLRepairOnly(_ file: URL) throws {
        try withCurrentWindowsUserSID { userSID in
            let sidLength = GetLengthSid(userSID)
            let aclSize = MemoryLayout<ACL>.size
                + MemoryLayout<ACCESS_ALLOWED_ACE>.size
                - MemoryLayout<DWORD>.size
                + Int(sidLength)
            let aclBuffer = UnsafeMutableRawPointer.allocate(
                byteCount: aclSize,
                alignment: MemoryLayout<ACL>.alignment
            )
            defer { aclBuffer.deallocate() }
            let acl = aclBuffer.bindMemory(to: ACL.self, capacity: 1)
            guard InitializeAcl(acl, DWORD(aclSize), DWORD(ACL_REVISION)),
                  AddAccessAllowedAceEx(
                      acl,
                      DWORD(ACL_REVISION),
                      0,
                      DWORD(READ_CONTROL) | DWORD(WRITE_DAC) | DWORD(FILE_READ_ATTRIBUTES)
                          | DWORD(SYNCHRONIZE),
                      userSID
                  ) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let handle = file.path.withCString(encodedAs: UTF16.self) { pathPointer in
                CreateFileW(
                    pathPointer,
                    DWORD(READ_CONTROL) | DWORD(WRITE_DAC) | DWORD(FILE_READ_ATTRIBUTES)
                        | DWORD(SYNCHRONIZE),
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
                        | UInt32(PROTECTED_DACL_SECURITY_INFORMATION)
                ),
                nil,
                nil,
                acl,
                nil
            )
            guard result == DWORD(ERROR_SUCCESS) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
    }

    private func withCurrentWindowsUserSID<Output>(
        _ body: (PSID) throws -> Output
    ) throws -> Output {
        var token: HANDLE?
        guard OpenProcessToken(GetCurrentProcess(), DWORD(TOKEN_QUERY), &token),
              let token else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { _ = CloseHandle(token) }
        var requiredLength: DWORD = 0
        _ = GetTokenInformation(token, TokenUser, nil, 0, &requiredLength)
        guard requiredLength > 0 else {
            throw CocoaError(.fileReadUnknown)
        }
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(requiredLength),
            alignment: MemoryLayout<TOKEN_USER>.alignment
        )
        defer { buffer.deallocate() }
        guard GetTokenInformation(
            token,
            TokenUser,
            buffer,
            requiredLength,
            &requiredLength
        ) else {
            throw CocoaError(.fileReadUnknown)
        }
        let tokenUser = buffer.bindMemory(to: TOKEN_USER.self, capacity: 1)
        guard IsValidSid(tokenUser.pointee.User.Sid) else {
            throw CocoaError(.fileReadUnknown)
        }
        return try body(tokenUser.pointee.User.Sid)
    }
    #endif
}
