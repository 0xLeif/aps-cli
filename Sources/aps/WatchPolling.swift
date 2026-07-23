import Foundation

/// Waits for the next polling opportunity without relying on a run-loop limit date.
///
/// Swift Foundation on some Linux distributions can block indefinitely while
/// servicing a run loop with a future limit date. A thread sleep is portable and
/// still gives the caller a bounded opportunity to observe cancellation.
internal func waitForWatchPoll(interval: TimeInterval) {
    Thread.sleep(forTimeInterval: interval)
}
