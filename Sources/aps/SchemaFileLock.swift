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
/// - Important: `processLock` (`NSLock`) is **non-recursive**. Callers must not
///   nest `withExclusiveLock`. Inside the body, use the UserSchema `*Unlocked`
///   load/materialize helpers instead of paths that take the lock again.
public enum SchemaFileLock {
    private static let processLock = NSLock()

    /// Maximum age of a Windows `.held` lock before it is treated as stale.
    /// CLI RMW holds are milliseconds; a short TTL also covers PID reuse when a
    /// leftover `.held` outlives its writer.
    private static let windowsHeldStaleAge: TimeInterval = 3

    public static func withExclusiveLock<T>(stateRoot: String, _ body: () throws -> T) throws -> T {
        try withExclusiveLock(stateRoot: stateRoot, lockFileName: "schema.json.lock", body)
    }

    internal static func withExclusiveLock<T>(
        stateRoot: String,
        lockFileName: String,
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
            throw APSError.persistenceFailed(key: UserSchema.fileName)
        }

        let safeLockFileName = URL(fileURLWithPath: lockFileName).lastPathComponent

        #if os(Windows)
        return try withWindowsLock(stateRoot: stateRoot, lockFileName: safeLockFileName, body)
        #else
        return try withPOSIXLock(stateRoot: stateRoot, lockFileName: safeLockFileName, body)
        #endif
    }

    #if !os(Windows)
    private static func withPOSIXLock<T>(
        stateRoot: String,
        lockFileName: String,
        _ body: () throws -> T
    ) throws -> T {
        let lockURL = URL(fileURLWithPath: stateRoot)
            .appendingPathComponent(lockFileName)
        if !FileManager.default.fileExists(atPath: lockURL.path) {
            _ = FileManager.default.createFile(atPath: lockURL.path, contents: Data())
        }
        let fd = open(lockURL.path, O_RDWR)
        guard fd >= 0 else {
            throw APSError.persistenceFailed(key: UserSchema.fileName)
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
            throw APSError.persistenceFailed(key: UserSchema.fileName)
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
        _ body: () throws -> T
    ) throws -> T {
        let heldURL = URL(fileURLWithPath: stateRoot)
            .appendingPathComponent("\(lockFileName).held")
        let deadline = Date().addingTimeInterval(60)
        while true {
            if Date() >= deadline {
                throw APSError.persistenceFailed(key: UserSchema.fileName)
            }
            do {
                let payload = HeldPayload(
                    pid: GetCurrentProcessId(),
                    ts: Date().timeIntervalSince1970
                )
                let data = try JSONEncoder().encode(payload)
                try data.write(to: heldURL, options: .withoutOverwriting)
                defer { try? FileManager.default.removeItem(at: heldURL) }
                return try body()
            } catch {
                // Only steal a held file when it exists and is stale. A missing
                // held file means the write failed for another reason; back off
                // instead of spinning forever on continue.
                if FileManager.default.fileExists(atPath: heldURL.path),
                   isWindowsHeldStale(at: heldURL) {
                    try? FileManager.default.removeItem(at: heldURL)
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }

    /// True when `.held` is missing/corrupt, the writer PID is dead or matches
    /// this process (orphaned leftover / PID reuse), or the timestamp is older
    /// than `windowsHeldStaleAge`.
    private static func isWindowsHeldStale(at url: URL) -> Bool {
        guard
            let data = try? Data(contentsOf: url),
            let payload = try? JSONDecoder().decode(HeldPayload.self, from: data)
        else {
            return true
        }
        let age = Date().timeIntervalSince1970 - payload.ts
        if age >= windowsHeldStaleAge || age < 0 {
            return true
        }
        // A held file claiming our own PID cannot be a live peer lock in this
        // single-threaded CLI; it is an orphan (often from Windows PID reuse).
        if payload.pid == GetCurrentProcessId() {
            return true
        }
        return !windowsProcessIsAlive(pid: payload.pid)
    }

    private static func windowsProcessIsAlive(pid: UInt32) -> Bool {
        guard pid > 0 else { return false }
        // PROCESS_QUERY_LIMITED_INFORMATION = 0x1000; STILL_ACTIVE = 259
        let handle = OpenProcess(0x1000, false, pid)
        guard handle != nil, handle != INVALID_HANDLE_VALUE else {
            return false
        }
        defer { _ = CloseHandle(handle) }
        var exitCode: DWORD = 0
        guard GetExitCodeProcess(handle, &exitCode) else {
            return false
        }
        return exitCode == 259
    }
    #endif
}
