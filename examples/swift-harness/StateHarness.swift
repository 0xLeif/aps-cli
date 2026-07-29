@preconcurrency import Foundation

internal enum HarnessError: Error, LocalizedError {
    case commandFailed(arguments: [String], status: Int32, stderr: String)

    internal var errorDescription: String? {
        switch self {
        case .commandFailed(let arguments, let status, let stderr):
            return "aps \(arguments.joined(separator: " ")) failed with \(status): \(stderr)"
        }
    }
}

@main
internal struct StateHarness {
    internal static func main() throws {
        let apsBinary = ProcessInfo.processInfo.environment["APS_BIN"] ?? "aps"
        let profile = #"{"name":"swift-harness","version":1}"#

        _ = try run(apsBinary, arguments: ["set", "profile", profile, "--json"])
        let result = try run(apsBinary, arguments: ["get", "profile", "--json"])
        FileHandle.standardOutput.write(result)
    }

    private static func run(_ apsBinary: String, arguments: [String]) throws -> Data {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [apsBinary] + arguments
        process.standardOutput = output
        process.standardError = errors

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let errorText = String(decoding: errorData, as: UTF8.self)
            throw HarnessError.commandFailed(
                arguments: arguments,
                status: process.terminationStatus,
                stderr: errorText
            )
        }
        return outputData
    }
}
