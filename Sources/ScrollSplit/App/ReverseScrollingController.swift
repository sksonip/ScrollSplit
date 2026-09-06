import Foundation

enum ReverseScrollingRuntimeState: Equatable {
    case disabled
    case active
    case permissionRequired(PermissionState)
    case eventTapFailed
    case inactive
}

@MainActor
final class ReverseScrollingController {
    private let settings: AppSettings
    private let eventTap: any ScrollEventTapControlling
    private let permissionService: any PermissionServicing
    private(set) var lastStartFailed = false

    init(
        settings: AppSettings,
        eventTap: any ScrollEventTapControlling,
        permissionService: any PermissionServicing
    ) {
        self.settings = settings
        self.eventTap = eventTap
        self.permissionService = permissionService
    }

    /// This is deliberately backed by the live event tap, not the saved desire.
    var isEnabled: Bool {
        eventTap.isRunning
    }

    var runtimeState: ReverseScrollingRuntimeState {
        if eventTap.isRunning {
            return .active
        }

        guard settings.reverseMouseScrolling else {
            return .disabled
        }

        let permissionState = PermissionState(
            hasInputMonitoringPermission: permissionService.hasInputMonitoringPermission,
            hasAccessibilityPermission: permissionService.hasAccessibilityPermission,
            hasPostEventPermission: permissionService.hasPostEventPermission
        )
        if permissionState != .granted {
            return .permissionRequired(permissionState)
        }

        return lastStartFailed ? .eventTapFailed : .inactive
    }

    func startAutomaticallyIfDesired() {
        guard settings.reverseMouseScrolling else { return }
        attemptStart(userInitiated: false)
    }

    func setEnabled(_ enabled: Bool) {
        if !enabled {
            settings.reverseMouseScrolling = false
            lastStartFailed = false
            eventTap.stop()
            return
        }

        // A stopped tap means this is an enable attempt, regardless of a stale
        // persisted desire from an earlier permission or startup failure.
        settings.reverseMouseScrolling = true
        attemptStart(userInitiated: true)
    }

    func retryAfterPermissionChange() {
        guard settings.reverseMouseScrolling, !eventTap.isRunning else { return }
        attemptStart(userInitiated: false)
    }

    private func attemptStart(userInitiated: Bool) {
        lastStartFailed = false

        guard (permissionService.hasInputMonitoringPermission &&
               permissionService.hasAccessibilityPermission &&
               permissionService.hasPostEventPermission) ||
                permissionService.requestOrExplainIfNeeded(
                    settings: settings,
                    userInitiated: userInitiated
                ) else {
            return
        }

        if eventTap.start() {
            permissionService.recordSuccessfulEventTapStart(settings: settings)
        } else {
            lastStartFailed = true
            permissionService.explainEventTapFailureIfNeeded(
                settings: settings,
                userInitiated: userInitiated
            )
        }
    }
}
