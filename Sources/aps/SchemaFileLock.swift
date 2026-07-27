import Foundation

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

#if os(Windows)
import WinSDK
#endif

/// Exclusive cross-process lock for `schema.json` read-modify-write.
///
/// Lock file: `<state-root>/<lockFileName>`. Combines a process-local mutex
/// (so same-process threads serialize; plain `flock` does not) with POSIX
/// `fcntl(F_SETLKW)` for cross-process exclusion. Windows uses an exclusive
/// create/retry on `schema.json.lock.held`, with PID+timestamp stale recovery.
///
/// Schema and storage locks use separate process-local mutexes so the supported
/// schema-then-storage ordering does not recursively acquire one `NSLock`.
/// Inside a schema body, use the UserSchema `*Unlocked` load/materialize helpers
/// instead of taking the schema lock again.
public enum SchemaFileLock {
    internal enum WindowsLockOwnerState: Sendable {
        case alive
        case dead
        case unknown
    }

    private static let schemaProcessLock = NSLock()
    private static let storageProcessLock = NSLock()

    /// Maximum age before an unparseable Windows lock is treated as stale.
    private static let windowsHeldStaleAge: TimeInterval = 3

    public static func withExclusiveLock<T>(stateRoot: String, _ body: () throws -> T) throws -> T {
        try withExclusiveLock(
            processLock: schemaProcessLock,
            stateRoot: stateRoot,
            lockFileName: "schema.json.lock",
            resourceKey: UserSchema.fileName,
            body
        )
    }

    internal static func withExclusiveStorageLock<T>(
        stateRoot: String,
        lockFileName: String,
        resourceKey: String,
        _ body: () throws -> T
    ) throws -> T {
        try withExclusiveLock(
            processLock: storageProcessLock,
            stateRoot: stateRoot,
            lockFileName: lockFileName,
            resourceKey: resourceKey,
            body
        )
    }

    private static func withExclusiveLock<T>(
        processLock: NSLock,
        stateRoot: String,
        lockFileName: String,
        resourceKey: String,
        _ body: () throws -> T
    ) throws -> T {
        processLock.lock()
        defer { processLock.unlock() }

        let rootURL = URL(fileURLWithPath: stateRoot)
        do {
            try FileManager.default.createDirectory(
                at: rootURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw APSError.persistenceFailed(key: resourceKey)
        }

        let safeLockFileName = URL(fileURLWithPath: lockFileName).lastPathComponent

        #if os(Windows)
        return try withWindowsLock(
            stateRoot: stateRoot,
            lockFileName: safeLockFileName,
            resourceKey: resourceKey,
            body
        )
        #else
        return try withPOSIXLock(
            stateRoot: stateRoot,
            lockFileName: safeLockFileName,
            resourceKey: resourceKey,
            body
        )
        #endif
    }

    #if !os(Windows)
    private static func withPOSIXLock<T>(
        stateRoot: String,
        lockFileName: String,
        resourceKey: String,
        _ body: () throws -> T
    ) throws -> T {
        let lockURL = URL(fileURLWithPath: stateRoot)
            .appendingPathComponent(lockFileName)
        if !FileManager.default.fileExists(atPath: lockURL.path) {
            _ = FileManager.default.createFile(atPath: lockURL.path, contents: Data())
        }
        let fd = open(lockURL.path, O_RDWR)
        guard fd >= 0 else {
            throw APSError.persistenceFailed(key: resourceKey)
        }
        defer { close(fd) }

        // Assign fields (do not use flock(...) memberwise init): Darwin and
        // Glibc disagree on argument label order.
        var lock = flock()
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)
        lock.l_start = 0
        lock.l_len = 0
        lock.l_pid = 0

        while fcntl(fd, F_SETLKW, &lock) == -1 {
            if errno == EINTR {
                continue
            }
            throw APSError.persistenceFailed(key: resourceKey)
        }
        defer {
            var unlock = flock()
            unlock.l_type = Int16(F_UNLCK)
            unlock.l_whence = Int16(SEEK_SET)
            unlock.l_start = 0
            unlock.l_len = 0
            unlock.l_pid = 0
            while fcntl(fd, F_SETLK, &unlock) == -1, errno == EINTR {
                continue
            }
        }
        return try body()
    }
    #endif

    #if os(Windows)
    private struct HeldPayload: Codable {
        let pid: UInt32
        let ts: TimeInterval
    }

