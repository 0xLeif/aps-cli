import Foundation

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Exclusive cross-process lock for `schema.json` read-modify-write.
///
/// Lock file: `<state-root>/schema.json.lock`. Combines a process-local mutex
/// (so same-process threads serialize; plain `flock` does not) with POSIX
/// `fcntl(F_SETLKW)` for cross-process exclusion. Windows uses an exclusive
/// create/retry on `schema.json.lock.held`.
public enum SchemaFileLock {
    private static let processLock = NSLock()

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

        var lock = flock(
            l_type: Int16(F_WRLCK),
            l_whence: Int16(SEEK_SET),
            l_start: 0,
            l_len: 0,
            l_pid: 0
        )
        if fcntl(fd, F_SETLKW, &lock) == -1 {
            throw APSError.persistenceFailed(key: UserSchema.fileName)
        }
        defer {
            var unlock = flock(
                l_type: Int16(F_UNLCK),
                l_whence: Int16(SEEK_SET),
                l_start: 0,
                l_len: 0,
                l_pid: 0
            )
            _ = fcntl(fd, F_SETLK, &unlock)
        }
        return try body()
    }
    #endif

    #if os(Windows)
    private static func withWindowsLock<T>(
        stateRoot: String,
        _ body: () throws -> T
    ) throws -> T {
        let heldURL = URL(fileURLWithPath: stateRoot)
            .appendingPathComponent("schema.json.lock.held")
        let deadline = Date().addingTimeInterval(60)
        while true {
            do {
                try Data().write(to: heldURL, options: .withoutOverwriting)
                defer { try? FileManager.default.removeItem(at: heldURL) }
                return try body()
            } catch {
                if Date() >= deadline {
                    throw APSError.persistenceFailed(key: UserSchema.fileName)
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }
    #endif
}
