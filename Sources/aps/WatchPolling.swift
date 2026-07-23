import Foundation

/// Coordinates polling waits with signal delivery without changing the configured cadence.
internal final class WatchPollingWakeup: @unchecked Sendable {
    internal static let shared = WatchPollingWakeup()

    private let semaphore = DispatchSemaphore(value: 0)

    internal func signal() {
        semaphore.signal()
    }

    internal func wait(interval: TimeInterval) {
        let deadline = Date(timeIntervalSinceNow: max(interval, 0))

#if canImport(Darwin)
        while Date() < deadline {
            let remaining = deadline.timeIntervalSinceNow
            let slice = min(max(remaining, 0), 0.05)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: slice))
            guard semaphore.wait(timeout: .now()) != .success else { return }
        }
#else
        _ = semaphore.wait(timeout: .now() + max(interval, 0))
#endif
    }
}

/// Waits for the next polling opportunity without relying on a run-loop limit date.
///
/// Swift Foundation on some Linux distributions can block indefinitely while
/// servicing a run loop with a future limit date. Apple platforms retain a
/// short run-loop slice so main-actor work queued by the caller can execute;
/// Linux and Windows use an interruptible semaphore wait instead. Apple
/// platforms service short run-loop slices so main-actor work remains live;
/// every platform can be woken promptly by signal delivery.
internal func waitForWatchPoll(interval: TimeInterval) {
    WatchPollingWakeup.shared.wait(interval: interval)
}
