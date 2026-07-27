import Foundation
import Crypto

/// A portable, relative path used by a schema-controlled persistent store.
///
/// Lexical validation makes the path safe to move between supported platforms.
/// Filesystem validation is intentionally repeated for every operation because
/// the state-root contents may have changed since the schema was loaded.
internal struct SchemaStoragePath: Hashable, Sendable {
    /// Instance-scoped filesystem operations used by verified deletion.
    ///
    /// Tests can inject deterministic failures without process-global mutable
    /// state. Production callers use `live`.
    internal struct DeletionOperations: Sendable {
        internal let moveItem: @Sendable (URL, URL) throws -> Void
        internal let removeItem: @Sendable (URL) throws -> Void
        internal let isAbsent: @Sendable (URL) throws -> Bool

        internal init(
            moveItem: @escaping @Sendable (URL, URL) throws -> Void = { source, destination in
                try FileManager.default.moveItem(at: source, to: destination)
            },
            removeItem: @escaping @Sendable (URL) throws -> Void,
            isAbsent: @escaping @Sendable (URL) throws -> Bool
        ) {
            self.moveItem = moveItem
            self.removeItem = removeItem
            self.isAbsent = isAbsent
        }

        internal static let live = DeletionOperations(
            moveItem: { source, destination in
                try FileManager.default.moveItem(at: source, to: destination)
            },
            removeItem: { url in
                try FileManager.default.removeItem(at: url)
            },
            isAbsent: { url in
                try SchemaStoragePath.itemKind(at: url) == nil
            }
        )
    }

    internal let rawValue: String
    internal let collisionKey: String

    private let components: [String]

    /// Validates a schema path without consulting the filesystem.
    /// - Parameter rawValue: The relative path stored in `schema.json`.
    internal init(_ rawValue: String) throws {
        try Self.validateLexically(rawValue)
        let components = rawValue.split(separator: "/", omittingEmptySubsequences: false).map(String.init)

        self.rawValue = rawValue
        self.components = components
        self.collisionKey = components
            .map(Self.portableCollisionComponent)
            .joined(separator: "/")
    }

    /// Returns true when two paths name the same portable leaf or when one
    /// would need to be a directory ancestor of the other's regular-file leaf.
    internal func collides(with other: SchemaStoragePath) -> Bool {
        collisionKey == other.collisionKey
            || collisionKey.hasPrefix("\(other.collisionKey)/")
            || other.collisionKey.hasPrefix("\(collisionKey)/")
    }

    /// Resolves the path beneath a canonical state root and validates all
    /// existing descendants. The leaf may be absent, but when present it must
    /// be a regular file.
    /// - Parameter stateRoot: The active APS state-root path.
    /// - Returns: The validated file URL.
    internal func resolve(stateRoot: String) throws -> URL {
        let root = URL(fileURLWithPath: stateRoot, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        try Self.requireDirectory(root, description: "state root")

        var candidate = root
        for (index, component) in components.enumerated() {
            candidate.appendPathComponent(component, isDirectory: false)
            let kind = try Self.itemKind(at: candidate)
            let isLeaf = index == components.count - 1

            if isLeaf {
                switch kind {
                case .none, .regularFile:
                    break
                case .directory:
                    throw Self.invalid("\(rawValue) resolves to a directory")
                case .symbolicLink:
                    throw Self.invalid("\(rawValue) resolves to a symbolic link")
                case .special:
                    throw Self.invalid("\(rawValue) resolves to a special file")
                }
            } else {
                switch kind {
                case .none:
                    break
                case .directory:
                    break
                case .symbolicLink:
                    throw Self.invalid("\(rawValue) traverses a symbolic link")
                case .regularFile, .special:
                    throw Self.invalid("\(rawValue) has a non-directory ancestor")
                }
            }
        }

        let standardizedCandidate = candidate.standardizedFileURL
        guard Self.isContained(standardizedCandidate, by: root) else {
            throw Self.invalid("\(rawValue) escapes the state root")
        }
        return standardizedCandidate
    }

    /// Removes the leaf only when it is a verified regular file.
    ///
    /// A missing leaf is a successful no-op. This method never asks
    /// `FileManager` to recursively remove a directory.
    /// - Parameters:
    ///   - stateRoot: The active APS state-root path.
    ///   - operations: The filesystem operations used for deletion and
    ///     postcondition verification.
    /// - Returns: `true` when a regular file was removed, or `false` when the
    ///   leaf was already missing.
    @discardableResult
    internal func removeRegularFileIfPresent(
        stateRoot: String,
        operations: DeletionOperations = .live
    ) throws -> Bool {
        let url = try resolve(stateRoot: stateRoot)
        guard let kind = try Self.itemKind(at: url) else { return false }
        guard kind == .regularFile else {
            throw Self.invalid("\(rawValue) is not a regular file")
        }

        let stagedURL = url
            .deletingLastPathComponent()
            .appendingPathComponent(stagedDeletionComponent())
        do {
            try operations.moveItem(url, stagedURL)
        } catch let error as CocoaError
            where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            try requireAbsent(url, operations: operations)
            return false
        } catch {
            throw APSError.persistenceFailed(key: rawValue)
        }

        do {
            try requireAbsent(url, operations: operations)
            try operations.removeItem(stagedURL)
        } catch {
            let deletionFailure = error as? APSError ?? .persistenceFailed(key: rawValue)
            do {
                try restoreStagedFile(stagedURL, to: url, operations: operations)
            } catch {
                throw APSError.rollbackFailed(
                    context: .stagedFile(path: rawValue),
                    originalErrorCode: deletionFailure.code,
                    originalErrorDescription: deletionFailure.description
                )
            }
            throw deletionFailure
        }
        return true
    }

