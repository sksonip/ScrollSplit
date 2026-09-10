import AppKit
import Sparkle

@main
enum ScrollSplitApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()

        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()

        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private lazy var eventTap = ScrollEventTap(
        isReversalEnabled: { [weak settings] in
            settings?.reverseMouseScrolling ?? false
        }
    )
    private let permissionService = PermissionService()
    private lazy var reversalController = ReverseScrollingController(
        settings: settings,
        eventTap: eventTap,
        permissionService: permissionService
    )
    private let loginItemService = LoginItemService()
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private var settingsWindowController: SettingsWindowController?
    private var shouldShowSettingsOnLaunch = true

    func applicationWillFinishLaunching(_ notification: Notification) {
        shouldShowSettingsOnLaunch = !ApplicationLaunchContext.isLoginItemLaunch()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessing the controller starts Sparkle's scheduled update checks.
        // The interval is configured in Info.plist and updates still require
        // an explicit confirmation from the user before installation.
        _ = updaterController
        reversalController.startAutomaticallyIfDesired()

        if shouldShowSettingsOnLaunch {
            showSettingsWindow()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showSettingsWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTap.stop()
    }

    private func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                reversalController: reversalController,
                permissionService: permissionService,
                loginItemService: loginItemService,
                settings: settings,
                updaterController: updaterController
            )
        }

        settingsWindowController?.present()
    }
}
