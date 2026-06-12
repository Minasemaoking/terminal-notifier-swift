import Foundation
import Testing
@testable import WarpNotify

@Suite("OSC notification encoder")
struct OSCNotificationTests {
    @Test
    func messageOnlyProducesOSC9Bytes() throws {
        let data = try OSCNotificationEncoder.encode(
            NotificationPayload(title: nil, message: "Build complete")
        )

        #expect(data == Data("\u{001B}]9;Build complete\u{0007}".utf8))
    }

    @Test
    func titleAndMessageProduceOSC777Bytes() throws {
        let data = try OSCNotificationEncoder.encode(
            NotificationPayload(title: "Build", message: "Build complete")
        )

        #expect(data == Data("\u{001B}]777;notify;Build;Build complete\u{0007}".utf8))
    }

    @Test
    func whitespaceTitleUsesOSC9() throws {
        let data = try OSCNotificationEncoder.encode(
            NotificationPayload(title: "  \t ", message: "Complete")
        )

        #expect(data == Data("\u{001B}]9;Complete\u{0007}".utf8))
    }
}
