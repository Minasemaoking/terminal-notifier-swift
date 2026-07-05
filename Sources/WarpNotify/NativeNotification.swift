import AppKit
import Foundation
import QuartzCore

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
private final class InteractiveNotificationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class AnimatedCloseButton: NSButton {
    private weak var notificationPanel: NSPanel?
    private var pointerIsInside = false
    private var trackingAreaReference: NSTrackingArea?

    init(notificationPanel: NSPanel) {
        self.notificationPanel = notificationPanel
        super.init(frame: .zero)

        image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close notification")
        symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        target = self
        action = #selector(dismissNotification)
        isBordered = false
        imagePosition = .imageOnly
        contentTintColor = .secondaryLabelColor
        focusRingType = .none
        toolTip = "Close notification"
        setAccessibilityLabel("Close notification")
        wantsLayer = true
        layer?.cornerRadius = 9
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingAreaReference = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        pointerIsInside = true
        animate(scale: 1, backgroundAlpha: 0.12, duration: 0.12)
    }

    override func mouseExited(with event: NSEvent) {
        pointerIsInside = false
        animate(scale: 1, backgroundAlpha: 0, duration: 0.12)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        animate(scale: 0.82, backgroundAlpha: 0.28, duration: 0.07)
        super.mouseDown(with: event)
        animate(scale: 1, backgroundAlpha: pointerIsInside ? 0.12 : 0, duration: 0.12)
    }

    @objc private func dismissNotification() {
        notificationPanel?.close()
    }

    private func animate(scale: CGFloat, backgroundAlpha: CGFloat, duration: CFTimeInterval) {
        guard let layer else { return }

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = layer.presentation()?.value(forKeyPath: "transform.scale") ?? 1
        scaleAnimation.toValue = scale
        scaleAnimation.duration = duration
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.setValue(scale, forKeyPath: "transform.scale")
        layer.add(scaleAnimation, forKey: "closeButtonScale")

        let targetColor = NSColor.labelColor.withAlphaComponent(backgroundAlpha).cgColor
        let colorAnimation = CABasicAnimation(keyPath: "backgroundColor")
        colorAnimation.fromValue = layer.presentation()?.backgroundColor ?? layer.backgroundColor
        colorAnimation.toValue = targetColor
        colorAnimation.duration = duration
        colorAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.backgroundColor = targetColor
        layer.add(colorAnimation, forKey: "closeButtonBackground")
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
            let eventDeadline = min(deadline, Date(timeIntervalSinceNow: 0.1))
            if let event = application.nextEvent(
                matching: .any,
                until: eventDeadline,
                inMode: .default,
                dequeue: true
            ) {
                application.sendEvent(event)
            }
            application.updateWindows()
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

        let panel = InteractiveNotificationPanel(
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

        let closeButton = AnimatedCloseButton(notificationPanel: closeTarget)
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
            closeButton.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -6),
            closeButton.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 6),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -18),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: effectView.bottomAnchor, constant: -16),
        ])

        return effectView
    }
}
