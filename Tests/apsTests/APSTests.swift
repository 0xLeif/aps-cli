import AppState
import Foundation
import XCTest
@testable import aps

final class APSTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()

        await MainActor.run {
            Application.logging(isEnabled: false)

            // Isolate FileState under a unique temp directory for this test run.
            let path = FileManager.default.temporaryDirectory
                .appendingPathComponent("aps-tests-\(UUID().uuidString)", isDirectory: true)
                .path
            FileManager.defaultFileStatePath = path
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)

            Application.reset(\.counter)
            Application.reset(\.message)
            Application.reset(storedState: \.flag)
            Application.reset(fileState: \.note)
        }
    }

    func testParseBool() {
        XCTAssertEqual(StateStore.parseBool("true"), true)
        XCTAssertEqual(StateStore.parseBool("YES"), true)
        XCTAssertEqual(StateStore.parseBool("1"), true)
        XCTAssertEqual(StateStore.parseBool("false"), false)
        XCTAssertEqual(StateStore.parseBool("off"), false)
        XCTAssertNil(StateStore.parseBool("maybe"))
    }

    func testDemoKeyMetadata() {
        XCTAssertEqual(DemoKey.counter.storage, "State")
        XCTAssertEqual(DemoKey.flag.storage, "StoredState")
        XCTAssertEqual(DemoKey.note.storage, "FileState")
        XCTAssertEqual(DemoKey.counter.valueType, "Int")
    }

    @MainActor
    func testCounterRoundTrip() async throws {
        let store = StateStore()
        try store.set(.counter, value: "7")
        XCTAssertEqual(store.get(.counter), "7")
        try store.set(.counter, value: "42")
        XCTAssertEqual(store.get(.counter), "42")
    }

    @MainActor
    func testMessageAndFlagRoundTrip() async throws {
        let store = StateStore()
        try store.set(.message, value: "hello")
        XCTAssertEqual(store.get(.message), "hello")

        try store.set(.flag, value: "true")
        XCTAssertEqual(store.get(.flag), "true")
        try store.set(.flag, value: "0")
        XCTAssertEqual(store.get(.flag), "false")
    }

    @MainActor
    func testNoteFileStateRoundTrip() async throws {
        let store = StateStore()
        try store.set(.note, value: "persisted note")
        XCTAssertEqual(store.get(.note), "persisted note")
    }

    @MainActor
    func testInvalidCounterValue() async {
        let store = StateStore()
        do {
            try store.set(.counter, value: "nope")
            XCTFail("Expected invalid value error")
        } catch let error as APSError {
            XCTAssertEqual(error, .invalidValue(key: .counter, value: "nope"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testDumpIncludesKeysAndUsesDependency() async throws {
        let store = StateStore()
        try store.set(.counter, value: "3")
        try store.set(.message, value: "hi")

        let json = try store.dump()
        XCTAssertTrue(json.contains("\"key\" : \"counter\""))
        XCTAssertTrue(json.contains("\"value\" : \"3\""))
        XCTAssertTrue(json.contains("\"key\" : \"message\""))
        XCTAssertTrue(json.contains("\"storage\" : \"FileState\""))
        XCTAssertTrue(json.contains("timestamp"))
    }

    @MainActor
    func testJSONCodingDependency() async throws {
        let coding = Application.dependency(\.jsonCoding)
        let encoded = try coding.encodePretty(["ok": true])
        XCTAssertTrue(encoded.contains("true"))
    }
}
