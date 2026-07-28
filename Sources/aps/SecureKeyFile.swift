import Foundation

#if canImport(Glibc)
import Glibc

@_silgen_name("renameat2")
private func linuxRenameAt2(
    _ oldDirectory: Int32,
    _ oldPath: UnsafePointer<CChar>,
    _ newDirectory: Int32,
    _ newPath: UnsafePointer<CChar>,
    _ flags: UInt32
) -> Int32

// Swift's Glibc module does not expose Linux's stable O_PATH UAPI flag.
private let linuxOpenPathFlag = Int32(0o10000000)
#elseif canImport(Darwin)
import Darwin
#endif

#if os(Windows)
import WinSDK
#endif

/// Errors produced while securely accessing a key file.
internal enum SecureKeyFileError: Error, Equatable, Sendable {
    case alreadyExists
    case invalidSize(actual: Int64)
    case insecurePermissions
    case io(operation: String, code: Int32)
    case permissionRepairFailed(operation: String, code: Int32)
    case securityUnproven
    case unsafeFileType
    case wrongOwner
}

/// Test-only synchronization points for deterministic pathname race coverage.
internal struct SecureKeyFileRaceHooks: Sendable {
    internal let beforeCreatePathVerification: @Sendable () -> Void
    internal let beforeLoadPathVerification: @Sendable () -> Void
    internal let beforeUnreadableQuarantineRename: @Sendable () -> Void
    internal let beforeUnreadablePermissionRepair: @Sendable () throws -> Void

    internal init(
        beforeCreatePathVerification: @escaping @Sendable () -> Void = {},
        beforeLoadPathVerification: @escaping @Sendable () -> Void = {},
        beforeUnreadableQuarantineRename: @escaping @Sendable () -> Void = {},
        beforeUnreadablePermissionRepair: @escaping @Sendable () throws -> Void = {}
    ) {
        self.beforeCreatePathVerification = beforeCreatePathVerification
        self.beforeLoadPathVerification = beforeLoadPathVerification
        self.beforeUnreadableQuarantineRename = beforeUnreadableQuarantineRename
        self.beforeUnreadablePermissionRepair = beforeUnreadablePermissionRepair
    }

    internal static let inactive = SecureKeyFileRaceHooks()
}

/// Descriptor-based access to raw key material.
///
/// The implementation deliberately avoids path metadata prechecks. Existing
/// files are opened without following links, validated through that handle,
/// and read from the same handle.
internal struct SecureKeyFile: Sendable {
    internal static let expectedByteCount = 44
    internal let path: String
    private let raceHooks: SecureKeyFileRaceHooks

    internal init(path: String) {
        self.init(path: path, raceHooks: .inactive)
    }

    internal init(path: String, raceHooks: SecureKeyFileRaceHooks) {
        self.path = path
        self.raceHooks = raceHooks
    }

    /// Loads raw key data, or returns `nil` when the path does not exist.
    internal func load() throws -> Data? {
        #if os(Windows)
        return try loadWindows()
        #else
        return try loadPOSIX()
        #endif
    }

    /// Creates the file exclusively with owner-only access.
    internal func create(_ data: Data) throws {
        guard data.count == Self.expectedByteCount else {
            throw SecureKeyFileError.invalidSize(actual: Int64(data.count))
        }
        #if os(Windows)
        try createWindows(data)
        #else
        try createPOSIX(data)
        #endif
    }

}

#if !os(Windows)
internal extension SecureKeyFile {
    private func loadPOSIX() throws -> Data? {
        try withPOSIXParent { parentDescriptor, fileName in
            let descriptor = try openReadablePOSIX(
                parentDescriptor: parentDescriptor,
                fileName: fileName
            )
            guard descriptor >= 0 else {
                return nil
            }
            defer { _ = close(descriptor) }

            try validateAndRepairPOSIX(descriptor)
            try validateSizePOSIX(descriptor)
            let data = try readAllPOSIX(descriptor)
            raceHooks.beforeLoadPathVerification()
            try validatePathIdentityPOSIX(
                parentDescriptor: parentDescriptor,
                fileName: fileName,
                descriptor: descriptor
            )
            return data
        }
    }

