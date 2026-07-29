@preconcurrency import Foundation

internal enum HarnessError: Error, LocalizedError {
    case commandFailed(arguments: [String], status: Int32, stderr: String)
    case executableNotFound(String)

    internal var errorDescription: String? {
        switch self {
        case .commandFailed(let arguments, let status, let stderr):
            return "aps \(arguments.joined(separator: " ")) failed with \(status): \(stderr)"
        case .executableNotFound(let executable):
            return "Could not resolve aps executable '\(executable)' from APS_BIN or PATH"
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

        process.executableURL = try executableURL(for: apsBinary)
        process.arguments = arguments
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

    private static func executableURL(for executable: String) throws -> URL {
        let fileManager = FileManager.default
        let environment = ProcessInfo.processInfo.environment

        #if os(Windows)
        let pathSeparator: Character = ";"
        let extensions = (environment["PATHEXT"] ?? ".EXE;.CMD;.BAT")
            .split(separator: ";")
            .map(String.init)
        #else
        let pathSeparator: Character = ":"
        let extensions = [""]
        #endif

        let executableNames = [executable] + extensions
            .filter { !$0.isEmpty }
            .map { executable + $0 }
        if executable.contains("/") || executable.contains("\\") {
            for executableName in executableNames {
                let directURL = URL(fileURLWithPath: executableName).standardizedFileURL
                if isExecutable(directURL, fileManager: fileManager) {
                    return directURL
                }
            }
            throw HarnessError.executableNotFound(executable)
        }

        let pathEntries = (environment["PATH"] ?? "")
            .split(separator: pathSeparator)
            .map(String.init)
        for pathEntry in pathEntries {
            for executableName in executableNames {
                let candidate = URL(fileURLWithPath: pathEntry)
                    .appendingPathComponent(executableName)
                if isExecutable(candidate, fileManager: fileManager) {
                    return candidate
                }
            }
        }

        throw HarnessError.executableNotFound(executable)
    }

    private static func isExecutable(_ url: URL, fileManager: FileManager) -> Bool {
        #if os(Windows)
        return fileManager.fileExists(atPath: url.path)
        #else
        return fileManager.isExecutableFile(atPath: url.path)
        #endif
    }
}
