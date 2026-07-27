import Foundation

/// A reset operation that reached its verified postcondition.
public struct ResetOutcome: Codable, Equatable, Sendable {
    /// Name of the key whose reset postcondition was verified.
    public let key: String

    /// Creates a verified single-key reset outcome.
    /// - Parameter key: Name of the reset key
    public init(key: String) {
        self.key = key
    }
}

/// Stable details for the first failed key in a fail-fast bulk reset.
public struct ResetFailure: Codable, Equatable, Sendable {
    /// Name of the key whose reset failed.
    public let key: String
    /// Stable snake-case domain error code.
    public let code: String
    /// Stable human-readable domain error message.
    public let message: String
    /// Actionable recovery guidance.
    public let hint: String
    /// Stable sysexits-aligned process exit status.
    public let exitCode: Int32

    /// Captures stable error details for a failed key.
    /// - Parameters:
    ///   - key: Name of the failed key
    ///   - error: Domain error produced by its reset adapter
    public init(key: String, error: APSError) {
        self.key = key
        self.code = error.code
        self.message = error.description
        self.hint = error.hint
        self.exitCode = error.exitCode
    }
}

/// Explicit partial-progress result for a deterministic fail-fast bulk reset.
public struct BulkResetReport: Codable, Equatable, Sendable {
    /// Keys reset successfully before the first failure.
    public let reset: [String]
    /// First failed key, or `nil` when every selected key succeeded.
    public let failed: ResetFailure?
    /// Selected keys skipped after the first failure.
    public let notAttempted: [String]

    /// Creates an explicit fail-fast reset report.
    /// - Parameters:
    ///   - reset: Keys whose reset postconditions were verified
    ///   - failed: First failed key, if any
    ///   - notAttempted: Remaining selected keys
    public init(
        reset: [String],
        failed: ResetFailure?,
        notAttempted: [String]
    ) {
        self.reset = reset
        self.failed = failed
        self.notAttempted = notAttempted
    }

    /// A report for a bulk reset whose selected keys all reached their postcondition.
    /// - Parameter reset: Keys whose reset postconditions were verified
    /// - Returns: A successful report with no failure or unattempted keys
    public static func success(reset: [String]) -> BulkResetReport {
        BulkResetReport(reset: reset, failed: nil, notAttempted: [])
    }
}

/// Failure from a bulk reset, including the completed and unattempted keys.
public struct BulkResetError: Error, Equatable, Sendable {
    /// Partial progress and the selected keys skipped by fail-fast behavior.
    public let report: BulkResetReport
    /// Stable domain error produced by the first failed reset adapter.
    public let underlying: APSError

    /// Creates a throwable bulk reset failure.
    /// - Parameters:
    ///   - report: Partial-progress report containing the same failed key
    ///   - underlying: Domain error produced by that failed key
    public init(report: BulkResetReport, underlying: APSError) {
        self.report = report
        self.underlying = underlying
    }

    /// Stable machine-readable error code.
    public var code: String {
        underlying.code
    }

    /// Stable human-readable error description.
    public var description: String {
        underlying.description
    }

    /// Actionable recovery guidance.
    public var hint: String {
        underlying.hint
    }

    /// Stable sysexits-aligned process exit status.
    public var exitCode: Int32 {
        underlying.exitCode
    }
}
