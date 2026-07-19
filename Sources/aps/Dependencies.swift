#if canImport(Combine)
import Combine
#endif
import Foundation

/// Clock abstraction injected through AppState.
public protocol APSClock: Sendable {
    var now: Date { get }
}

/// Production clock backed by `Date()`.
public struct SystemAPSClock: APSClock {
    public init() {}

    public var now: Date { Date() }
}

/// Real JSON helpers used by dump / formatting: not a stub.
public struct JSONCoding: Sendable {
    public init() {}

    public func encodePretty<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw APSError.encodingFailed
        }
        return string
    }

    /// TTY-aware JSON (gh rule): pretty when interactive, compact when piped.
    public func encodeAuto<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        if TTY.stdoutIsTTY {
            formatting.insert(.prettyPrinted)
        }
        encoder.outputFormatting = formatting
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw APSError.encodingFailed
        }
        return string
    }
}

/// Process-local mutation counters dogfooded through `@ObservedDependency`.
///
/// Conforms to `ObservableObject` so AppState's observable dependency surface can
/// publish changes that CLI watch (and tests) subscribe to via Combine.
#if canImport(Combine)
@MainActor
public final class DemoStats: ObservableObject, Sendable {
    @Published public private(set) var mutationCount: Int
    @Published public private(set) var lastMutatedKey: String

    public init() {
        self.mutationCount = 0
        self.lastMutatedKey = ""
    }

    /// Records a successful demo-key mutation (set or reset).
    public func recordMutation(key: String) {
        mutationCount += 1
        lastMutatedKey = key
    }

    /// Clears counters back to their initial values.
    public func reset() {
        mutationCount = 0
        lastMutatedKey = ""
    }
}
#else
@MainActor
public final class DemoStats: Sendable {
    public private(set) var mutationCount: Int
    public private(set) var lastMutatedKey: String

    public init() {
        self.mutationCount = 0
        self.lastMutatedKey = ""
    }

    /// Records a successful demo-key mutation (set or reset).
    public func recordMutation(key: String) {
        mutationCount += 1
        lastMutatedKey = key
    }

    /// Clears counters back to their initial values.
    public func reset() {
        mutationCount = 0
        lastMutatedKey = ""
    }
}
#endif

/// Immutable view of `DemoStats` for CLI output and watch events.
public struct DemoStatsSnapshot: Equatable, Sendable, Encodable {
    public let mutationCount: Int
    public let lastMutatedKey: String

    public init(mutationCount: Int, lastMutatedKey: String) {
        self.mutationCount = mutationCount
        self.lastMutatedKey = lastMutatedKey
    }
}
