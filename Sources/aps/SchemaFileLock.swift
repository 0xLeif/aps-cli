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
/// Lock file: `<state-root>/schema.json.lock`. Combines a process-local mutex
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
    private static let windowsHeldStaleAge: TimeInterval = 5 * 60

    public static func withExclusiveLock<T>(
        stateRoot: String,
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

        #if os(Windows)
        return try withWindowsLock(stateRoot: stateRoot, body)
        #else
        return try withPOSIXLock(stateRoot: stateRoot, body)
        #endif
    }

    #if !os(Windows)
    private static func withPOSIXLock<T>(
        stateRoot: String,
        _ body: () throws -> T
    ) throws -> T {
        let lockURL = URL(fileURLWithPath: stateRoot)
            .appendingPathComponent("schema.json.lock")
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
        _ body: () throws -> T
    ) throws -> T {
        let heldURL = URL(fileURLWithPath: stateRoot)
            .appendingPathComponent("schema.json.lock.held")
        let deadline = Date().addingTimeInterval(60)
        while true {
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
                if isWindowsHeldStale(at: heldURL) {
                    try? FileManager.default.removeItem(at: heldURL)
                    continue
                }
                if Date() >= deadline {
                    throw APSError.persistenceFailed(key: UserSchema.fileName)
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }

    /// True when `.held` is missing/corrupt, the writer PID is dead, or the
    /// timestamp is older than `windowsHeldStaleAge`.
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
