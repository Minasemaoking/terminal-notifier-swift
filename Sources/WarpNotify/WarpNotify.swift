import Darwin
import Foundation

enum WarpNotifyExitCode: Int32 {
    case success = 0
    case usageError = 2
    case inputError = 3
    case outputError = 4
}

struct WarpEnvironment: Equatable {
    let termProgram: String?
    let termProgramVersion: String?
    let isLocalShellSession: String?

    init(environment: [String: String]) {
        termProgram = environment["TERM_PROGRAM"]
        termProgramVersion = environment["TERM_PROGRAM_VERSION"]
        isLocalShellSession = environment["WARP_IS_LOCAL_SHELL_SESSION"]
    }

    var looksLikeWarp: Bool {
        let programSuggestsWarp = termProgram?.localizedCaseInsensitiveContains("warp") == true
        let hasWarpSessionHint = isLocalShellSession?.isEmpty == false
        return programSuggestsWarp || hasWarpSessionHint
    }
}

@MainActor
struct WarpNotifyApplication {
    let input: any InputReading
    let terminalWriter: any TerminalWriting
    let nativePresenter: any NativeNotificationPresenting
    let diagnosticWriter: any DiagnosticWriting
    let environment: [String: String]

    func run(arguments: [String]) -> Int32 {
        let options: CLIOptions
        do {
            options = try CLIOptionsParser.parse(arguments)
        } catch {
            diagnosticWriter.writeToStandardError("warp-notify: \(error)\n")
            diagnosticWriter.writeToStandardError(CLIText.usage)
            return WarpNotifyExitCode.usageError.rawValue
        }

        if options.showHelp {
            return writeTextToStandardOutput(CLIText.usage)
        }
        if options.showVersion {
            return writeTextToStandardOutput(CLIText.version)
        }

        let rawMessage: String?
        if let message = options.message {
            rawMessage = message
        } else if !input.isTTY {
            do {
                rawMessage = try input.readToEnd()
            } catch {
                diagnosticWriter.writeToStandardError("warp-notify: \(error)\n")
                return WarpNotifyExitCode.inputError.rawValue
            }
        } else {
            rawMessage = nil
        }

        let hasMessageInput = options.message != nil || rawMessage?.isEmpty == false
        if options.title == nil, !hasMessageInput {
            diagnosticWriter.writeToStandardError(CLIText.usage)
            return WarpNotifyExitCode.usageError.rawValue
        }

        guard let rawMessage else {
            diagnosticWriter.writeToStandardError("warp-notify: no message was provided\n")
            return WarpNotifyExitCode.inputError.rawValue
        }

        let payload = NotificationPayload(title: options.title, message: rawMessage)
        guard !payload.message.isEmpty else {
            diagnosticWriter.writeToStandardError("warp-notify: message is empty after normalization\n")
            return WarpNotifyExitCode.inputError.rawValue
        }

        let usesWarpOutput = options.printOnly || options.backend == .warp
        if usesWarpOutput, !options.quiet, !WarpEnvironment(environment: environment).looksLikeWarp {
            diagnosticWriter.writeToStandardError(
                "warp-notify: warning: terminal does not appear to be Warp; sending OSC notification anyway\n"
            )
        }

        do {
            if options.printOnly {
                let data = try OSCNotificationEncoder.encode(payload)
                try terminalWriter.writeToStandardOutput(data)
            } else {
                switch options.backend {
                case .auto, .native:
                    try nativePresenter.present(payload)
                case .warp:
                    let data = try OSCNotificationEncoder.encode(payload)
                    if try !terminalWriter.writeToTTY(data) {
                        try terminalWriter.writeToStandardOutput(data)
                    }
                }
            }
            return WarpNotifyExitCode.success.rawValue
        } catch {
            diagnosticWriter.writeToStandardError("warp-notify: output failed: \(error)\n")
            return WarpNotifyExitCode.outputError.rawValue
        }
    }

    private func writeTextToStandardOutput(_ text: String) -> Int32 {
        guard let data = text.data(using: .utf8) else {
            diagnosticWriter.writeToStandardError("warp-notify: output text is not valid UTF-8\n")
            return WarpNotifyExitCode.outputError.rawValue
        }

        do {
            try terminalWriter.writeToStandardOutput(data)
            return WarpNotifyExitCode.success.rawValue
        } catch {
            diagnosticWriter.writeToStandardError("warp-notify: output failed: \(error)\n")
            return WarpNotifyExitCode.outputError.rawValue
        }
    }
}

@main
enum WarpNotifyCommand {
    @MainActor
    static func main() {
        let application = WarpNotifyApplication(
            input: StandardInputReader(),
            terminalWriter: FileHandleTerminalWriter(),
            nativePresenter: AppKitNotificationPresenter(),
            diagnosticWriter: StandardErrorWriter(),
            environment: ProcessInfo.processInfo.environment
        )
        Darwin.exit(application.run(arguments: Array(CommandLine.arguments.dropFirst())))
    }
}
