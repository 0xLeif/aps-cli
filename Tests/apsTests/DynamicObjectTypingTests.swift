import Foundation
import XCTest
@testable import aps

internal final class DynamicObjectTypingTests: XCTestCase {
    internal func testRecursiveJSONRoundTripPreservesEverySupportedKind() throws {
        let value = SchemaJSON.object([
            "array": .array([.null, .bool(true), .int(7), .double(2.5), .string("swift")]),
            "nested": .object([
                "enabled": .bool(false),
                "extra": .string("preserved"),
            ]),
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SchemaJSON.self, from: data)

        XCTAssertEqual(decoded, value)
    }

    internal func testIntegralFloatingJSONCanonicalizesWithoutChangingNumericValue() throws {
        let value = SchemaJSON.object([
            "count": .int(1),
            "ratio": .double(1.0),
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SchemaJSON.self, from: data)

        XCTAssertEqual(
            decoded,
            .object([
                "count": .int(1),
                "ratio": .int(1),
            ])
        )
    }

    internal func testNonFiniteJSONNumberCannotProduceInvalidWireJSON() {
        let value = SchemaJSON.double(.infinity)

        XCTAssertFalse(value.matches(type: "Double"))
        XCTAssertEqual(value.wireString, "null")
        XCTAssertThrowsError(try JSONEncoder().encode(value))
    }

    internal func testSchemaRejectsNonFiniteNumberInsideNestedArray() {
        let document = UserSchemaDocument(keys: [
            SchemaKeyEntry(
                name: "settings",
                type: "object",
                storage: "FileState",
                initial: .object([
                    "name": .string("agent"),
                    "nested": .array([
                        .object(["ratio": .double(.infinity)]),
                    ]),
                ]),
                path: "settings.json",
                objectShape: ["name": "String"]
            ),
        ])

        XCTAssertThrowsError(try UserSchema.validate(document))
    }

    internal func testSchemaRejectsNonFiniteNumberInOpenObjectExtension() {
        let document = UserSchemaDocument(keys: [
            SchemaKeyEntry(
                name: "settings",
                type: "object",
                storage: "FileState",
                initial: .object([
                    "name": .string("agent"),
                    "extension": .object(["ratio": .double(.nan)]),
                ]),
                path: "settings.json",
                objectShape: ["name": "String"]
            ),
        ])

        XCTAssertThrowsError(try UserSchema.validate(document))
    }

    internal func testCLIOutputPreservesArbitraryObjectAndExtraFields() throws {
        let entry = SchemaKeyEntry(
            name: "settings",
            type: "object",
            storage: "FileState",
            initial: .object([
                "name": .string(""),
                "version": .int(0),
            ]),
            path: "settings.json",
            objectShape: [
                "name": "String",
                "version": "Int",
            ]
        )
        let raw = #"{"name":"agent","version":1,"extra":{"tags":["swift",null],"ratio":1.5}}"#

        let value = try CLIOutput.typedValue(for: entry, from: raw)
        let encoded = try CLIOutput.encodeLine(value)
        let data = try XCTUnwrap(encoded.data(using: .utf8))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let extra = try XCTUnwrap(object["extra"] as? [String: Any])
        let tags = try XCTUnwrap(extra["tags"] as? [Any])

        XCTAssertEqual(object["name"] as? String, "agent")
        XCTAssertEqual(object["version"] as? Int, 1)
        XCTAssertEqual(tags.count, 2)
        XCTAssertTrue(tags[1] is NSNull)
        XCTAssertEqual(extra["ratio"] as? Double, 1.5)
    }

    internal func testSchemaRejectsInitialTypeMismatch() {
        let document = UserSchemaDocument(keys: [
            SchemaKeyEntry(
                name: "count",
                type: "Int",
                storage: "State",
                initial: .string("0")
            ),
        ])

        XCTAssertThrowsError(try UserSchema.validate(document)) { error in
            XCTAssertTrue(String(describing: error).contains("declared type"))
        }
    }

    internal func testSchemaRejectsMissingObjectShapeField() {
        let document = UserSchemaDocument(keys: [
            SchemaKeyEntry(
                name: "settings",
                type: "object",
                storage: "FileState",
                initial: .object(["name": .string("agent")]),
                path: "settings.json",
                objectShape: [
                    "name": "String",
                    "version": "Int",
                ]
            ),
        ])

        XCTAssertThrowsError(try UserSchema.validate(document)) { error in
            XCTAssertTrue(String(describing: error).contains("version"))
        }
    }

    internal func testSchemaRejectsUndeclaredSliceField() {
        let document = UserSchemaDocument(keys: [
            SchemaKeyEntry(
                name: "alias",
                type: "String",
                storage: "Slice",
                initial: .string(""),
                sliceOf: "profile",
                sliceField: "alias"
            ),
            SchemaKeyEntry(
                name: "profile",
                type: "object",
                storage: "FileState",
                initial: .object(["name": .string("")]),
                path: "profile.json",
                objectShape: ["name": "String"]
            ),
        ])

        XCTAssertThrowsError(try UserSchema.validate(document)) { error in
            XCTAssertTrue(String(describing: error).contains("must be declared"))
        }
    }

    internal func testSchemaAcceptsForwardReferencedTypedSlice() throws {
        let document = UserSchemaDocument(keys: [
            SchemaKeyEntry(
                name: "alias",
                type: "String",
                storage: "Slice",
                initial: .string(""),
                sliceOf: "profile",
                sliceField: "alias"
            ),
            SchemaKeyEntry(
                name: "profile",
                type: "object",
                storage: "FileState",
                initial: .object([
                    "alias": .string(""),
                    "metadata": .object(["tags": .array([])]),
                ]),
                path: "profile.json",
                objectShape: [
                    "alias": "String",
                    "metadata": "object",
                ]
            ),
        ])

        XCTAssertNoThrow(try UserSchema.validate(document))
    }

    @MainActor
    internal func testFileStateObjectRejectsNonObjectBeforeMutation() async throws {
        let stateRoot = try temporaryStateRoot()
        defer { try? FileManager.default.removeItem(atPath: stateRoot) }
        let entry = SchemaKeyEntry(
            name: "settings",
            type: "object",
            storage: "FileState",
            initial: .object(["name": .string("")]),
            path: "settings.json",
            objectShape: ["name": "String"]
        )
        let schema = UserSchemaDocument(keys: [entry])

        XCTAssertThrowsError(
            try DynamicKeyStorage.set(
                entry: entry,
                value: #"["not-an-object"]"#,
                stateRoot: stateRoot,
                schema: schema
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: URL(fileURLWithPath: stateRoot)
                    .appendingPathComponent("settings.json")
                    .path
            )
        )
    }

    @MainActor
    internal func testTypedSliceRoundTripUsesDeclaredJSONKind() async throws {
        let stateRoot = try temporaryStateRoot()
        defer { try? FileManager.default.removeItem(atPath: stateRoot) }
        let parent = SchemaKeyEntry(
            name: "settings",
            type: "object",
            storage: "FileState",
            initial: .object(["retries": .int(0)]),
            path: "settings.json",
            objectShape: ["retries": "Int"]
        )
        let slice = SchemaKeyEntry(
            name: "retries",
            type: "Int",
            storage: "Slice",
            initial: .int(0),
            sliceOf: "settings",
            sliceField: "retries"
        )
        let schema = UserSchemaDocument(keys: [parent, slice])
        try UserSchema.validate(schema)

        try DynamicKeyStorage.set(
            entry: slice,
            value: "4",
            stateRoot: stateRoot,
            schema: schema
        )

        XCTAssertEqual(
            try DynamicKeyStorage.get(
                entry: slice,
                stateRoot: stateRoot,
                schema: schema
            ),
            "4"
        )
    }

    private func temporaryStateRoot() throws -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("aps-object-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }
}
