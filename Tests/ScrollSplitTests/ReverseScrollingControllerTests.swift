import Foundation
import XCTest
@testable import ScrollSplit

@MainActor
final class ReverseScrollingControllerTests: XCTestCase {
    func testDesiredEnabledButStoppedTapDisplaysOff() {
        let fixture = makeFixture(desired: true, isRunning: false)

        XCTAssertTrue(fixture.settings.reverseMouseScrolling)
        XCTAssertFalse(fixture.controller.isEnabled)
    }

    func testFailedAutomaticStartupPreservesDesireButDisplaysOff() {
        let fixture = makeFixture(
            desired: true,
            isRunning: false,
            hasPermission: true,
            startResults: [false]
        )

        fixture.controller.startAutomaticallyIfDesired()

        XCTAssertTrue(fixture.settings.reverseMouseScrolling)
        XCTAssertFalse(fixture.tap.isRunning)
        XCTAssertFalse(fixture.controller.isEnabled)
        XCTAssertEqual(fixture.tap.startCallCount, 1)
        XCTAssertEqual(fixture.permissions.failureGuidanceUserInitiated, [false])
    }

    func testExplicitEnableRetriesWhenPersistedDesireWasAlreadyEnabled() {
        let fixture = makeFixture(
            desired: true,
            isRunning: false,
            hasPermission: false,
            permissionRequestResults: [true],
            startResults: [true]
        )

        fixture.controller.setEnabled(true)

        XCTAssertEqual(fixture.permissions.permissionRequestUserInitiated, [true])
        XCTAssertEqual(fixture.tap.startCallCount, 1)
        XCTAssertTrue(fixture.tap.isRunning)
        XCTAssertTrue(fixture.controller.isEnabled)
        XCTAssertEqual(fixture.permissions.successfulStartCount, 1)
    }

    func testSuccessfulRetryAfterStartupFailureUpdatesRuntimeState() {
        let fixture = makeFixture(
            desired: true,
            isRunning: false,
            hasPermission: true,
            startResults: [false, true]
        )

        fixture.controller.startAutomaticallyIfDesired()
        XCTAssertFalse(fixture.controller.isEnabled)

        fixture.controller.setEnabled(true)

        XCTAssertEqual(fixture.tap.startCallCount, 2)
        XCTAssertTrue(fixture.controller.isEnabled)
        XCTAssertTrue(fixture.settings.reverseMouseScrolling)
        XCTAssertEqual(fixture.permissions.successfulStartCount, 1)
    }

    func testAccessibilityMissingPreventsEventTapStart() {
        let fixture = makeFixture(
            desired: true,
            isRunning: false,
            hasPermission: true,
            hasAccessibilityPermission: false,
            permissionRequestResults: [false],
            startResults: [true]
        )

        fixture.controller.startAutomaticallyIfDesired()

        XCTAssertEqual(fixture.permissions.permissionRequestUserInitiated, [false])
        XCTAssertEqual(fixture.tap.startCallCount, 0)
        XCTAssertFalse(fixture.controller.isEnabled)
    }

    func testInputMonitoringMissingPreventsEventTapStart() {
        let fixture = makeFixture(
            desired: true,
            isRunning: false,
            hasPermission: true,
            hasInputMonitoringPermission: false,
            permissionRequestResults: [false],
            startResults: [true]
        )

        fixture.controller.setEnabled(true)

        XCTAssertEqual(fixture.permissions.requestedStates, [.inputMonitoringMissing])
        XCTAssertEqual(fixture.tap.startCallCount, 0)
    }

    func testPostEventMissingWhileAccessibilityTrustedIsReportedSeparately() {
        let fixture = makeFixture(
            desired: true,
            isRunning: false,
            hasPermission: true,
            hasAccessibilityPermission: true,
            hasPostEventPermission: false,
            permissionRequestResults: [false],
            startResults: [true]
        )

        fixture.controller.setEnabled(true)

        XCTAssertEqual(fixture.permissions.requestedStates, [.postEventMissing])
        XCTAssertFalse(fixture.permissions.requestedStates.contains(.accessibilityMissing))
        XCTAssertEqual(fixture.tap.startCallCount, 0)
    }