    private func openReadablePOSIX(
        parentDescriptor: Int32,
        fileName: String
    ) throws -> Int32 {
        let descriptor = openat(
            parentDescriptor,
            fileName,
            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        if descriptor >= 0 {
            return descriptor
        }
        if errno == ENOENT {
            return -1
        }
        if errno == ELOOP {
            throw SecureKeyFileError.unsafeFileType
        }
        let openError = errno
        guard openError == EACCES else {
            try classifyUnopenablePOSIX(
                parentDescriptor: parentDescriptor,
                fileName: fileName,
                operation: "openat",
                code: openError
            )
        }

        return try repairAndOpenUnreadablePOSIX(
            parentDescriptor: parentDescriptor,
            fileName: fileName
        )
    }

    private func classifyUnopenablePOSIX(
        parentDescriptor: Int32,
        fileName: String,
        operation: String,
        code: Int32
    ) throws -> Never {
        var status = stat()
        if fstatat(parentDescriptor, fileName, &status, AT_SYMLINK_NOFOLLOW) == 0,
           status.st_mode & mode_t(S_IFMT) != mode_t(S_IFREG) {
            throw SecureKeyFileError.unsafeFileType
        }
        throw SecureKeyFileError.io(operation: operation, code: code)
    }

    private func repairAndOpenUnreadablePOSIX(
        parentDescriptor: Int32,
        fileName: String
    ) throws -> Int32 {
        var before = stat()
        guard fstatat(parentDescriptor, fileName, &before, AT_SYMLINK_NOFOLLOW) == 0 else {
            if errno == ELOOP {
                throw SecureKeyFileError.unsafeFileType
            }
            throw posixError(operation: "fstatat-before-permission-repair")
        }
        guard before.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw SecureKeyFileError.unsafeFileType
        }
        guard before.st_uid == geteuid() else {
            throw SecureKeyFileError.wrongOwner
        }
        let quarantineName = ".aps-key-permission-repair-\(UUID().uuidString)"
        raceHooks.beforeUnreadableQuarantineRename()
        guard noReplaceRenamePOSIX(
            parentDescriptor: parentDescriptor,
            oldName: fileName,
            newName: quarantineName
        ) == 0 else {
            throw posixError(operation: "renameat-permission-repair")
        }

        var moved = stat()
        guard fstatat(parentDescriptor, quarantineName, &moved, AT_SYMLINK_NOFOLLOW) == 0 else {
            _ = noReplaceRenamePOSIX(
                parentDescriptor: parentDescriptor,
                oldName: quarantineName,
                newName: fileName
            )
            throw posixError(operation: "fstatat-permission-repair")
        }
        guard before.st_dev == moved.st_dev,
              before.st_ino == moved.st_ino,
              moved.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              moved.st_uid == geteuid() else {
            _ = noReplaceRenamePOSIX(
                parentDescriptor: parentDescriptor,
                oldName: quarantineName,
                newName: fileName
            )
            throw SecureKeyFileError.securityUnproven
        }

        do {
            try raceHooks.beforeUnreadablePermissionRepair()
            try repairQuarantinedPermissionsPOSIX(
                parentDescriptor: parentDescriptor,
                quarantineName: quarantineName,
                expectedStatus: moved
            )
        } catch {
            _ = noReplaceRenamePOSIX(
                parentDescriptor: parentDescriptor,
                oldName: quarantineName,
                newName: fileName
            )
            throw error
        }

        let descriptor = openat(
            parentDescriptor,
            quarantineName,
            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else {
            _ = noReplaceRenamePOSIX(
                parentDescriptor: parentDescriptor,
                oldName: quarantineName,
                newName: fileName
            )
            throw posixError(operation: "openat-permission-repair")
        }
        do {
            try validateAndRepairPOSIX(descriptor)
            var opened = stat()
            guard fstat(descriptor, &opened) == 0,
                  moved.st_dev == opened.st_dev,
                  moved.st_ino == opened.st_ino else {
                throw SecureKeyFileError.securityUnproven
            }
            guard noReplaceRenamePOSIX(
                parentDescriptor: parentDescriptor,
                oldName: quarantineName,
                newName: fileName
            ) == 0 else {
                throw posixError(operation: "renameat-permission-restore")
            }
            return descriptor
        } catch {
            _ = close(descriptor)
            _ = noReplaceRenamePOSIX(
                parentDescriptor: parentDescriptor,
                oldName: quarantineName,
                newName: fileName
            )
            throw error
        }
    }

    private func repairQuarantinedPermissionsPOSIX(
        parentDescriptor: Int32,
        quarantineName: String,
        expectedStatus: stat
    ) throws {
        #if canImport(Glibc)
        let repairDescriptor = openat(
            parentDescriptor,
            quarantineName,
            linuxOpenPathFlag | O_NOFOLLOW | O_CLOEXEC
        )
        guard repairDescriptor >= 0 else {
            throw SecureKeyFileError.permissionRepairFailed(
                operation: "openat-permission-handle",
                code: errno
            )
        }
        defer { _ = close(repairDescriptor) }
        var repairStatus = stat()
        guard fstat(repairDescriptor, &repairStatus) == 0,
              expectedStatus.st_dev == repairStatus.st_dev,
              expectedStatus.st_ino == repairStatus.st_ino,
              repairStatus.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              repairStatus.st_uid == geteuid() else {
            throw SecureKeyFileError.securityUnproven
        }
        let descriptorPath = "/proc/self/fd/\(repairDescriptor)"
        while chmod(descriptorPath, mode_t(0o600)) != 0 {
            if errno == EINTR {
                continue
            }
            throw SecureKeyFileError.permissionRepairFailed(
                operation: "chmod-permission-handle",
                code: errno
            )
        }
        guard fstat(repairDescriptor, &repairStatus) == 0,
              repairStatus.st_mode & mode_t(0o7777) == mode_t(0o600) else {
            throw SecureKeyFileError.insecurePermissions
        }
        #else
        let repairDescriptor = openat(
            parentDescriptor,
            quarantineName,
            O_WRONLY | O_NOFOLLOW | O_CLOEXEC
        )
        guard repairDescriptor >= 0 else {
            throw SecureKeyFileError.permissionRepairFailed(
                operation: "openat-permission-handle",
                code: errno
            )
        }
        defer { _ = close(repairDescriptor) }
        var repairStatus = stat()
        guard fstat(repairDescriptor, &repairStatus) == 0,
              expectedStatus.st_dev == repairStatus.st_dev,
              expectedStatus.st_ino == repairStatus.st_ino,
              repairStatus.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              repairStatus.st_uid == geteuid() else {
            throw SecureKeyFileError.securityUnproven
        }
        while fchmod(repairDescriptor, mode_t(0o600)) != 0 {
            if errno == EINTR {
                continue
            }
            throw SecureKeyFileError.permissionRepairFailed(
                operation: "fchmod-permission-handle",
                code: errno
            )
        }
        guard fstat(repairDescriptor, &repairStatus) == 0,
              repairStatus.st_mode & mode_t(0o7777) == mode_t(0o600) else {
            throw SecureKeyFileError.insecurePermissions
        }
        #endif
    }

    private func createPOSIX(_ data: Data) throws {
        try withPOSIXParent { parentDescriptor, fileName in
            let descriptor = openat(
                parentDescriptor,
                fileName,
                O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
                mode_t(0o600)
            )
            guard descriptor >= 0 else {
                if errno == EEXIST {
                    throw SecureKeyFileError.alreadyExists
                }
                if errno == ELOOP {
                    throw SecureKeyFileError.unsafeFileType
                }
                throw posixError(operation: "openat-create")
            }
            defer { _ = close(descriptor) }

            do {
                try validateAndRepairPOSIX(descriptor)
                try writeAllPOSIX(data, descriptor: descriptor)
                while fsync(descriptor) != 0 {
                    if errno == EINTR {
                        continue
                    }
                    throw posixError(operation: "fsync")
                }
                try validatePOSIX(descriptor)
                try validateSizePOSIX(descriptor)
                raceHooks.beforeCreatePathVerification()
                try validatePathIdentityPOSIX(
                    parentDescriptor: parentDescriptor,
                    fileName: fileName,
                    descriptor: descriptor
                )
            } catch {
                _ = try quarantineAndRemovePOSIX(
                    parentDescriptor: parentDescriptor,
                    fileName: fileName,
                    expectedDescriptor: descriptor
                )
                throw error
            }
        }
    }

    private func withPOSIXParent<Output>(
        _ body: (Int32, String) throws -> Output
    ) throws -> Output {
        let fileName = (path as NSString).lastPathComponent
        let parentPath = (path as NSString).deletingLastPathComponent
        guard !fileName.isEmpty, fileName != ".", fileName != ".." else {
            throw SecureKeyFileError.securityUnproven
        }
        let unresolvedParentPath = parentPath.isEmpty ? "." : parentPath
        let resolvedParentPath = URL(fileURLWithPath: unresolvedParentPath)
            .resolvingSymlinksInPath()
            .path
        #if canImport(Glibc)
        let parentAccessMode = linuxOpenPathFlag
        #else
        let parentAccessMode = O_SEARCH
        #endif
        let parentDescriptor = open(
            resolvedParentPath,
            parentAccessMode | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard parentDescriptor >= 0 else {
            if errno == ELOOP || errno == ENOTDIR {
                throw SecureKeyFileError.unsafeFileType
            }
            throw posixError(operation: "open-parent")
        }
        defer { _ = close(parentDescriptor) }
        try validateParentPOSIX(parentDescriptor)
        return try body(parentDescriptor, fileName)
    }

    private func validateParentPOSIX(_ descriptor: Int32) throws {
        var status = stat()
        guard fstat(descriptor, &status) == 0 else {
            throw posixError(operation: "fstat-parent")
        }
        guard status.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else {
            throw SecureKeyFileError.unsafeFileType
        }
        guard status.st_uid == geteuid() else {
            throw SecureKeyFileError.wrongOwner
        }
        guard status.st_mode & mode_t(0o022) == 0 else {
            throw SecureKeyFileError.insecurePermissions
        }
    }

    private func validatePathIdentityPOSIX(
        parentDescriptor: Int32,
        fileName: String,
        descriptor: Int32
    ) throws {
        var descriptorStatus = stat()
        var pathStatus = stat()
        guard fstat(descriptor, &descriptorStatus) == 0,
              fstatat(parentDescriptor, fileName, &pathStatus, AT_SYMLINK_NOFOLLOW) == 0 else {
            throw posixError(operation: "fstatat-identity")
        }
        guard descriptorStatus.st_dev == pathStatus.st_dev,
              descriptorStatus.st_ino == pathStatus.st_ino,
              pathStatus.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              pathStatus.st_uid == geteuid() else {
            throw SecureKeyFileError.securityUnproven
        }
        guard descriptorStatus.st_mode & mode_t(0o7777) == mode_t(0o600),
              pathStatus.st_mode & mode_t(0o7777) == mode_t(0o600) else {
            throw SecureKeyFileError.insecurePermissions
        }
    }

    private func quarantineAndRemovePOSIX(
        parentDescriptor: Int32,
        fileName: String,
        expectedDescriptor: Int32
    ) throws -> Bool {
        let quarantineName = ".aps-key-quarantine-\(UUID().uuidString)"
        guard noReplaceRenamePOSIX(
            parentDescriptor: parentDescriptor,
            oldName: fileName,
            newName: quarantineName
        ) == 0 else {
            if errno == ENOENT {
                return false
            }
            throw posixError(operation: "renameat-quarantine")
        }

        let quarantineDescriptor = openat(
            parentDescriptor,
            quarantineName,
            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        guard quarantineDescriptor >= 0 else {
            throw posixError(operation: "openat-quarantine")
        }
        defer { _ = close(quarantineDescriptor) }

        var expectedStatus = stat()
        var quarantineStatus = stat()
        guard fstat(expectedDescriptor, &expectedStatus) == 0,
              fstat(quarantineDescriptor, &quarantineStatus) == 0 else {
            throw posixError(operation: "fstat-quarantine")
        }
        guard expectedStatus.st_dev == quarantineStatus.st_dev,
              expectedStatus.st_ino == quarantineStatus.st_ino,
              quarantineStatus.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              quarantineStatus.st_uid == geteuid() else {
            // The entry was swapped before the atomic rename. Keep it intact:
            // restore it without replacement when possible, otherwise
            // leave it quarantined. It is deliberately never unlinked.
            _ = noReplaceRenamePOSIX(
                parentDescriptor: parentDescriptor,
                oldName: quarantineName,
                newName: fileName
            )
            throw SecureKeyFileError.securityUnproven
        }
        guard unlinkat(parentDescriptor, quarantineName, 0) == 0 else {
            throw posixError(operation: "unlinkat-quarantine")
        }
        return true
    }

    private func noReplaceRenamePOSIX(
        parentDescriptor: Int32,
        oldName: String,
        newName: String
    ) -> Int32 {
        #if canImport(Glibc)
        return oldName.withCString { oldPath in
            newName.withCString { newPath in
                linuxRenameAt2(parentDescriptor, oldPath, parentDescriptor, newPath, UInt32(1))
            }
        }
        #else
        return renameatx_np(parentDescriptor, oldName, parentDescriptor, newName, UInt32(RENAME_EXCL))
        #endif
    }

    private func validateAndRepairPOSIX(_ descriptor: Int32) throws {
        var status = try validatedStatusPOSIX(descriptor)
        if status.st_mode & mode_t(0o7777) != mode_t(0o600) {
            while fchmod(descriptor, mode_t(0o600)) != 0 {
                if errno == EINTR {
                    continue
                }
                throw SecureKeyFileError.permissionRepairFailed(
                    operation: "fchmod",
                    code: errno
                )
            }
            status = try validatedStatusPOSIX(descriptor)
        }
        guard status.st_mode & mode_t(0o7777) == mode_t(0o600) else {
            throw SecureKeyFileError.insecurePermissions
        }
    }

    private func validatePOSIX(_ descriptor: Int32) throws {
        let status = try validatedStatusPOSIX(descriptor)
        guard status.st_mode & mode_t(0o7777) == mode_t(0o600) else {
            throw SecureKeyFileError.insecurePermissions
        }
    }

    private func validateSizePOSIX(_ descriptor: Int32) throws {
        var status = stat()
        guard fstat(descriptor, &status) == 0 else {
            throw posixError(operation: "fstat-size")
        }
        let actual = Int64(status.st_size)
        guard actual == Int64(Self.expectedByteCount) else {
            throw SecureKeyFileError.invalidSize(actual: actual)
        }
    }

    private func validatedStatusPOSIX(_ descriptor: Int32) throws -> stat {
        var status = stat()
        guard fstat(descriptor, &status) == 0 else {
            throw posixError(operation: "fstat")
        }
        guard status.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw SecureKeyFileError.unsafeFileType
        }
        guard status.st_uid == geteuid() else {
            throw SecureKeyFileError.wrongOwner
        }
        return status
    }

    private func readAllPOSIX(_ descriptor: Int32) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: Self.expectedByteCount)
        var total = 0
        while total < buffer.count {
            let count = buffer.withUnsafeMutableBytes { bytes in
                read(
                    descriptor,
                    bytes.baseAddress?.advanced(by: total),
                    bytes.count - total
                )
            }
            if count > 0 {
                total += Int(count)
                continue
            }
            if count == 0 {
                throw SecureKeyFileError.invalidSize(actual: Int64(total))
            }
            if errno == EINTR {
                continue
            }
            throw posixError(operation: "read")
        }

        var extra: UInt8 = 0
        while true {
            let count = read(descriptor, &extra, 1)
            if count > 0 {
                throw SecureKeyFileError.invalidSize(actual: Int64(total + Int(count)))
            }
            if count == 0 {
                return Data(buffer)
            }
            if errno == EINTR {
                continue
            }
            throw posixError(operation: "read-extra")
        }
    }

