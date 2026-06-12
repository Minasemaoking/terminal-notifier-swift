import Testing
@testable import WarpNotify

@Suite("Notification text sanitization")
struct SanitizationTests {
    @Test
    func preservesChineseAndEmoji() {
        #expect(sanitizeNotificationText("建置完成 ✅") == "建置完成 ✅")
    }

    @Test
    func normalizesNewlinesToSpaces() {
        #expect(sanitizeNotificationText("one\r\ntwo\rthree\nfour") == "one two three four")
    }

    @Test
    func replacesSemicolonWithFullwidthSemicolon() {
        #expect(sanitizeNotificationText("Build; complete") == "Build； complete")
    }

    @Test
    func removesEscapeBellNullAndOtherControlCharacters() {
        let input = "a\u{001B}b\u{0007}c\u{0000}d\u{0001}e"

        #expect(sanitizeNotificationText(input) == "abcde")
    }

    @Test
    func trimsLeadingAndTrailingWhitespace() {
        #expect(sanitizeNotificationText("  complete  ") == "complete")
    }
}
