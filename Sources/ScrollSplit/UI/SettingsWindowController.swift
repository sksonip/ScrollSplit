import AppKit
import Sparkle

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let reversalController: ReverseScrollingController
    private let permissionService: PermissionService
    private let loginItemService: LoginItemService
    private let settings: AppSettings
    private let updaterController: SPUStandardUpdaterController

    private let overallIcon = NSImageView()
    private let overallTitle = NSTextField(labelWithString: "")
    private let overallDetail = NSTextField(wrappingLabelWithString: "")
    private let reverseSwitch = NSSwitch()
    private let loginSwitch = NSSwitch()
    private let checkForUpdatesButton = NSButton()
    private var permissionRows: [PermissionKind: PermissionRowView] = [:]
    private var hasCenteredWindow = false

    init(
        reversalController: ReverseScrollingController,
        permissionService: PermissionService,
        loginItemService: LoginItemService,
        settings: AppSettings,
        updaterController: SPUStandardUpdaterController
    ) {
        self.reversalController = reversalController
        self.permissionService = permissionService
        self.loginItemService = loginItemService
        self.settings = settings
        self.updaterController = updaterController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 510, height: 650),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ScrollSplit"
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.animationBehavior = .documentWindow

        super.init(window: window)
        window.delegate = self
        window.contentView = makeContentView()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func present() {
        guard let window else { return }

        NSApp.setActivationPolicy(.regular)
        if !hasCenteredWindow {
            window.center()
            hasCenteredWindow = true
        }
        refresh()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // AppKit is still completing the close transaction here. Deferring the
        // policy change by one run-loop turn reliably removes the Dock presence.
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        refresh()
    }

    @objc private func applicationDidBecomeActive() {
        if window?.isVisible == true {
            refresh()
        }
    }

    @objc private func toggleReverseScrolling() {
        reversalController.setEnabled(reverseSwitch.state == .on)
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try loginItemService.setEnabled(loginSwitch.state == .on)
        } catch {
            showError(
                title: "Could not update Launch at Login",
                message: error.localizedDescription
            )
        }
        refresh()
    }

    @objc private func requestPermission(_ sender: NSButton) {
        guard let permission = PermissionKind(rawValue: sender.tag) else { return }
        permissionService.requestPermission(for: permission, settings: settings)
        reversalController.retryAfterPermissionChange()
        refresh()
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func makeContentView() -> NSView {
        let content = NSView()

        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64)
        ])

        let appTitle = NSTextField(labelWithString: "ScrollSplit")
        appTitle.font = .systemFont(ofSize: 24, weight: .semibold)
        appTitle.alignment = .center

        let subtitle = NSTextField(labelWithString: "Natural trackpad. Reversed mouse wheel.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center

        let header = NSStackView(views: [icon, appTitle, subtitle])
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = 5

        overallIcon.imageScaling = .scaleProportionallyUpOrDown
        overallIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overallIcon.widthAnchor.constraint(equalToConstant: 28),
            overallIcon.heightAnchor.constraint(equalToConstant: 28)
        ])

        overallTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        overallDetail.textColor = .secondaryLabelColor
        overallDetail.maximumNumberOfLines = 2

        let overallText = NSStackView(views: [overallTitle, overallDetail])
        overallText.orientation = .vertical
        overallText.alignment = .leading
        overallText.spacing = 3

        let overall = NSStackView(views: [overallIcon, overallText])
        overall.orientation = .horizontal
        overall.alignment = .centerY
        overall.distribution = .fill
        overall.spacing = 12
        overall.edgeInsets = NSEdgeInsets(top: 13, left: 14, bottom: 13, right: 14)
        overall.wantsLayer = true
        overall.layer?.cornerRadius = 10
        overall.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        reverseSwitch.target = self
        reverseSwitch.action = #selector(toggleReverseScrolling)
        loginSwitch.target = self
        loginSwitch.action = #selector(toggleLaunchAtLogin)
        checkForUpdatesButton.title = "Check for Updates…"
        checkForUpdatesButton.bezelStyle = .rounded
        checkForUpdatesButton.target = self
        checkForUpdatesButton.action = #selector(checkForUpdates)

        let reverseRow = makeSettingRow(
            title: "Reverse Mouse Scrolling",
            detail: "Reverse vertical wheel scrolling while leaving trackpad gestures unchanged.",
            control: reverseSwitch
        )
        let preferencesSeparator = separator()
        let loginRow = makeSettingRow(
            title: "Launch at Login",
            detail: "Start ScrollSplit silently when you sign in.",
            control: loginSwitch
        )
        let updatesSeparator = separator()
        let updatesRow = makeSettingRow(
            title: "Software Updates",
            detail: "Automatically check every 30 days, or check now.",
            control: checkForUpdatesButton
        )
        let preferences = NSStackView(views: [
            reverseRow,
            preferencesSeparator,
            loginRow,
            updatesSeparator,
            updatesRow
        ])
        preferences.orientation = .vertical
        preferences.alignment = .width
        preferences.distribution = .fill
        preferences.spacing = 0
        preferences.edgeInsets = NSEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)
        preferences.wantsLayer = true
        preferences.layer?.cornerRadius = 10
        preferences.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let permissionStack = NSStackView()
        permissionStack.orientation = .vertical
        permissionStack.alignment = .width
        permissionStack.distribution = .fill
        permissionStack.spacing = 0
        permissionStack.edgeInsets = NSEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)
        permissionStack.wantsLayer = true
        permissionStack.layer?.cornerRadius = 10
        permissionStack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let permissionData: [(PermissionKind, String, String)] = [
            (.inputMonitoring, "Input Monitoring", "Reads mouse wheel events."),
            (.accessibility, "Accessibility", "Allows the event tap to control scrolling."),
            (.postEvent, "Scroll Control", "Authorizes modified scroll events.")
        ]
        var permissionRowViews: [NSView] = []
        for (index, item) in permissionData.enumerated() {
            if index > 0 { permissionStack.addArrangedSubview(separator()) }
            let row = PermissionRowView(
                permission: item.0,
                title: item.1,
                detail: item.2,
                target: self,
                action: #selector(requestPermission(_:))
            )
            permissionRows[item.0] = row
            permissionRowViews.append(row)
            permissionStack.addArrangedSubview(row)
        }

        let permissionsTitle = NSTextField(labelWithString: "Permissions")
        permissionsTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        permissionsTitle.textColor = .secondaryLabelColor
        permissionsTitle.alignment = .left

        let quitButton = NSButton(title: "Quit ScrollSplit", target: self, action: #selector(quit))
        quitButton.bezelStyle = .rounded
        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [footerSpacer, quitButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.distribution = .fill

        let root = NSStackView(views: [
            header,
            overall,
            preferences,
            permissionsTitle,
            permissionStack,
            footer
        ])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            root.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -22),
            header.widthAnchor.constraint(equalTo: root.widthAnchor),
            overall.widthAnchor.constraint(equalTo: root.widthAnchor),
            preferences.widthAnchor.constraint(equalTo: root.widthAnchor),
            reverseRow.widthAnchor.constraint(equalTo: preferences.widthAnchor, constant: -28),
            preferencesSeparator.widthAnchor.constraint(
                equalTo: preferences.widthAnchor,
                constant: -28
            ),
            loginRow.widthAnchor.constraint(equalTo: preferences.widthAnchor, constant: -28),
            updatesSeparator.widthAnchor.constraint(
                equalTo: preferences.widthAnchor,
                constant: -28
            ),
            updatesRow.widthAnchor.constraint(equalTo: preferences.widthAnchor, constant: -28),
            permissionsTitle.widthAnchor.constraint(equalTo: root.widthAnchor),
            permissionStack.widthAnchor.constraint(equalTo: root.widthAnchor),
            footer.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])

        permissionRowViews.forEach {
            $0.widthAnchor.constraint(
                equalTo: permissionStack.widthAnchor,
                constant: -28
            ).isActive = true
        }

        return content
    }

    private func makeSettingRow(title: String, detail: String, control: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.maximumNumberOfLines = 2

        let labels = NSStackView(views: [titleLabel, detailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2

        let row = NSStackView(views: [labels, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func refresh() {
        reverseSwitch.state = reversalController.isEnabled ? .on : .off
        loginSwitch.state = loginItemService.isEnabled ? .on : .off
        checkForUpdatesButton.isEnabled = updaterController.updater.canCheckForUpdates

        updateOverallState()
        permissionRows[.inputMonitoring]?.setGranted(
            permissionService.hasInputMonitoringPermission
        )
        permissionRows[.accessibility]?.setGranted(
            permissionService.hasAccessibilityPermission
        )
        permissionRows[.postEvent]?.setGranted(
            permissionService.hasPostEventPermission
        )
    }

    private func updateOverallState() {
        let symbol: String
        let color: NSColor

        switch reversalController.runtimeState {
        case .active:
            overallTitle.stringValue = "ScrollSplit is active"
            overallDetail.stringValue = "Mouse wheel scrolling is being reversed."
            symbol = "checkmark.circle.fill"
            color = .systemGreen
        case .disabled:
            overallTitle.stringValue = "ScrollSplit is paused"
            overallDetail.stringValue = "Turn on Reverse Mouse Scrolling to resume."
            symbol = "pause.circle.fill"
            color = .secondaryLabelColor
        case .permissionRequired:
            overallTitle.stringValue = "Permission required"
            overallDetail.stringValue = "Grant the missing access below, then try again."
            symbol = "exclamationmark.triangle.fill"
            color = .systemOrange
        case .eventTapFailed:
            overallTitle.stringValue = "Scroll control unavailable"
            overallDetail.stringValue = "macOS refused the event tap. Quit, reopen, and try again."
            symbol = "xmark.octagon.fill"
            color = .systemRed
        case .inactive:
            overallTitle.stringValue = "ScrollSplit is not active"
            overallDetail.stringValue = "Try enabling mouse scroll reversal again."
            symbol = "exclamationmark.circle.fill"
            color = .systemOrange
        }

        overallIcon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        overallIcon.contentTintColor = color
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}

@MainActor
private final class PermissionRowView: NSStackView {
    private let statusIcon = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let actionButton: NSButton

    init(
        permission: PermissionKind,
        title: String,
        detail: String,
        target: AnyObject,
        action: Selector
    ) {
        actionButton = NSButton(title: "Grant Access", target: target, action: action)
        actionButton.tag = permission.rawValue
        actionButton.bezelStyle = .rounded
        actionButton.controlSize = .small

        super.init(frame: .zero)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.font = .systemFont(ofSize: 11)

        let labels = NSStackView(views: [titleLabel, detailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)

        statusIcon.imageScaling = .scaleProportionallyUpOrDown
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusIcon.widthAnchor.constraint(equalToConstant: 16),
            statusIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)

        let status = NSStackView(views: [statusIcon, statusLabel])
        status.orientation = .horizontal
        status.alignment = .centerY
        status.spacing = 4

        orientation = .horizontal
        alignment = .centerY
        distribution = .fill
        spacing = 10
        edgeInsets = NSEdgeInsets(top: 9, left: 0, bottom: 9, right: 0)
        addArrangedSubview(labels)
        addArrangedSubview(status)
        addArrangedSubview(actionButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setGranted(_ granted: Bool) {
        statusIcon.image = NSImage(
            systemSymbolName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
            accessibilityDescription: granted ? "Granted" : "Required"
        )
        statusIcon.contentTintColor = granted ? .systemGreen : .systemOrange
        statusLabel.stringValue = granted ? "Granted" : "Required"
        statusLabel.textColor = granted ? .secondaryLabelColor : .systemOrange
        actionButton.isHidden = granted
    }
}