    func testAllPermissionChecksPassingStartsEventTap() {
        let fixture = makeFixture(
            desired: true,
            isRunning: false,
            hasPermission: true,
            startResults: [true]
        )

        fixture.controller.setEnabled(true)

        XCTAssertTrue(fixture.permissions.requestedStates.isEmpty)
        XCTAssertEqual(fixture.tap.startCallCount, 1)
        XCTAssertTrue(fixture.controller.isEnabled)
    }

    func testExplicitRetryAfterPostEventDenialRequestsPostEventAgain() {
        let fixture = makeFixture(
            desired: true,
            isRunning: false,
            hasPermission: true,
            hasPostEventPermission: false,
            permissionRequestResults: [false, false]
        )

        fixture.controller.setEnabled(true)
        fixture.controller.setEnabled(true)

        XCTAssertEqual(fixture.permissions.permissionRequestUserInitiated, [true, true])
        XCTAssertEqual(fixture.permissions.requestedStates, [.postEventMissing, .postEventMissing])
        XCTAssertEqual(fixture.tap.startCallCount, 0)
    }

    func testPermissionStatePrioritizesIndependentChecks() {
        XCTAssertEqual(
            PermissionState(
                hasInputMonitoringPermission: false,
                hasAccessibilityPermission: false,
                hasPostEventPermission: false
            ),
            .inputMonitoringMissing
        )
        XCTAssertEqual(
            PermissionState(
                hasInputMonitoringPermission: true,
                hasAccessibilityPermission: false,
                hasPostEventPermission: false
            ),
            .accessibilityMissing
        )
        XCTAssertEqual(
            PermissionState(
                hasInputMonitoringPermission: true,
                hasAccessibilityPermission: true,
                hasPostEventPermission: false
            ),
            .postEventMissing
        )
        XCTAssertEqual(
            PermissionState(
                hasInputMonitoringPermission: true,
                hasAccessibilityPermission: true,
                hasPostEventPermission: true
            ),
            .granted
        )
    }

    func testConcreteServiceDoesNotPromptAccessibilityWhenOnlyPostEventIsMissing() {
        var listenRequestCount = 0
        var accessibilityRequestCount = 0
        var postEventRequestCount = 0
        var guidanceStates: [PermissionState] = []
        let api = PermissionAPI(
            preflightListenEvent: { true },
            isAccessibilityTrusted: { true },
            preflightPostEvent: { false },
            requestListenEvent: {
                listenRequestCount += 1
                return false
            },
            requestAccessibility: {
                accessibilityRequestCount += 1
                return false
            },
            requestPostEvent: {
                postEventRequestCount += 1
                return false
            }
        )
        let defaults = UserDefaults(
            suiteName: "ReverseScrollingControllerTests.PermissionService.\(UUID().uuidString)"
        )!
        let settings = AppSettings(defaults: defaults)
        let service = PermissionService(api: api) { guidanceStates.append($0) }

        XCTAssertFalse(service.requestOrExplainIfNeeded(settings: settings, userInitiated: true))

        XCTAssertEqual(listenRequestCount, 0)
        XCTAssertEqual(accessibilityRequestCount, 0)
        XCTAssertEqual(postEventRequestCount, 1)
        XCTAssertEqual(guidanceStates, [.postEventMissing])
        XCTAssertTrue(settings.hasRequestedPostEvent)
        XCTAssertFalse(settings.hasRequestedAccessibility)
    }

    func testConcreteServiceIsCompletelySilentForAutomaticStartup() {
        var requestCount = 0
        var guidanceStates: [PermissionState] = []
        let api = PermissionAPI(
            preflightListenEvent: { false },
            isAccessibilityTrusted: { false },
            preflightPostEvent: { false },
            requestListenEvent: {
                requestCount += 1
                return false
            },
            requestAccessibility: {
                requestCount += 1
                return false
            },
            requestPostEvent: {
                requestCount += 1
                return false
            }
        )
        let defaults = UserDefaults(
            suiteName: "ReverseScrollingControllerTests.SilentStartup.\(UUID().uuidString)"
        )!
        let settings = AppSettings(defaults: defaults)
        let service = PermissionService(api: api) { guidanceStates.append($0) }

        XCTAssertFalse(service.requestOrExplainIfNeeded(settings: settings, userInitiated: false))

        XCTAssertEqual(requestCount, 0)
        XCTAssertTrue(guidanceStates.isEmpty)
        XCTAssertFalse(settings.hasShownPermissionGuidance)
    }