    private func restoreStagedFile(
        _ stagedURL: URL,
        to originalURL: URL,
        operations: DeletionOperations
    ) throws {
        do {
            try operations.moveItem(stagedURL, originalURL)
        } catch {
            throw APSError.persistenceFailed(key: rawValue)
        }
    }

    private func stagedDeletionComponent() -> String {
        let digest = SHA256.hash(data: Data(collisionKey.utf8))
        let digits = Array("0123456789abcdef".utf8)
        var encoded: [UInt8] = []
        encoded.reserveCapacity(SHA256.byteCount * 2)
        for byte in digest {
            encoded.append(digits[Int(byte >> 4)])
            encoded.append(digits[Int(byte & 0x0f)])
        }
        return ".aps-delete-\(String(decoding: encoded, as: UTF8.self))-\(UUID().uuidString)"
    }

    private func requireAbsent(
        _ url: URL,
        operations: DeletionOperations
    ) throws {
        do {
            guard try operations.isAbsent(url) else {
                throw APSError.persistenceFailed(key: rawValue)
            }
        } catch let error as APSError {
            throw error
        } catch {
            throw APSError.persistenceFailed(key: rawValue)
        }
    }

    private enum ItemKind: Equatable, Sendable {
        case regularFile
        case directory
        case symbolicLink
        case special
    }

    private static func validateLexically(_ path: String) throws {
        guard !path.isEmpty else {
            throw invalid("path cannot be empty")
        }
        guard !path.hasPrefix("/"), !path.hasPrefix("//") else {
            throw invalid("\(path) must be relative")
        }
        guard !isWindowsAbsolute(path) else {
            throw invalid("\(path) must be relative")
        }
        guard !path.contains("\\") else {
            throw invalid("\(path) contains a backslash")
        }
        guard !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw invalid("\(path) contains a control character")
        }

        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        for component in pathComponents {
            guard !component.isEmpty else {
                throw invalid("\(path) contains an empty component")
            }
            guard component != ".", component != ".." else {
                throw invalid("\(path) contains a root or traversal component")
            }
            guard component.last != ".", component.last != " " else {
                throw invalid("\(path) contains a component ending in a dot or space")
            }
            guard component.rangeOfCharacter(from: CharacterSet(charactersIn: #"<>:"|?*"#)) == nil else {
                throw invalid("\(path) contains a character unavailable in portable file names")
            }
            guard !isWindowsDeviceName(component) else {
                throw invalid("\(path) contains a reserved Windows device name")
            }
        }

        let collisionKey = pathComponents
            .map(portableCollisionComponent)
            .joined(separator: "/")
        guard !isReserved(collisionKey) else {
            throw invalid("\(path) is reserved by APS")
        }
    }

    private static func isWindowsAbsolute(_ path: String) -> Bool {
        let scalars = Array(path.unicodeScalars)
        guard scalars.count >= 2 else { return false }
        let first = scalars[0]
        let isASCIILetter = (65...90).contains(first.value) || (97...122).contains(first.value)
        return isASCIILetter && scalars[1].value == 58
    }

    private static func isWindowsDeviceName(_ component: String) -> Bool {
        let stem = component.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .lowercased() ?? ""
        let fixedNames: Set<String> = ["con", "prn", "aux", "nul", "clock$"]
        if fixedNames.contains(stem) {
            return true
        }
        for prefix in ["com", "lpt"] {
            guard stem.hasPrefix(prefix) else { continue }
            let suffix = String(stem.dropFirst(prefix.count))
            if let number = Int(suffix), (1...9).contains(number) {
                return true
            }
            if ["¹", "²", "³"].contains(suffix) {
                return true
            }
        }
        return false
    }

    private static func portableCollisionComponent(_ component: String) -> String {
        component
            .folding(
                options: [.caseInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .precomposedStringWithCanonicalMapping
    }

    private static func isReserved(_ collisionKey: String) -> Bool {
        let topLevelReserved: Set<String> = [
            "schema.json",
            "secret.key",
            "secret.store.lock",
            "secret.key.lock",
        ]
        let components = collisionKey.split(separator: "/").map(String.init)
        guard let first = components.first else {
            return true
        }
        if topLevelReserved.contains(first) {
            return true
        }
        return components.contains {
            $0.hasSuffix(".lock") || $0.hasSuffix(".lock.held")
        }
    }

    private static func requireDirectory(_ url: URL, description: String) throws {
        guard let kind = try itemKind(at: url) else {
            throw invalid("\(description) does not exist")
        }
        guard kind == .directory else {
            throw invalid("\(description) is not a directory")
        }
    }

    private static func itemKind(at url: URL) throws -> ItemKind? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let type = attributes[.type] as? FileAttributeType else {
                return .special
            }
            switch type {
            case .typeRegular:
                return .regularFile
            case .typeDirectory:
                return .directory
            case .typeSymbolicLink:
                return .symbolicLink
            default:
                return .special
            }
        } catch let error as CocoaError
            where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return nil
        } catch {
            throw APSError.persistenceFailed(key: url.lastPathComponent)
        }
    }

    private static func isContained(_ candidate: URL, by root: URL) -> Bool {
        let rootComponents = root.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.count > rootComponents.count else { return false }
        return Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }

    private static func invalid(_ reason: String) -> APSError {
        APSError.schemaInvalid(reason: reason)
    }
}
