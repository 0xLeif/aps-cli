import Foundation

/// Waits for the next polling opportunity without relying on a run-loop limit date.
///
/// Swift Foundation on some Linux distributions can block indefinitely while
/// servicing a run loop with a future limit date. Apple platforms retain a
/// short run-loop slice so main-actor work queued by the caller can execute;
/// Linux and Windows use a thread sleep instead. Every platform caps the wait
/// so background signal delivery is observed promptly for large intervals.
internal func waitForWatchPoll(interval: TimeInterval) {
    let maximumInterval = 0.05
    let boundedInterval = min(max(interval, 0), maximumInterval)

#if canImport(Darwin)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: boundedInterval))
#else
    Thread.sleep(forTimeInterval: boundedInterval)
#endif
}