    func testEachPermissionCanBeRequestedIndependently() {
        var requested: [PermissionKind] = []
        let api = PermissionAPI(
            preflightListenEvent: { false },
            isAccessibilityTrusted: { false },
            preflightPostEvent: { false },
            requestListenEvent: {
                requested.append(.inputMonitoring)
                return false
            },
            requestAccessibility: {
                requested.append(.accessibility)
                return false
            },
            requestPostEvent: {
                requested.append(.postEvent)
                return false
            }
        )
        let defaults = UserDefaults(
            suiteName: "ReverseScrollingControllerTests.IndependentPermissions.\(UUID().uuidString)"
        )!
        let settings = AppSettings(defaults: defaults)
        let service = PermissionService(api: api)

        PermissionKind.allCases.forEach {
            service.requestPermission(for: $0, settings: settings)
        }

        XCTAssertEqual(requested, [.inputMonitoring, .accessibility, .postEvent])
        XCTAssertTrue(settings.hasRequestedInputMonitoring)
        XCTAssertTrue(settings.hasRequestedAccessibility)
        XCTAssertTrue(settings.hasRequestedPostEvent)
    }

    func testRuntimeStateKeepsEventTapFailureSeparateFromPermissions() {
        let fixture = makeFixture(
            desired: true,
            isRunning: false,
            hasPermission: true,
            startResults: [false]
        )

        fixture.controller.startAutomaticallyIfDesired()

        XCTAssertEqual(fixture.controller.runtimeState, .eventTapFailed)
    }

    func testRuntimeStateReportsSpecificMissingPermission() {
        let fixture = makeFixture(
            desired: true,
            isRunning: false,
            hasPermission: true,
            hasPostEventPermission: false
        )

        XCTAssertEqual(
            fixture.controller.runtimeState,
            .permissionRequired(.postEventMissing)
        )
    }

    func testDisablingRunningTapClearsDesireAndRuntimeState() {
        let fixture = makeFixture(desired: true, isRunning: true)

        fixture.controller.setEnabled(false)

        XCTAssertFalse(fixture.settings.reverseMouseScrolling)
        XCTAssertFalse(fixture.tap.isRunning)
        XCTAssertFalse(fixture.controller.isEnabled)
        XCTAssertEqual(fixture.tap.stopCallCount, 1)
    }

    private func makeFixture(
        desired: Bool,
        isRunning: Bool,
        hasPermission: Bool = true,
        hasInputMonitoringPermission: Bool? = nil,
        hasAccessibilityPermission: Bool? = nil,
        hasPostEventPermission: Bool? = nil,
        permissionRequestResults: [Bool] = [],
        startResults: [Bool] = []
    ) -> Fixture {
        let suiteName = "ReverseScrollingControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(desired, forKey: "reverseMouseScrolling")

        let settings = AppSettings(defaults: defaults)
        let tap = FakeEventTap(isRunning: isRunning, startResults: startResults)
        let permissions = FakePermissionService(
            hasInputMonitoringPermission: hasInputMonitoringPermission ?? hasPermission,
            hasAccessibilityPermission: hasAccessibilityPermission ?? hasPermission,
            hasPostEventPermission: hasPostEventPermission ?? hasPermission,
            requestResults: permissionRequestResults
        )
        let controller = ReverseScrollingController(
            settings: settings,
            eventTap: tap,
            permissionService: permissions
        )

        return Fixture(
            settings: settings,
            tap: tap,
            permissions: permissions,
            controller: controller
        )
    }
}

@MainActor
private struct Fixture {
    let settings: AppSettings
    let tap: FakeEventTap
    let permissions: FakePermissionService
    let controller: ReverseScrollingController
}

@MainActor
private final class FakeEventTap: ScrollEventTapControlling {
    var isRunning: Bool
    private var startResults: [Bool]
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    init(isRunning: Bool, startResults: [Bool]) {
        self.isRunning = isRunning
        self.startResults = startResults
    }

    func start() -> Bool {
        startCallCount += 1
        let result = startResults.isEmpty ? false : startResults.removeFirst()
        isRunning = result
        return result
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }
}

@MainActor
private final class FakePermissionService: PermissionServicing {
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
