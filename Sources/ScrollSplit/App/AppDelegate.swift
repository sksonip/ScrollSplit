import AppKit

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
    private var settingsWindowController: SettingsWindowController?
    private var shouldShowSettingsOnLaunch = true

    func applicationWillFinishLaunching(_ notification: Notification) {
        shouldShowSettingsOnLaunch = !ApplicationLaunchContext.isLoginItemLaunch()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
                settings: settings
            )
        }

        settingsWindowController?.present()
    }
}
