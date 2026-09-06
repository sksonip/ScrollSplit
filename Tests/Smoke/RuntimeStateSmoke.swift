import Foundation

@main
struct RuntimeStateSmoke {
    @MainActor
    static func main() {
        verifyDesiredStateDoesNotMasqueradeAsRuntimeState()
        verifyFailedStartupAndSuccessfulRetry()
        verifyExplicitPermissionRetryWithStaleDesire()
        verifyAccessibilityPermissionIsRequired()
        verifyPostEventIsIndependentFromAccessibility()
        verifyExplicitPostEventRetry()
        print("Runtime state smoke tests passed")
    }

    @MainActor
    private static func verifyDesiredStateDoesNotMasqueradeAsRuntimeState() {
        let fixture = makeFixture(desired: true, hasPermission: true)

        precondition(fixture.settings.reverseMouseScrolling)
        precondition(!fixture.controller.isEnabled)
    }

    @MainActor
    private static func verifyFailedStartupAndSuccessfulRetry() {
        let fixture = makeFixture(
            desired: true,
            hasPermission: true,
            startResults: [false, true]
        )

        fixture.controller.startAutomaticallyIfDesired()
        precondition(!fixture.controller.isEnabled)
        precondition(fixture.permissions.failureGuidanceUserInitiated == [false])

        fixture.controller.setEnabled(true)
        precondition(fixture.controller.isEnabled)
        precondition(fixture.tap.startCallCount == 2)
        precondition(fixture.permissions.successfulStartCount == 1)
    }

    @MainActor
    private static func verifyExplicitPermissionRetryWithStaleDesire() {
        let fixture = makeFixture(
            desired: true,
            hasPermission: false,
            permissionRequestResults: [true],
            startResults: [true]
        )

        fixture.controller.setEnabled(true)
        precondition(fixture.permissions.permissionRequestUserInitiated == [true])
        precondition(fixture.controller.isEnabled)
    }

    @MainActor
    private static func verifyAccessibilityPermissionIsRequired() {
        let fixture = makeFixture(
            desired: true,
            hasPermission: true,
            hasAccessibilityPermission: false,
            permissionRequestResults: [false],
            startResults: [true]
        )

        fixture.controller.startAutomaticallyIfDesired()

        precondition(fixture.permissions.permissionRequestUserInitiated == [false])
        precondition(fixture.tap.startCallCount == 0)
        precondition(!fixture.controller.isEnabled)
    }

    @MainActor
    private static func verifyPostEventIsIndependentFromAccessibility() {
        let fixture = makeFixture(
            desired: true,
            hasPermission: true,
            hasAccessibilityPermission: true,
            hasPostEventPermission: false,
            permissionRequestResults: [false],
            startResults: [true]
        )

        fixture.controller.setEnabled(true)

        precondition(fixture.permissions.requestedStates == [.postEventMissing])
        precondition(!fixture.permissions.requestedStates.contains(.accessibilityMissing))
        precondition(fixture.tap.startCallCount == 0)
    }

    @MainActor
    private static func verifyExplicitPostEventRetry() {
        let fixture = makeFixture(
            desired: true,
            hasPermission: true,
            hasPostEventPermission: false,
            permissionRequestResults: [false, false]
        )

        fixture.controller.setEnabled(true)
        fixture.controller.setEnabled(true)

        precondition(fixture.permissions.requestedStates == [.postEventMissing, .postEventMissing])
        precondition(fixture.permissions.permissionRequestUserInitiated == [true, true])
    }

    @MainActor
    private static func makeFixture(
        desired: Bool,
        hasPermission: Bool,
        hasAccessibilityPermission: Bool? = nil,
        hasPostEventPermission: Bool? = nil,
        permissionRequestResults: [Bool] = [],
        startResults: [Bool] = []
    ) -> RuntimeFixture {
        let suiteName = "RuntimeStateSmoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(desired, forKey: "reverseMouseScrolling")

        let settings = AppSettings(defaults: defaults)
        let tap = SmokeEventTap(startResults: startResults)
        let permissions = SmokePermissionService(
            hasInputMonitoringPermission: hasPermission,
            hasAccessibilityPermission: hasAccessibilityPermission ?? hasPermission,
            hasPostEventPermission: hasPostEventPermission ?? hasPermission,
            requestResults: permissionRequestResults
        )
        let controller = ReverseScrollingController(
            settings: settings,
            eventTap: tap,
            permissionService: permissions
        )

        return RuntimeFixture(
            settings: settings,
            tap: tap,
            permissions: permissions,
            controller: controller
        )
    }
}

@MainActor
private struct RuntimeFixture {
    let settings: AppSettings
    let tap: SmokeEventTap
    let permissions: SmokePermissionService
    let controller: ReverseScrollingController
}

@MainActor
private final class SmokeEventTap: ScrollEventTapControlling {
    var isRunning = false
    private var startResults: [Bool]
    private(set) var startCallCount = 0

    init(startResults: [Bool]) {
        self.startResults = startResults
    }

    func start() -> Bool {
        startCallCount += 1
        let result = startResults.isEmpty ? false : startResults.removeFirst()
        isRunning = result
        return result
    }

    func stop() {
        isRunning = false
    }
}

@MainActor
private final class SmokePermissionService: PermissionServicing {
    var hasInputMonitoringPermission: Bool
    var hasAccessibilityPermission: Bool
    var hasPostEventPermission: Bool
    private var requestResults: [Bool]
    private(set) var permissionRequestUserInitiated: [Bool] = []
    private(set) var requestedStates: [PermissionState] = []
    private(set) var failureGuidanceUserInitiated: [Bool] = []
    private(set) var successfulStartCount = 0

    init(
        hasInputMonitoringPermission: Bool,
        hasAccessibilityPermission: Bool,
        hasPostEventPermission: Bool,
        requestResults: [Bool]
    ) {
        self.hasInputMonitoringPermission = hasInputMonitoringPermission
        self.hasAccessibilityPermission = hasAccessibilityPermission
        self.hasPostEventPermission = hasPostEventPermission
        self.requestResults = requestResults
    }

    func requestOrExplainIfNeeded(settings: AppSettings, userInitiated: Bool) -> Bool {
        permissionRequestUserInitiated.append(userInitiated)
        requestedStates.append(
            PermissionState(
                hasInputMonitoringPermission: hasInputMonitoringPermission,
                hasAccessibilityPermission: hasAccessibilityPermission,
                hasPostEventPermission: hasPostEventPermission
            )
        )
        return requestResults.isEmpty ? false : requestResults.removeFirst()
    }

    func explainEventTapFailureIfNeeded(settings: AppSettings, userInitiated: Bool) {
        failureGuidanceUserInitiated.append(userInitiated)
    }

    func recordSuccessfulEventTapStart(settings: AppSettings) {
        successfulStartCount += 1
    }
}
