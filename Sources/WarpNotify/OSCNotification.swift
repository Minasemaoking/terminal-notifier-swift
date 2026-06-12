import Foundation

struct NotificationPayload: Equatable {
    let title: String?
    let message: String

    init(title: String?, message: String) {
        let sanitizedTitle = title.map(sanitizeNotificationText)
        self.title = sanitizedTitle?.isEmpty == false ? sanitizedTitle : nil
        self.message = sanitizeNotificationText(message)
    }
}

enum OSCNotificationEncodingError: Error, Equatable, CustomStringConvertible {
    case invalidUTF8

    var description: String {
        "notification could not be encoded as UTF-8"
    }
}

enum OSCNotificationEncoder {
    static func encode(_ payload: NotificationPayload) throws -> Data {
        let sequence: String

        if let title = payload.title, !title.isEmpty {
            sequence = "\u{001B}]777;notify;\(title);\(payload.message)\u{0007}"
        } else {
            sequence = "\u{001B}]9;\(payload.message)\u{0007}"
        }

        guard let data = sequence.data(using: .utf8) else {
            throw OSCNotificationEncodingError.invalidUTF8
        }
        return data
    }
}

func sanitizeNotificationText(_ input: String) -> String {
    let newlineNormalized = input
        .replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .replacingOccurrences(of: "\n", with: " ")

    var sanitized = ""
    for scalar in newlineNormalized.unicodeScalars {
        if scalar.value == 0x3B {
            sanitized.append("；")
        } else if !CharacterSet.controlCharacters.contains(scalar) {
            sanitized.unicodeScalars.append(scalar)
        }
    }

    return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
}
