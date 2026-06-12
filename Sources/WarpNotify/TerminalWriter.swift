import Darwin
import Foundation

protocol TerminalWriting {
    func writeToTTY(_ data: Data) throws -> Bool
    func writeToStandardOutput(_ data: Data) throws
}

protocol DiagnosticWriting {
    func writeToStandardError(_ text: String)
}

protocol InputReading {
    var isTTY: Bool { get }
    func readToEnd() throws -> String
}

enum InputReaderError: Error, Equatable, CustomStringConvertible {
    case invalidUTF8

    var description: String {
        "stdin is not valid UTF-8"
    }
}

struct StandardInputReader: InputReading {
    var isTTY: Bool {
        Darwin.isatty(STDIN_FILENO) == 1
    }

    func readToEnd() throws -> String {
        guard let data = try FileHandle.standardInput.readToEnd() else {
            return ""
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw InputReaderError.invalidUTF8
        }
        return text
    }
}

struct FileHandleTerminalWriter: TerminalWriting {
    func writeToTTY(_ data: Data) throws -> Bool {
        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: URL(fileURLWithPath: "/dev/tty"))
        } catch {
            return false
        }

        defer {
            try? handle.close()
        }
        try handle.write(contentsOf: data)
        return true
    }

    func writeToStandardOutput(_ data: Data) throws {
        try FileHandle.standardOutput.write(contentsOf: data)
    }
}

struct StandardErrorWriter: DiagnosticWriting {
    func writeToStandardError(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            return
        }
        try? FileHandle.standardError.write(contentsOf: data)
    }
}
