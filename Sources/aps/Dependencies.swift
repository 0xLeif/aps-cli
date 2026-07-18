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

/// Real JSON helpers used by dump / formatting — not a stub.
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

    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw APSError.decodingFailed
        }
        return try JSONDecoder().decode(type, from: data)
    }
}