    private func writeAllPOSIX(_ data: Data, descriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return
            }
            var written = 0
            while written < bytes.count {
                let count = write(
                    descriptor,
                    baseAddress.advanced(by: written),
                    bytes.count - written
                )
                if count > 0 {
                    written += count
                    continue
                }
                if count < 0, errno == EINTR {
                    continue
                }
                throw posixError(operation: "write")
            }
        }
    }

    private func posixError(operation: String) -> SecureKeyFileError {
        SecureKeyFileError.io(operation: operation, code: errno)
    }
}
#endif

#if os(Windows)
internal extension SecureKeyFile {
    private static let fileAllAccess = DWORD(0x001F01FF)
    private static let readAccess: DWORD = DWORD(GENERIC_READ)
    private static let repairAccess = DWORD(READ_CONTROL) | DWORD(WRITE_DAC)
        | DWORD(SYNCHRONIZE)
    private static let writeAccess: DWORD = DWORD(GENERIC_WRITE)
    private static let shareNone: DWORD = 0
    private static let shareExistingReads: DWORD = DWORD(FILE_SHARE_READ)
    private static let openReparsePoint: DWORD = DWORD(FILE_FLAG_OPEN_REPARSE_POINT)
        | DWORD(FILE_FLAG_BACKUP_SEMANTICS)

