import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
protocol PermissionServicing {
    var hasInputMonitoringPermission: Bool { get }
    var hasAccessibilityPermission: Bool { get }
    var hasPostEventPermission: Bool { get }

    func requestOrExplainIfNeeded(settings: AppSettings, userInitiated: Bool) -> Bool
    func explainEventTapFailureIfNeeded(settings: AppSettings, userInitiated: Bool)
    func recordSuccessfulEventTapStart(settings: AppSettings)
}

@MainActor
struct PermissionService: PermissionServicing {
    private let api: PermissionAPI
    private let guidanceHandler: ((PermissionState) -> Void)?

    init(
        api: PermissionAPI = .system,
        guidanceHandler: ((PermissionState) -> Void)? = nil
    ) {
        self.api = api
        self.guidanceHandler = guidanceHandler
    }

    var hasInputMonitoringPermission: Bool {
        api.preflightListenEvent()
    }

    var hasAccessibilityPermission: Bool {
        api.isAccessibilityTrusted()
    }

    var hasPostEventPermission: Bool {
        api.preflightPostEvent()
    }

    @discardableResult
    func requestOrExplainIfNeeded(settings: AppSettings, userInitiated: Bool) -> Bool {
        let initialState = permissionState
        guard initialState != .granted else { return true }

        // Login/background startup is intentionally silent. Prompting APIs and
        // guidance are only reached from an explicit user action.
        guard userInitiated else { return false }

        requestPermission(for: initialState.permissionKind, settings: settings)

        let currentState = permissionState
        guard currentState != .granted else { return true }
        guard !settings.hasShownPermissionGuidance else { return false }
        settings.hasShownPermissionGuidance = true

        showPermissionGuidance(for: currentState)
        return false
    }

    func explainEventTapFailureIfNeeded(settings: AppSettings, userInitiated: Bool) {
        guard userInitiated, !settings.hasShownEventTapFailure else { return }
        settings.hasShownEventTapFailure = true

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Scroll interception is still unavailable"
        alert.informativeText = "All required permissions are granted, but macOS still refused ScrollSplit's event tap. Quit and reopen ScrollSplit, then try again."
        alert.runModal()
    }

    func recordSuccessfulEventTapStart(settings: AppSettings) {
        settings.hasShownPermissionGuidance = false
        settings.hasShownEventTapFailure = false
    }

    var permissionState: PermissionState {
        PermissionState(
            hasInputMonitoringPermission: hasInputMonitoringPermission,
            hasAccessibilityPermission: hasAccessibilityPermission,
            hasPostEventPermission: hasPostEventPermission
        )
    }

    func requestPermission(for permission: PermissionKind, settings: AppSettings) {
        switch permission {
        case .inputMonitoring:
            settings.hasRequestedInputMonitoring = true
            _ = api.requestListenEvent()
        case .accessibility:
            settings.hasRequestedAccessibility = true
            _ = api.requestAccessibility()
        case .postEvent:
            settings.hasRequestedPostEvent = true
            _ = api.requestPostEvent()
        }
    }

    private func showPermissionGuidance(for state: PermissionState) {
        if let guidanceHandler {
            guidanceHandler(state)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational

        switch state {
        case .granted:
            return
        case .inputMonitoringMissing:
            alert.messageText = "Input Monitoring required"
            alert.informativeText = "Enable ScrollSplit in Privacy & Security > Input Monitoring, then select Reverse Mouse Scrolling again."
            alert.addButton(withTitle: "Open Input Monitoring")
            alert.addButton(withTitle: "Not Now")
        case .accessibilityMissing:
            alert.messageText = "Accessibility required"
            alert.informativeText = "Enable ScrollSplit in Privacy & Security > Accessibility, then select Reverse Mouse Scrolling again."
            alert.addButton(withTitle: "Open Accessibility")
            alert.addButton(withTitle: "Not Now")
        case .postEventMissing:
            alert.messageText = "Scroll control permission required"
            alert.informativeText = "Accessibility is granted, but macOS has not authorized ScrollSplit to control scroll events. Quit and reopen ScrollSplit, then retry. If this began after a signing change, clear ScrollSplit's stale PostEvent authorization once before reopening."
            alert.addButton(withTitle: "OK")
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        switch (state, response) {
        case (.inputMonitoringMissing, .alertFirstButtonReturn):
            openPrivacyPane("Privacy_ListenEvent")
        case (.accessibilityMissing, .alertFirstButtonReturn):
            openPrivacyPane("Privacy_Accessibility")
        default:
            break
        }
    }

    private func openPrivacyPane(_ pane: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        ) else { return }

        NSWorkspace.shared.open(url)
    }
}

struct PermissionAPI {
    let preflightListenEvent: () -> Bool
    let isAccessibilityTrusted: () -> Bool
    let preflightPostEvent: () -> Bool
    let requestListenEvent: () -> Bool
    let requestAccessibility: () -> Bool
    let requestPostEvent: () -> Bool

    static let system = PermissionAPI(
        preflightListenEvent: { CGPreflightListenEventAccess() },
        isAccessibilityTrusted: { AXIsProcessTrusted() },
        preflightPostEvent: { CGPreflightPostEventAccess() },
        requestListenEvent: { CGRequestListenEventAccess() },
        requestAccessibility: {
            let options = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        },
        requestPostEvent: { CGRequestPostEventAccess() }
    )
}

enum PermissionState: Equatable {
    case granted
    case inputMonitoringMissing
    case accessibilityMissing
    case postEventMissing

    init(
        hasInputMonitoringPermission: Bool,
        hasAccessibilityPermission: Bool,
        hasPostEventPermission: Bool
    ) {
        if !hasInputMonitoringPermission {
            self = .inputMonitoringMissing
        } else if !hasAccessibilityPermission {
            self = .accessibilityMissing
        } else if !hasPostEventPermission {
            self = .postEventMissing
        } else {
            self = .granted
        }
    }

    var permissionKind: PermissionKind {
        switch self {
        case .inputMonitoringMissing:
            return .inputMonitoring
        case .accessibilityMissing:
            return .accessibility
        case .postEventMissing:
            return .postEvent
        case .granted:
            preconditionFailure("A granted state has no missing permission")
        }
    }
}

enum PermissionKind: Int, CaseIterable {
    case inputMonitoring
    case accessibility
    case postEvent
}
