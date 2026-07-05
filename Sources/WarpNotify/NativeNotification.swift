import AppKit
import Foundation

@MainActor
protocol NativeNotificationPresenting {
    func present(_ payload: NotificationPayload) throws
}

enum NativeNotificationError: Error, CustomStringConvertible {
    case screenUnavailable

    var description: String {
        switch self {
        case .screenUnavailable:
            return "no display is available for the notification"
        }
    }
}

@MainActor
struct AppKitNotificationPresenter: NativeNotificationPresenting {
    private let displayDuration: TimeInterval = 5
    private let panelSize = NSSize(width: 380, height: 118)

    func present(_ payload: NotificationPayload) throws {
        guard let screen = targetScreen() else {
            throw NativeNotificationError.screenUnavailable
        }

        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.finishLaunching()

        let panel = makePanel(payload: payload, screen: screen)
        panel.orderFrontRegardless()

        let deadline = Date(timeIntervalSinceNow: displayDuration)
        while panel.isVisible, Date() < deadline {
            RunLoop.main.run(until: min(deadline, Date(timeIntervalSinceNow: 0.1)))
        }
        panel.orderOut(nil)
        panel.close()
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func makePanel(payload: NotificationPayload, screen: NSScreen) -> NSPanel {
        let margin: CGFloat = 24
        let origin = NSPoint(
            x: screen.visibleFrame.maxX - panelSize.width - margin,
            y: screen.visibleFrame.minY + margin
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.contentView = makeContentView(payload: payload, closeTarget: panel)
        return panel
    }

    private func makeContentView(payload: NotificationPayload, closeTarget: NSPanel) -> NSView {
        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true

        let titleLabel = NSTextField(labelWithString: payload.title ?? "Terminal Notification")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = NSButton(
            image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close notification")
                ?? NSImage(),
            target: closeTarget,
            action: #selector(NSWindow.close)
        )
        closeButton.isBordered = false
        closeButton.imagePosition = .imageOnly
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.focusRingType = .none
        closeButton.toolTip = "Close notification"
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let messageLabel = NSTextField(wrappingLabelWithString: payload.message)
        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.maximumNumberOfLines = 3
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        effectView.addSubview(titleLabel)
        effectView.addSubview(closeButton)
        effectView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 17),
            closeButton.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -10),
            closeButton.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 10),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -18),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: effectView.bottomAnchor, constant: -16),
        ])

        return effectView
    }
}