    private func loadWindows() throws -> Data? {
        let repairHandle = try openWindows(
            access: Self.repairAccess,
            disposition: DWORD(OPEN_EXISTING),
            shareMode: Self.shareExistingReads,
            accessDeniedIsInsecure: true,
            operation: "CreateFileW-repair"
        )
        guard let repairHandle else {
            return nil
        }
        let expectedIdentity: WindowsFileIdentity
        do {
            try validateAndRepairWindows(repairHandle)
            expectedIdentity = try windowsIdentity(repairHandle)
        } catch {
            _ = CloseHandle(repairHandle)
            throw error
        }
        _ = CloseHandle(repairHandle)

        guard let readHandle = try openWindows(
            access: Self.readAccess | DWORD(READ_CONTROL),
            disposition: DWORD(OPEN_EXISTING),
            shareMode: Self.shareExistingReads,
            operation: "CreateFileW-read"
        ) else {
            throw SecureKeyFileError.securityUnproven
        }
        defer { _ = CloseHandle(readHandle) }
        try validateWindowsSecurity(readHandle)
        guard try windowsIdentity(readHandle) == expectedIdentity else {
            throw SecureKeyFileError.securityUnproven
        }
        try validateSizeWindows(readHandle)
        return try readAllWindows(readHandle)
    }

