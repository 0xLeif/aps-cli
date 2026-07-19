import Foundation

/// Signal handling and termination semantics for `aps watch` (issue #34).
/// The loop stops for one of three reasons (count, timeout, signal) and the
/// reason is observable in both channels: a terminal stream marker and a
/// process exit code (0 count, 124 timeout, 128+signal).

/// Thread-safe record of received signals.
final class SignalBox: @unchecked Sendable {
    private let lock = NSLock()
    private var signals: [Int32] = []

    func mark(_ signal: Int32) {
        lock.lock()
        signals.append(signal)
        lock.unlock()
    }

    var first: Int32? {
        lock.lock()
        defer { lock.unlock() }
        return signals.first
    }
}

/// Install DispatchSource handlers for SIGINT/SIGTERM on the main queue.
/// The watch loop's RunLoop draining delivers them; the box is polled by
/// `shouldContinue`. Sources must be retained for the watch's lifetime.
@discardableResult
func installWatchSignalHandlers(_ box: SignalBox) -> [DispatchSourceSignal] {
    [SIGINT, SIGTERM].map { sig in
        // Block (not SIG_IGN): an ignored disposition also suppresses kqueue
        // signal delivery on some platforms, which is how the macOS CI runner
        // silently lost SIGINT while local shells did not.
        var set = sigset_t()
        sigemptyset(&set)
        sigaddset(&set, sig)
        sigprocmask(SIG_BLOCK, &set, nil)
        let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
        source.setEventHandler {
            box.mark(sig)
        }
        source.resume()
        return source
    }
}

/// Why a bounded watch stopped.
enum StopReason: Equatable {
    case count
    case timeout
    case signal(Int32)

    /// Machine-mode reason token for the terminal stream event.
    var token: String {
        switch self {
        case .count: return "count"
        case .timeout: return "timeout"
        case .signal(let signalNumber):
            switch signalNumber {
            case SIGINT: return "sigint"
            case SIGTERM: return "sigterm"
            default: return "signal"
            }
        }
    }

    /// Process exit code: 0 on count (request satisfied), 124 on timeout
    /// (GNU convention), 128+signal for signals (130 SIGINT, 143 SIGTERM).
    var exitCode: Int32 {
        switch self {
        case .count: return 0
        case .timeout: return 124
        case .signal(let signalNumber): return 128 + signalNumber
        }
    }

    /// Human stderr line.
    var summary: String {
        switch self {
        case .count: return "count reached"
        case .timeout: return "timeout"
        case .signal(let signalNumber):
            switch signalNumber {
            case SIGINT: return "interrupted (SIGINT)"
            case SIGTERM: return "terminated (SIGTERM)"
            default: return "signal \(signalNumber)"
            }
        }
    }
}
