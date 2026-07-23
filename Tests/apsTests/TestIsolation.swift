import AppState
import Foundation

/// Serializes Application-touching XCTest cases under `swift test --parallel`.
///
/// AppState `Application` is a process singleton (`FileManager.defaultFileStatePath`,
/// StoredState / State / Dependency cache). Concurrent cases in one process race on
/// that singleton; acquire in `setUp` and release in `tearDown` keeps each case's
/// scope exclusive. Implemented as an actor so it is safe to await from async
/// XCTest lifecycle methods (DispatchSemaphore.wait is unavailable in async
/// contexts on newer Apple Swift toolchains).
actor TestIsolationGate {
    static let shared = TestIsolationGate()

    private var held = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if held {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                waiters.append(continuation)
            }
        }
        held = true
    }

    func release() {
        if waiters.isEmpty {
            held = false
            return
        }
        let next = waiters.removeFirst()
        next.resume()
    }
}

/// In-memory `UserDefaultsManaging` so StoredState tests never touch
/// `UserDefaults.standard` (see archived CHG-0007).
final class InMemoryUserDefaults: UserDefaultsManaging, @unchecked Sendable {
    private var storage: [String: Any] = [:]
    private let lock = NSLock()

    func object(forKey key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func set(_ value: Any?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    /// Snapshot of keys currently held (for hermetic assertions).
    var keys: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.keys)
    }
}