    private func createWindows(_ data: Data) throws {
        let handle = try withCurrentUserSID { userSID in
            try withPrivateWindowsACL(userSID: userSID) { acl in
                var securityDescriptor = SECURITY_DESCRIPTOR()
                guard InitializeSecurityDescriptor(
                    &securityDescriptor,
                    DWORD(SECURITY_DESCRIPTOR_REVISION)
                ),
                SetSecurityDescriptorOwner(&securityDescriptor, userSID, false),
                SetSecurityDescriptorDacl(&securityDescriptor, true, acl, false),
                SetSecurityDescriptorControl(
                    &securityDescriptor,
                    SECURITY_DESCRIPTOR_CONTROL(SE_DACL_PROTECTED),
                    SECURITY_DESCRIPTOR_CONTROL(SE_DACL_PROTECTED)
                ) else {
                    throw windowsError(operation: "initialize-security-descriptor")
                }

                return try withUnsafeMutablePointer(to: &securityDescriptor) { descriptorPointer in
                    var attributes = SECURITY_ATTRIBUTES()
                    attributes.nLength = DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size)
                    attributes.lpSecurityDescriptor = UnsafeMutableRawPointer(descriptorPointer)
                    attributes.bInheritHandle = false
                    return try createWindowsHandle(securityAttributes: &attributes)
                }
            }
        }
        defer { _ = CloseHandle(handle) }

