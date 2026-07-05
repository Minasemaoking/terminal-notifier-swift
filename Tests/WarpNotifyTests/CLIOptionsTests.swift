import Testing
@testable import WarpNotify

@Suite("CLI options")
struct CLIOptionsTests {
    @Test
    func parsesLongOptions() throws {
        let options = try CLIOptionsParser.parse([
            "--title", "Build", "--message", "Complete", "--backend", "warp", "--print", "--quiet",
        ])

        #expect(options.title == "Build")
        #expect(options.message == "Complete")
        #expect(options.backend == .warp)
        #expect(options.printOnly)
        #expect(options.quiet)
    }

    @Test
    func parsesShortTitleAndMessageOptions() throws {
        let options = try CLIOptionsParser.parse(["-t", "Build", "-m", "Complete"])

        #expect(options.title == "Build")
        #expect(options.message == "Complete")
    }

    @Test
    func rejectsInvalidBackend() {
        #expect(throws: CLIParseError.invalidBackend("system")) {
            try CLIOptionsParser.parse(["--backend", "system"])
        }
    }

    @Test
    func parsesNativeBackend() throws {
        let options = try CLIOptionsParser.parse(["--backend", "native"])

        #expect(options.backend == .native)
    }

    @Test
    func parsesHelpAndVersion() throws {
        #expect(try CLIOptionsParser.parse(["--help"]).showHelp)
        #expect(try CLIOptionsParser.parse(["--version"]).showVersion)
    }
}