    private static func withWindowsLock<T>(
        stateRoot: String,
        lockFileName: String,
        resourceKey: String,
        _ body: () throws -> T
    ) throws -> T {
        let heldURL = URL(fileURLWithPath: stateRoot)
            .appendingPathComponent("\(lockFileName).held")
        let deadline = Date().addingTimeInterval(60)
        while true {
            if Date() >= deadline {
                throw APSError.persistenceFailed(key: resourceKey)
            }
            let payload = HeldPayload(
                pid: GetCurrentProcessId(),
                ts: Date().timeIntervalSince1970
            )
            let data: Data
            do {
                data = try JSONEncoder().encode(payload)
                try data.write(to: heldURL, options: .withoutOverwriting)
            } catch {
                // Only steal a held file when it exists and is stale. A missing
                // held file means the write failed for another reason; back off
                // instead of spinning forever on continue.
                if FileManager.default.fileExists(atPath: heldURL.path),
                   isWindowsHeldStale(at: heldURL) {
                    try? FileManager.default.removeItem(at: heldURL)
                }
                Thread.sleep(forTimeInterval: 0.05)
                continue
            }
            defer { try? FileManager.default.removeItem(at: heldURL) }
            return try body()
        }
    }

    /// True when `.held` is safely reclaimable.
    ///
    /// A demonstrably live peer owns its lock regardless of age. Dead owners
    /// can be reclaimed immediately. An indeterminate valid owner fails closed;
    /// only a corrupt payload is reclaimed after its file lease expires.
    private static func isWindowsHeldStale(at url: URL) -> Bool {
        let fileTimestamp = (
            try? url.resourceValues(forKeys: [.contentModificationDateKey])
        )?.contentModificationDate?.timeIntervalSince1970
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(HeldPayload.self, from: data) else {
            return windowsHeldIsStale(
                ownerPID: nil,
                fileTimestamp: fileTimestamp,
                now: Date().timeIntervalSince1970,
                currentPID: GetCurrentProcessId(),
                ownerState: .unknown
            )
        }

        let currentPID = GetCurrentProcessId()
        let ownerState = payload.pid == currentPID
            ? WindowsLockOwnerState.unknown
            : windowsProcessState(pid: payload.pid)
        return windowsHeldIsStale(
            ownerPID: payload.pid,
            fileTimestamp: fileTimestamp,
            now: Date().timeIntervalSince1970,
            currentPID: currentPID,
            ownerState: ownerState
        )
    }

    private static func windowsProcessState(pid: UInt32) -> WindowsLockOwnerState {
        guard pid > 0 else { return .dead }
        // PROCESS_QUERY_LIMITED_INFORMATION = 0x1000; STILL_ACTIVE = 259
        let handle = OpenProcess(0x1000, false, pid)
        guard handle != nil, handle != INVALID_HANDLE_VALUE else {
            // ERROR_INVALID_PARAMETER means the PID does not identify a
            // running process. Access failures are indeterminate, not proof
            // that a live owner is gone.
            return GetLastError() == 87 ? .dead : .unknown
        }
        defer { _ = CloseHandle(handle) }
        var exitCode: DWORD = 0
        guard GetExitCodeProcess(handle, &exitCode) else {
            return .unknown
        }
        return exitCode == 259 ? .alive : .dead
    }
    #endif

    internal static func windowsHeldIsStale(
        ownerPID: UInt32?,
        fileTimestamp: TimeInterval?,
        now: TimeInterval,
        currentPID: UInt32,
        ownerState: WindowsLockOwnerState
    ) -> Bool {
        if ownerPID == currentPID {
            // The process-local mutex guarantees that this process has no live
            // peer acquisition. A matching PID is an orphan or PID reuse.
            return true
        }
        switch ownerState {
        case .alive:
            return false
        case .dead:
            return ownerPID != nil
        case .unknown:
            guard ownerPID == nil else {
                return false
            }
            return windowsLeaseExpired(
                fileTimestamp: fileTimestamp,
                now: now
            )
        }
    }

    private static func windowsLeaseExpired(
        fileTimestamp: TimeInterval?,
        now: TimeInterval
    ) -> Bool {
        guard let fileTimestamp, fileTimestamp.isFinite else {
            return false
        }
        let age = now - fileTimestamp
        return age >= windowsHeldStaleAge
    }
}