        do {
            try validateAndRepairWindows(handle)
            try writeAllWindows(data, handle: handle)
            guard FlushFileBuffers(handle) else {
                throw windowsError(operation: "FlushFileBuffers")
            }
            try validateWindowsSecurity(handle)
            try validateSizeWindows(handle)
        } catch {
            removeCreatedWindows(handle)
            throw error
        }
    }

    private func openWindows(
        access: DWORD,
        disposition: DWORD,
        shareMode: DWORD,
        accessDeniedIsInsecure: Bool = false,
        operation: String
    ) throws -> HANDLE? {
        let handle = path.withCString(encodedAs: UTF16.self) { pathPointer in
            CreateFileW(
                pathPointer,
                access,
                shareMode,
                nil,
                disposition,
                Self.openReparsePoint,
                nil
            )
        }
        guard handle != INVALID_HANDLE_VALUE else {
            let code = GetLastError()
            if code == DWORD(ERROR_FILE_NOT_FOUND) || code == DWORD(ERROR_PATH_NOT_FOUND) {
                return nil
            }
            if code == DWORD(ERROR_FILE_EXISTS) || code == DWORD(ERROR_ALREADY_EXISTS) {
                throw SecureKeyFileError.alreadyExists
            }
            if code == DWORD(ERROR_ACCESS_DENIED), accessDeniedIsInsecure {
                throw SecureKeyFileError.insecurePermissions
            }
            throw SecureKeyFileError.io(operation: operation, code: Int32(bitPattern: code))
        }
        return handle
    }

    private func windowsIdentity(_ handle: HANDLE) throws -> WindowsFileIdentity {
        var information = BY_HANDLE_FILE_INFORMATION()
        guard GetFileInformationByHandle(handle, &information) else {
            throw windowsError(operation: "GetFileInformationByHandle-identity")
        }
        return WindowsFileIdentity(
            volumeSerialNumber: information.dwVolumeSerialNumber,
            fileIndexHigh: information.nFileIndexHigh,
            fileIndexLow: information.nFileIndexLow
        )
    }

    private struct WindowsFileIdentity: Equatable, Sendable {
        private let volumeSerialNumber: DWORD
        private let fileIndexHigh: DWORD
        private let fileIndexLow: DWORD

        fileprivate init(
            volumeSerialNumber: DWORD,
            fileIndexHigh: DWORD,
            fileIndexLow: DWORD
        ) {
            self.volumeSerialNumber = volumeSerialNumber
            self.fileIndexHigh = fileIndexHigh
            self.fileIndexLow = fileIndexLow
        }
    }

    private func createWindowsHandle(
        securityAttributes: UnsafeMutablePointer<SECURITY_ATTRIBUTES>
    ) throws -> HANDLE {
        let handle = path.withCString(encodedAs: UTF16.self) { pathPointer in
            CreateFileW(
                pathPointer,
                Self.readAccess | Self.writeAccess | DWORD(READ_CONTROL)
                    | DWORD(WRITE_DAC) | DWORD(DELETE),
                Self.shareNone,
                securityAttributes,
                DWORD(CREATE_NEW),
                DWORD(FILE_ATTRIBUTE_NORMAL) | Self.openReparsePoint,
                nil
            )
        }
        guard handle != INVALID_HANDLE_VALUE else {
            let code = GetLastError()
            if code == DWORD(ERROR_FILE_EXISTS) || code == DWORD(ERROR_ALREADY_EXISTS) {
                throw SecureKeyFileError.alreadyExists
            }
            throw SecureKeyFileError.io(operation: "CreateFileW-create", code: Int32(bitPattern: code))
        }
        guard let handle else {
            throw SecureKeyFileError.securityUnproven
        }
        return handle
    }

    private func validateAndRepairWindows(_ handle: HANDLE) throws {
        guard GetFileType(handle) == DWORD(FILE_TYPE_DISK) else {
            throw SecureKeyFileError.unsafeFileType
        }
        var information = BY_HANDLE_FILE_INFORMATION()
        guard GetFileInformationByHandle(handle, &information) else {
            throw windowsError(operation: "GetFileInformationByHandle")
        }
        guard information.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) == 0,
              information.dwFileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) == 0 else {
            throw SecureKeyFileError.unsafeFileType
        }

        let isPrivate = try inspectWindowsSecurity(handle)
        if !isPrivate {
            try withCurrentUserSID { userSID in
                try withPrivateWindowsACL(userSID: userSID) { acl in
                    let result = SetSecurityInfo(
                        handle,
                        SE_FILE_OBJECT,
                        SECURITY_INFORMATION(
                            UInt32(DACL_SECURITY_INFORMATION)
                                | PROTECTED_DACL_SECURITY_INFORMATION
                        ),
                        nil,
                        nil,
                        acl,
                        nil
                    )
                    guard result == DWORD(ERROR_SUCCESS) else {
                        throw SecureKeyFileError.permissionRepairFailed(
                            operation: "SetSecurityInfo",
                            code: Int32(bitPattern: result)
                        )
                    }
                }
            }
        }
        try validateWindowsSecurity(handle)
    }

    private func validateWindowsSecurity(_ handle: HANDLE) throws {
        guard try inspectWindowsSecurity(handle) else {
            throw SecureKeyFileError.insecurePermissions
        }
    }

    private func inspectWindowsSecurity(_ handle: HANDLE) throws -> Bool {
        try withCurrentUserSID { userSID in
            var owner: PSID?
            var dacl: PACL?
            var securityDescriptor: PSECURITY_DESCRIPTOR?
            let result = GetSecurityInfo(
                handle,
                SE_FILE_OBJECT,
                SECURITY_INFORMATION(
                    UInt32(bitPattern: OWNER_SECURITY_INFORMATION)
                        | UInt32(bitPattern: DACL_SECURITY_INFORMATION)
                ),
                &owner,
                nil,
                &dacl,
                nil,
                &securityDescriptor
            )
            defer {
                if let securityDescriptor {
                    _ = LocalFree(securityDescriptor)
                }
            }
            guard result == DWORD(ERROR_SUCCESS) else {
                throw SecureKeyFileError.io(
                    operation: "GetSecurityInfo",
                    code: Int32(bitPattern: result)
                )
            }
            guard let owner, let securityDescriptor else {
                throw SecureKeyFileError.securityUnproven
            }
            guard EqualSid(owner, userSID) else {
                throw SecureKeyFileError.wrongOwner
            }
            var control = SECURITY_DESCRIPTOR_CONTROL()
            var revision: DWORD = 0
            guard GetSecurityDescriptorControl(
                securityDescriptor,
                &control,
                &revision
            ) else {
                throw windowsError(operation: "GetSecurityDescriptorControl")
            }
            guard control & SECURITY_DESCRIPTOR_CONTROL(SE_DACL_PROTECTED) != 0 else {
                return false
            }
            guard let dacl, dacl.pointee.AceCount == 1 else {
                return false
            }

            var rawACE: UnsafeMutableRawPointer?
            guard GetAce(dacl, 0, &rawACE), let rawACE else {
                throw SecureKeyFileError.securityUnproven
            }
            let header = rawACE.assumingMemoryBound(to: ACE_HEADER.self)
            guard header.pointee.AceType == ACCESS_ALLOWED_ACE_TYPE,
                  header.pointee.AceFlags == 0 else {
                return false
            }
            let allowedACE = rawACE.assumingMemoryBound(to: ACCESS_ALLOWED_ACE.self)
            guard let sidOffset = MemoryLayout<ACCESS_ALLOWED_ACE>.offset(of: \.SidStart) else {
                throw SecureKeyFileError.securityUnproven
            }
            let aceSID = PSID(rawACE.advanced(by: sidOffset))
            guard EqualSid(aceSID, userSID) else {
                return false
            }
            let requiredAccess = Self.fileAllAccess
            return allowedACE.pointee.Mask & requiredAccess == requiredAccess
        }
    }

    private func withCurrentUserSID<Output>(
        _ body: (PSID) throws -> Output
    ) throws -> Output {
        var token: HANDLE?
        guard OpenProcessToken(GetCurrentProcess(), DWORD(TOKEN_QUERY), &token),
              let token else {
            throw SecureKeyFileError.securityUnproven
        }
        defer { _ = CloseHandle(token) }

        var requiredLength: DWORD = 0
        _ = GetTokenInformation(token, TokenUser, nil, 0, &requiredLength)
        guard requiredLength > 0 else {
            throw SecureKeyFileError.securityUnproven
        }
        let tokenBuffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(requiredLength),
            alignment: MemoryLayout<TOKEN_USER>.alignment
        )
        defer { tokenBuffer.deallocate() }
        guard GetTokenInformation(
            token,
            TokenUser,
            tokenBuffer,
            requiredLength,
            &requiredLength
        ) else {
            throw SecureKeyFileError.securityUnproven
        }
        let tokenUser = tokenBuffer.bindMemory(to: TOKEN_USER.self, capacity: 1)
        guard IsValidSid(tokenUser.pointee.User.Sid) else {
            throw SecureKeyFileError.securityUnproven
        }
        return try body(tokenUser.pointee.User.Sid)
    }

    private func withPrivateWindowsACL<Output>(
        userSID: PSID,
        _ body: (PACL) throws -> Output
    ) throws -> Output {
        let sidLength = GetLengthSid(userSID)
        guard sidLength > 0 else {
            throw SecureKeyFileError.securityUnproven
        }
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
                  Self.fileAllAccess,
                  userSID
              ) else {
            throw windowsError(operation: "initialize-private-acl")
        }
        return try body(acl)
    }

    private func readAllWindows(_ handle: HANDLE) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: Self.expectedByteCount)
        var total = 0
        while total < buffer.count {
            var count: DWORD = 0
            let succeeded = buffer.withUnsafeMutableBytes { bytes in
                ReadFile(
                    handle,
                    bytes.baseAddress?.advanced(by: total),
                    DWORD(bytes.count - total),
                    &count,
                    nil
                )
            }
            guard succeeded else {
                throw windowsError(operation: "ReadFile")
            }
            guard count > 0 else {
                throw SecureKeyFileError.invalidSize(actual: Int64(total))
            }
            total += Int(count)
        }

        var extra: UInt8 = 0
        var extraCount: DWORD = 0
        guard ReadFile(handle, &extra, 1, &extraCount, nil) else {
            throw windowsError(operation: "ReadFile-extra")
        }
        guard extraCount == 0 else {
            throw SecureKeyFileError.invalidSize(actual: Int64(total + Int(extraCount)))
        }
        return Data(buffer)
    }

    private func validateSizeWindows(_ handle: HANDLE) throws {
        var size = LARGE_INTEGER()
        guard GetFileSizeEx(handle, &size) else {
            throw windowsError(operation: "GetFileSizeEx")
        }
        let actual = Int64(size.QuadPart)
        guard actual == Int64(Self.expectedByteCount) else {
            throw SecureKeyFileError.invalidSize(actual: actual)
        }
    }

    private func writeAllWindows(_ data: Data, handle: HANDLE) throws {
        try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return
            }
            var written = 0
            while written < bytes.count {
                let remaining = bytes.count - written
                let request = DWORD(min(remaining, Int(DWORD.max)))
                var count: DWORD = 0
                guard WriteFile(
                    handle,
                    baseAddress.advanced(by: written),
                    request,
                    &count,
                    nil
                ),
                count > 0 else {
                    throw windowsError(operation: "WriteFile")
                }
                written += Int(count)
            }
        }
    }

    private func removeCreatedWindows(_ handle: HANDLE) {
        var information = BY_HANDLE_FILE_INFORMATION()
        guard GetFileType(handle) == DWORD(FILE_TYPE_DISK),
              GetFileInformationByHandle(handle, &information),
              information.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) == 0,
              information.dwFileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) == 0 else {
            return
        }
        var disposition = FILE_DISPOSITION_INFO()
        withUnsafeMutableBytes(of: &disposition) { bytes in
            bytes[0] = 1
        }
        _ = SetFileInformationByHandle(
            handle,
            FileDispositionInfo,
            &disposition,
            DWORD(MemoryLayout<FILE_DISPOSITION_INFO>.size)
        )
    }

    private func windowsError(operation: String) -> SecureKeyFileError {
        SecureKeyFileError.io(operation: operation, code: Int32(bitPattern: GetLastError()))
    }
}
#endif
