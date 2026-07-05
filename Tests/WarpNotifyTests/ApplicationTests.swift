import Foundation
import Testing
@testable import WarpNotify

@MainActor
@Suite("Application", .serialized)
struct ApplicationTests {
    @Test
    func commandLineMessageTakesPriorityOverStandardInput() {
        let input = StubInput(isTTY: false, text: "stdin message")
        let terminal = SpyTerminalWriter()
        let diagnostics = SpyDiagnosticWriter()
        let application = makeApplication(input: input, terminal: terminal, diagnostics: diagnostics)

        let exitCode = application.run(arguments: ["--message", "argument message", "--print"])

        #expect(exitCode == 0)
        #expect(input.readCount == 0)
        #expect(terminal.standardOutputWrites == [Data("\u{001B}]9;argument message\u{0007}".utf8)])
    }

    @Test
    func missingMessageReturnsInputErrorWhenTitleExists() {
        let input = StubInput(isTTY: true, text: "")
        let terminal = SpyTerminalWriter()
        let diagnostics = SpyDiagnosticWriter()
        let application = makeApplication(input: input, terminal: terminal, diagnostics: diagnostics)

        let exitCode = application.run(arguments: ["--title", "Build"])

        #expect(exitCode == 3)
        #expect(diagnostics.text.contains("no message"))
    }

    @Test
    func missingTitleAndMessageReturnsUsageError() {
        let input = StubInput(isTTY: false, text: "")
        let diagnostics = SpyDiagnosticWriter()
        let application = makeApplication(input: input, diagnostics: diagnostics)

        let exitCode = application.run(arguments: [])

        #expect(exitCode == 2)
        #expect(diagnostics.text.contains("Usage:"))
    }

    @Test
    func printDoesNotAttemptToOpenTTY() {
        let terminal = SpyTerminalWriter()
        let nativePresenter = SpyNativeNotificationPresenter()
        let application = makeApplication(terminal: terminal, nativePresenter: nativePresenter)

        let exitCode = application.run(arguments: ["--message", "Complete", "--print"])

        #expect(exitCode == 0)
        #expect(terminal.ttyWriteAttempts == 0)
        #expect(terminal.standardOutputWrites.count == 1)
        #expect(nativePresenter.payloads.isEmpty)
    }

    @Test
    func autoUsesNativePresenter() {
        let terminal = SpyTerminalWriter()
        let nativePresenter = SpyNativeNotificationPresenter()
        let application = makeApplication(terminal: terminal, nativePresenter: nativePresenter)

        let exitCode = application.run(arguments: ["--title", "Build", "--message", "Complete"])

        #expect(exitCode == 0)
        #expect(nativePresenter.payloads == [NotificationPayload(title: "Build", message: "Complete")])
        #expect(terminal.ttyWriteAttempts == 0)
    }

    @Test
    func warpFallsBackToStandardOutputWhenTTYIsUnavailable() {
        let terminal = SpyTerminalWriter()
        terminal.ttyAvailable = false
        let application = makeApplication(terminal: terminal)

        let exitCode = application.run(arguments: ["--backend", "warp", "--message", "Complete"])

        #expect(exitCode == 0)
        #expect(terminal.ttyWriteAttempts == 1)
        #expect(terminal.standardOutputWrites.count == 1)
    }

    @Test
    func missingWarpEnvironmentWarnsButStillWrites() {
        let terminal = SpyTerminalWriter()
        let diagnostics = SpyDiagnosticWriter()
        let application = makeApplication(
            terminal: terminal,
            diagnostics: diagnostics,
            environment: [:]
        )

        let exitCode = application.run(arguments: ["--message", "Complete", "--print"])

        #expect(exitCode == 0)
        #expect(terminal.standardOutputWrites.count == 1)
        #expect(diagnostics.writeCount == 1)
        #expect(diagnostics.text.contains("warning"))
    }

    @Test
    func quietSuppressesEnvironmentWarning() {
        let diagnostics = SpyDiagnosticWriter()
        let application = makeApplication(diagnostics: diagnostics, environment: [:])

        let exitCode = application.run(arguments: ["--message", "Complete", "--print", "--quiet"])

        #expect(exitCode == 0)
        #expect(diagnostics.writeCount == 0)
    }

    @Test
    func readsMessageFromPipedStandardInput() {
        let input = StubInput(isTTY: false, text: "Build complete\n")
        let terminal = SpyTerminalWriter()
        let application = makeApplication(input: input, terminal: terminal)

        let exitCode = application.run(arguments: ["--title", "Build", "--print"])

        #expect(exitCode == 0)
        #expect(input.readCount == 1)
        #expect(
            terminal.standardOutputWrites
                == [Data("\u{001B}]777;notify;Build;Build complete\u{0007}".utf8)]
        )
    }

    @Test
    func warpTTYWriteFailureReturnsOutputErrorWithoutStdoutFallback() {
        let terminal = SpyTerminalWriter()
        terminal.ttyWriteError = StubError.failed
        let diagnostics = SpyDiagnosticWriter()
        let application = makeApplication(terminal: terminal, diagnostics: diagnostics)

        let exitCode = application.run(arguments: ["--backend", "warp", "--message", "Complete"])

        #expect(exitCode == 4)
        #expect(terminal.standardOutputWrites.isEmpty)
        #expect(diagnostics.text.contains("output failed"))
    }

    private func makeApplication(
        input: StubInput = StubInput(isTTY: true, text: ""),
        terminal: SpyTerminalWriter = SpyTerminalWriter(),
        nativePresenter: SpyNativeNotificationPresenter = SpyNativeNotificationPresenter(),
        diagnostics: SpyDiagnosticWriter = SpyDiagnosticWriter(),
        environment: [String: String] = ["TERM_PROGRAM": "WarpTerminal"]
    ) -> WarpNotifyApplication {
        WarpNotifyApplication(
            input: input,
            terminalWriter: terminal,
            nativePresenter: nativePresenter,
            diagnosticWriter: diagnostics,
            environment: environment
        )
    }
}

@MainActor
private final class SpyNativeNotificationPresenter: NativeNotificationPresenting {
    private(set) var payloads: [NotificationPayload] = []

    func present(_ payload: NotificationPayload) throws {
        payloads.append(payload)
    }
}

private final class StubInput: InputReading {
    let isTTY: Bool
    let text: String
    private(set) var readCount = 0

    init(isTTY: Bool, text: String) {
        self.isTTY = isTTY
        self.text = text
    }

    func readToEnd() throws -> String {
        readCount += 1
        return text
    }
}

private final class SpyTerminalWriter: TerminalWriting {
    var ttyAvailable = true
    var ttyWriteError: Error?
    private(set) var ttyWriteAttempts = 0
    private(set) var standardOutputWrites: [Data] = []

    func writeToTTY(_ data: Data) throws -> Bool {
        ttyWriteAttempts += 1
        if let ttyWriteError {
            throw ttyWriteError
        }
        return ttyAvailable
    }

    func writeToStandardOutput(_ data: Data) throws {
        standardOutputWrites.append(data)
    }
}

private final class SpyDiagnosticWriter: DiagnosticWriting {
    private(set) var messages: [String] = []

    var text: String {
        messages.joined()
    }

    var writeCount: Int {
        messages.count
    }

    func writeToStandardError(_ text: String) {
        messages.append(text)
    }
}

private enum StubError: Error {
    case failed
}
