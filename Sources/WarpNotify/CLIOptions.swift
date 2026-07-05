import Foundation

enum NotificationBackend: String, Equatable {
    case auto
    case native
    case warp
}

struct CLIOptions: Equatable {
    var title: String?
    var message: String?
    var backend: NotificationBackend = .auto
    var printOnly = false
    var quiet = false
    var showHelp = false
    var showVersion = false
}

enum CLIParseError: Error, Equatable, CustomStringConvertible {
    case missingValue(String)
    case invalidBackend(String)
    case unknownOption(String)
    case unexpectedArgument(String)

    var description: String {
        switch self {
        case let .missingValue(option):
            return "missing value for \(option)"
        case let .invalidBackend(value):
            return "invalid backend '\(value)'; expected auto, native, or warp"
        case let .unknownOption(option):
            return "unknown option '\(option)'"
        case let .unexpectedArgument(argument):
            return "unexpected argument '\(argument)'"
        }
    }
}

enum CLIOptionsParser {
    static func parse(_ arguments: [String]) throws -> CLIOptions {
        var options = CLIOptions()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "--title", "-t":
                options.title = try value(after: argument, in: arguments, index: &index)
            case "--message", "-m":
                options.message = try value(after: argument, in: arguments, index: &index)
            case "--backend":
                let rawValue = try value(after: argument, in: arguments, index: &index)
                guard let backend = NotificationBackend(rawValue: rawValue) else {
                    throw CLIParseError.invalidBackend(rawValue)
                }
                options.backend = backend
            case "--print":
                options.printOnly = true
            case "--quiet":
                options.quiet = true
            case "--help", "-h":
                options.showHelp = true
            case "--version":
                options.showVersion = true
            default:
                if argument.hasPrefix("-") {
                    throw CLIParseError.unknownOption(argument)
                }
                throw CLIParseError.unexpectedArgument(argument)
            }

            index += 1
        }

        return options
    }

    private static func value(
        after option: String,
        in arguments: [String],
        index: inout Int
    ) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw CLIParseError.missingValue(option)
        }

        index = valueIndex
        return arguments[valueIndex]
    }
}

enum CLIText {
    static let version = "warp-notify 2.0.0\n"

    static let usage = """
        Usage:
          warp-notify --message <message> [options]
          warp-notify --title <title> --message <message> [options]
          echo <message> | warp-notify [--title <title>] [options]

        Options:
          -t, --title <title>       Optional notification title
          -m, --message <message>   Notification message; stdin is used when omitted
              --backend <backend>   Backend: auto, native, or warp (default: auto)
              --print               Write the OSC sequence to stdout only
              --quiet               Suppress terminal environment warnings
          -h, --help                Show this help
              --version             Show version

        Exit codes:
          0  Success
          2  CLI usage error
          3  Input error
          4  Output error
        """ + "\n"
}
